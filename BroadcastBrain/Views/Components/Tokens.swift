import AppKit
import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves at draw time based on the current NSAppearance.
    /// Works with `.preferredColorScheme(...)` — when the app-level scheme flips,
    /// NSAppearance flips with it and this color re-resolves.
    static func themed(light lightHex: String, dark darkHex: String) -> Color {
        let ns = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? darkHex : lightHex)
        }
        return Color(nsColor: ns)
    }

    // ── Theme tokens ────────────────────────────────────────────────
    static let bgBase      = Color.themed(light: "#F7F7F6", dark: "#050505")
    static let bgRaised    = Color.themed(light: "#FFFFFF", dark: "#0A0A0A")
    static let bgSubtle    = Color.themed(light: "#EFEFED", dark: "#141414")
    static let bgHover     = Color.themed(light: "#E6E6E3", dark: "#171717")
    static let bbBorder    = Color.themed(light: "#D4D4D3", dark: "#262626")
    static let borderSoft  = Color.themed(light: "#E5E5E4", dark: "#1A1A1A")
    static let textPrimary = Color.themed(light: "#0A0A0A", dark: "#FAFAFA")
    static let textMuted   = Color.themed(light: "#525251", dark: "#A3A3A3")
    static let textSubtle  = Color.themed(light: "#8A8A89", dark: "#737373")

    // Strong edge used to separate the sidebar from the main content — inverts
    // with theme so it's always visible: near-black in light mode, near-white in dark.
    static let sidebarEdge = Color.themed(light: "#0A0A0A", dark: "#FAFAFA")

    // Semantic accents — same hue, slightly shifted for contrast in light mode.
    static let live        = Color.themed(light: "#DC2626", dark: "#EF4444")
    static let verified    = Color.themed(light: "#059669", dark: "#10B981")
    static let esoteric    = Color.themed(light: "#D97706", dark: "#F59E0B")
}

extension NSColor {
    fileprivate convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v & 0xFF0000) >> 16) / 255
        let g = CGFloat((v & 0x00FF00) >> 8) / 255
        let b = CGFloat(v & 0x0000FF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

enum Typography {
    static let heroStat    = Font.system(size: 48, weight: .medium, design: .monospaced)
    static let statLabel   = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let chip        = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let body        = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let playerName  = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let sectionHead = Font.system(size: 11, weight: .semibold, design: .monospaced)
}
