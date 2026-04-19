import Foundation
import Observation
import SwiftUI

/// App-wide theme + sidebar layout state. Persisted via UserDefaults so the
/// broadcaster's preference survives relaunch.
@Observable
final class ThemeStore {
    enum Mode: String {
        case dark
        case light

        var colorScheme: ColorScheme {
            switch self {
            case .dark: return .dark
            case .light: return .light
            }
        }
    }

    private let modeKey = "bb.theme.mode"
    private let collapsedKey = "bb.sidebar.collapsed"

    var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: modeKey) }
    }

    var sidebarCollapsed: Bool {
        didSet { UserDefaults.standard.set(sidebarCollapsed, forKey: collapsedKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: modeKey)
        self.mode = Mode(rawValue: stored ?? "") ?? .dark
        self.sidebarCollapsed = UserDefaults.standard.bool(forKey: collapsedKey)
    }

    func toggleMode() {
        withAnimation(.easeInOut(duration: 0.18)) {
            mode = (mode == .dark) ? .light : .dark
        }
    }

    func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarCollapsed.toggle()
        }
    }
}
