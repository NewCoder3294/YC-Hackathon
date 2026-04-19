import SwiftUI

@main
struct BroadcastBrainApp: App {
    @State private var installer = ModelInstaller()
    @State private var store: AppStore?
    @State private var theme: ThemeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    ContentView()
                        .environment(store)
                        .environment(theme)
                } else {
                    ModelSetupView(installer: installer)
                        .environment(theme)
                        .task { installer.install() }
                        .onChange(of: installer.state) { _, newState in
                            if case .installed = newState, store == nil {
                                store = Self.makeStore(modelDir: installer.modelDir)
                            }
                        }
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .preferredColorScheme(theme.mode.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
    }

    private static func makeStore(modelDir: URL) -> AppStore {
        let sessionStore = SessionStore()
        let cactus: CactusService = makeCactusService(modelDir: modelDir)
        let cacheDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BroadcastBrain/playbyplay", isDirectory: true)
        let pbp = PlayByPlayStore(cacheDirectory: cacheDir)
        let speech = SpeechSynthesisService()
        let whisper = WhisperEngine(cactus: cactus, tts: speech)
        return AppStore(
            sessionStore: sessionStore,
            cactus: cactus,
            playByPlayStore: pbp,
            speech: speech,
            whisperEngine: whisper
        )
    }

    private static func makeCactusService(modelDir: URL) -> CactusService {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelDir.path, isDirectory: &isDir),
              isDir.boolValue else {
            let msg = "Model directory missing at \(modelDir.path) after install — unexpected."
            print("⚠️ \(msg)")
            return UnavailableCactusService(reason: msg)
        }
        do {
            let real = try RealCactusService(modelPath: modelDir.path)
            print("✅ RealCactusService loaded from \(modelDir.path)")
            return real
        } catch {
            let msg = "RealCactusService init failed: \(error.localizedDescription)"
            print("⚠️ \(msg)")
            return UnavailableCactusService(reason: msg)
        }
    }
}
