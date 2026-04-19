import Foundation

/// Contract for the on-device LLM backend. Implemented by `RealCactusService`
/// (Gemma on Cactus).
///
/// `sourceLabel` and `isHealthy` exist so the UI can display at a glance
/// whether whispers are actually hitting Gemma or silently falling back.
/// The teammate debugging the whisper agent had no way to tell which code
/// path was running; the pill in the Live pane now makes this obvious.
protocol CactusService: AnyObject {
    func complete(system: String, user: String) async throws -> String

    /// Short human-readable label for the status pill. Short enough to fit
    /// in ~12 chars of monospaced UI space.
    var sourceLabel: String { get }

    /// True when `complete(...)` has a realistic chance of returning useful
    /// output. False for `UnavailableCactusService`. Drives the pill color.
    var isHealthy: Bool { get }
}

/// Stand-in used when the Gemma model is missing or failed to initialize.
/// It throws from every call so the UI can surface a clear error — this is
/// NOT a mock and never returns canned data.
final class UnavailableCactusService: CactusService {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func complete(system: String, user: String) async throws -> String {
        throw CactusError.initFailed(reason)
    }

    var sourceLabel: String { "UNAVAILABLE" }
    var isHealthy: Bool { false }
}

enum CactusError: Error, LocalizedError {
    case modelFileMissing(String)
    case initFailed(String)
    case completionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .modelFileMissing(let p): return "Gemma model file not found at \(p)"
        case .initFailed(let m): return "Cactus init failed: \(m)"
        case .completionFailed(let m): return "Completion failed: \(m)"
        case .invalidResponse: return "Invalid response from Cactus"
        }
    }
}

/// Real Cactus-backed inference. Wraps the API exposed by `Cactus.swift`,
/// which ships alongside `cactus-macos.xcframework`.
///
/// API reference (from the bundled Cactus.swift):
///   - `cactusInit(modelPath, corpusDir, cacheIndex)` throws -> `CactusModelT`
///   - `cactusComplete(model, messagesJson, optionsJson, toolsJson, onToken, pcmData)` throws -> `String`
///   - `cactusDestroy(model)`
final class RealCactusService: CactusService {
    private let model: CactusModelT
    // cactus_complete is not thread-safe against itself on the same model
    // pointer; overlapping calls corrupt the native runtime's KV state and
    // crash the process. Funnel every invocation through one serial queue so
    // the live-pane segment stream, the 30-second whisper tick, and the
    // research pane can never run inference concurrently.
    private let inferenceQueue = DispatchQueue(
        label: "com.broadcastbrain.cactus.inference",
        qos: .userInitiated
    )

    init(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw CactusError.modelFileMissing(modelPath)
        }
        do {
            self.model = try cactusInit(modelPath, nil, false)
        } catch {
            throw CactusError.initFailed(error.localizedDescription)
        }
    }

    deinit {
        cactusDestroy(model)
    }

    func complete(system: String, user: String) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "system", "content": system],
            ["role": "user", "content": user]
        ]
        let data = try JSONSerialization.data(withJSONObject: messages)
        guard let messagesJson = String(data: data, encoding: .utf8) else {
            throw CactusError.invalidResponse
        }

        let modelRef = self.model
        let queue = self.inferenceQueue
        let raw: String = try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    let value = try cactusComplete(modelRef, messagesJson, nil, nil, nil)
                    cont.resume(returning: value)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }

        return Self.extractContent(from: raw)
    }

    var sourceLabel: String { "REAL · GEMMA" }
    var isHealthy: Bool { true }

    /// Cactus chat completions have shipped at least three envelope shapes:
    ///   - OpenAI-compatible:  `.choices[0].message.content`
    ///   - Legacy:             top-level `.content`
    ///   - Current Cactus FFI: `{"success":true,"response":"<model output>", ...}`
    /// Gemma also likes to wrap structured output in ```json ... ``` fences even
    /// when the prompt asks for raw JSON. Normalize all of that here so callers
    /// only ever see the model's actual content, free of framing.
    static func extractContent(from raw: String) -> String {
        var content = raw
        if let data = raw.data(using: .utf8),
           let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let choices = top["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let c = message["content"] as? String {
                content = c
            } else if let c = top["content"] as? String {
                content = c
            } else if let c = top["response"] as? String {
                // New Cactus FFI envelope. Note: this branch also runs when
                // `success` is false — in that case we still surface whatever
                // partial `response` the runtime produced; the caller will
                // fail to parse and log it explicitly.
                content = c
            }
        }
        return stripCodeFences(content)
    }

    /// Trim a single surrounding markdown fence like ```json\n...\n``` or ```...```.
    /// Leaves content alone if no fence is present.
    static func stripCodeFences(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        // Drop the opening fence (optionally "```json" / "```JSON" etc.)
        var body = trimmed.dropFirst(3)
        if let newlineIdx = body.firstIndex(of: "\n") {
            let firstLine = body[..<newlineIdx].trimmingCharacters(in: .whitespaces)
            if firstLine.allSatisfy({ $0.isLetter }) {
                body = body[body.index(after: newlineIdx)...]
            }
        }
        // Drop a trailing fence if present.
        if let closeRange = body.range(of: "```", options: .backwards) {
            body = body[..<closeRange.lowerBound]
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
