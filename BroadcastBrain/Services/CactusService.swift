import Foundation

/// Contract for whatever backend surfaces stat-card JSON.
/// Both `RealCactusService` (Gemma on Cactus) and `MockResponder` conform.
protocol CactusService: AnyObject {
    func complete(system: String, user: String) async throws -> String
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

        // Run off the MainActor — cactusComplete is synchronous/blocking.
        let modelRef = self.model
        let raw: String = try await Task.detached(priority: .userInitiated) {
            try cactusComplete(modelRef, messagesJson, nil, nil, nil)
        }.value

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
