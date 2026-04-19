import Foundation

/// Contract for the on-device LLM backend. Implemented by `RealCactusService`
/// (Gemma on Cactus).
protocol CactusService: AnyObject {
    func complete(system: String, user: String) async throws -> String
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

    /// Cactus chat completions return an envelope with `.choices[0].message.content`.
    /// Some configurations return the content string directly. Handle both.
    private static func extractContent(from raw: String) -> String {
        guard
            let data = raw.data(using: .utf8),
            let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return raw
        }
        if let choices = top["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        if let content = top["content"] as? String {
            return content
        }
        return raw
    }
}
