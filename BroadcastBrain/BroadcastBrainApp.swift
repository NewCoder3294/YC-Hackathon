import SwiftUI

@main
struct BroadcastBrainApp: App {
    @State private var store: AppStore = Self.makeStore()
    @State private var theme: ThemeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(theme)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(theme.mode.colorScheme)
        }
    }

    private static func makeStore() -> AppStore {
        let sessionStore = SessionStore()
        let cactus: CactusService = makeCactusService()
        return AppStore(sessionStore: sessionStore, cactus: cactus)
    }

    private static func makeCactusService() -> CactusService {
        if ProcessInfo.processInfo.environment["MOCK_MODE"] == "1" {
            print("✅ MOCK_MODE=1 — using MockResponder")
            return MockResponder()
        }

        let modelURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BroadcastBrain/models/gemma.gguf")

        if FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                let real = try RealCactusService(modelPath: modelURL.path)
                print("✅ RealCactusService loaded from \(modelURL.path)")
                return real
            } catch {
                print("⚠️ RealCactusService init failed (\(error.localizedDescription)) — falling back to MockResponder")
                return MockResponder()
            }
        } else {
            print("⚠️ Gemma model not found at \(modelURL.path) — using MockResponder")
            return MockResponder()
        }
    }
}
