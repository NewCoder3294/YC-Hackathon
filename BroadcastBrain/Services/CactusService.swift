import Foundation

/// Contract for the on-device LLM backend. Implemented by `RealCactusService`
/// (Gemma on Cactus).
///
/// `sourceLabel` and `isHealthy` exist so the UI can display at a glance
/// whether whispers are actually hitting Gemma or silently falling back.
protocol CactusService: AnyObject {
    /// Run inference with optional audio input. When `audioPath` is non-nil
    /// the WAV file at that path is included in the user message as
    /// `"audio":["path"]`, enabling Gemma 4's multimodal audio understanding.
    func complete(system: String, user: String, audioPath: String?) async throws -> String

    /// Short human-readable label for the status pill.
    var sourceLabel: String { get }

    /// True when `complete(...)` has a realistic chance of returning useful output.
    var isHealthy: Bool { get }
}

extension CactusService {
    /// Convenience overload — no audio input.
    func complete(system: String, user: String) async throws -> String {
        try await complete(system: system, user: user, audioPath: nil)
    }
}

/// Stand-in used when the Gemma model is missing or failed to initialize.
final class UnavailableCactusService: CactusService {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func complete(system: String, user: String, audioPath: String?) async throws -> String {
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

/// Real Cactus-backed inference. Wraps the API exposed by `Cactus.swift`.
///
/// Audio is included in the messages JSON using the Cactus/Gemma4 multimodal
/// format: `{"role":"user","content":"...","audio":["path/to/file.wav"]}`.
/// This lets Gemma hear the broadcaster's audio alongside play-by-play context.
final class RealCactusService: CactusService {
    private let model: CactusModelT
    // cactus_complete is not thread-safe against itself on the same model
    // pointer; funnel every invocation through one serial queue.
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

    func complete(system: String, user: String, audioPath: String? = nil) async throws -> String {
        var userMsg: [String: Any] = ["role": "user", "content": user]
        if let path = audioPath {
            userMsg["audio"] = [path]
        }
        let messages: [[String: Any]] = [
            ["role": "system", "content": system],
            userMsg
        ]
        // Cactus's hand-rolled JSON parser (cactus_utils.h parse_path_array)
        // does not unescape "\/" in the audio[] array — it then passes the
        // literal backslash-laden string to std::filesystem::absolute(), which
        // treats it as relative and prepends the sandbox working dir.
        // `.withoutEscapingSlashes` keeps "/" literal so the parser sees the
        // real absolute path.
        let data = try JSONSerialization.data(
            withJSONObject: messages,
            options: [.withoutEscapingSlashes]
        )
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
                content = c
            }
        }
        return stripCodeFences(content)
    }

    static func stripCodeFences(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        var body = trimmed.dropFirst(3)
        if let newlineIdx = body.firstIndex(of: "\n") {
            let firstLine = body[..<newlineIdx].trimmingCharacters(in: .whitespaces)
            if firstLine.allSatisfy({ $0.isLetter }) {
                body = body[body.index(after: newlineIdx)...]
            }
        }
        if let closeRange = body.range(of: "```", options: .backwards) {
            body = body[..<closeRange.lowerBound]
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
