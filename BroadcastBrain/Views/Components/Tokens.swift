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

    static let bgBase      = Color(hex: "#050505")
    static let bgRaised    = Color(hex: "#0A0A0A")
    static let bgSubtle    = Color(hex: "#141414")
    static let bgHover     = Color(hex: "#171717")
    static let bbBorder    = Color(hex: "#262626")
    static let borderSoft  = Color(hex: "#1A1A1A")
    static let textPrimary = Color(hex: "#FAFAFA")
    static let textMuted   = Color(hex: "#A3A3A3")
    static let textSubtle  = Color(hex: "#737373")
    static let live        = Color(hex: "#EF4444")
    static let verified    = Color(hex: "#10B981")
    static let esoteric    = Color(hex: "#F59E0B")
    static let tactical    = Color(hex: "#F97316")
}

enum Typography {
    static let heroStat    = Font.system(size: 48, weight: .medium, design: .monospaced)
    static let statLabel   = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let chip        = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let body        = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let playerName  = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let sectionHead = Font.system(size: 11, weight: .semibold, design: .monospaced)
}
