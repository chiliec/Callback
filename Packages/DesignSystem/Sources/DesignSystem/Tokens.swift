import SwiftUI

public enum DSColor {
    // Action / status — prefer system semantics.
    public static let action = Color(.sRGB, red: 0x00/255, green: 0x7A/255, blue: 0xFF/255)
    public static let actionTint = action.opacity(0.15)
    public static let selectionTint = action.opacity(0.08)

    public static let green = Color(.sRGB, red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
    public static let greenText = Color(.sRGB, red: 0x24/255, green: 0x8A/255, blue: 0x3D/255)
    public static let orange = Color(.sRGB, red: 0xFF/255, green: 0x95/255, blue: 0x00/255)
    public static let orangeText = Color(.sRGB, red: 0xC9/255, green: 0x34/255, blue: 0x00/255)
    public static let red = Color(.sRGB, red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)
    public static let redText = Color(.sRGB, red: 0xD7/255, green: 0x00/255, blue: 0x15/255)

    // Surfaces / text — system semantics so dark mode derives.
    #if canImport(UIKit)
    public static let groupedBackground = Color(.systemGroupedBackground)
    public static let card = Color(.secondarySystemGroupedBackground)
    public static let fill = Color(.sRGB, red: 118/255, green: 118/255, blue: 128/255).opacity(0.12)
    public static let label = Color(.label)
    public static let secondaryLabel = Color(.secondaryLabel)
    public static let tertiaryLabel = Color(.tertiaryLabel)
    public static let separator = Color(.sRGB, red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)
    public static let ringTrack = Color(.systemGray5)
    public static let tabInactive = Color(.sRGB, red: 0x8E/255, green: 0x8E/255, blue: 0x93/255)
    #else
    public static let groupedBackground = Color(NSColor.windowBackgroundColor)
    public static let card = Color(NSColor.controlBackgroundColor)
    public static let fill = Color(.sRGB, red: 118/255, green: 118/255, blue: 128/255).opacity(0.12)
    public static let label = Color(NSColor.labelColor)
    public static let secondaryLabel = Color(NSColor.secondaryLabelColor)
    public static let tertiaryLabel = Color(NSColor.tertiaryLabelColor)
    public static let separator = Color(.sRGB, red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)
    public static let ringTrack = Color(NSColor.systemGray)
    public static let tabInactive = Color(.sRGB, red: 0x8E/255, green: 0x8E/255, blue: 0x93/255)
    #endif

    /// Topic tile colors keyed by `colorToken`.
    public static func topic(_ token: String) -> Color {
        switch token {
        case "swift":        return Color(.sRGB, red: 0x00/255, green: 0x7A/255, blue: 0xFF/255)
        case "memory":       return Color(.sRGB, red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)
        case "concurrency":  return Color(.sRGB, red: 0xFF/255, green: 0x95/255, blue: 0x00/255)
        case "swiftui":      return Color(.sRGB, red: 0xAF/255, green: 0x52/255, blue: 0xDE/255)
        case "uikit":        return Color(.sRGB, red: 0x58/255, green: 0x56/255, blue: 0xD6/255)
        case "networking":   return Color(.sRGB, red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
        case "coredata":     return Color(.sRGB, red: 0x30/255, green: 0xB0/255, blue: 0xC7/255)
        case "systemdesign": return Color(.sRGB, red: 0x32/255, green: 0xAD/255, blue: 0xE6/255)
        case "testing":      return Color(.sRGB, red: 0x00/255, green: 0xC7/255, blue: 0xBE/255)
        case "architecture": return Color(.sRGB, red: 0xA2/255, green: 0x84/255, blue: 0x5E/255)
        case "behavioral":   return Color(.sRGB, red: 0xFF/255, green: 0x2D/255, blue: 0x55/255)
        default:             return action
        }
    }
}

public enum DSRadius {
    public static let card: CGFloat = 26
    public static let control: CGFloat = 14
    public static let button: CGFloat = 12
    public static let tile: CGFloat = 7
    public static let tileLarge: CGFloat = 10
    public static let appIcon: CGFloat = 22
}

public enum DSSpacing {
    public static let listInset: CGFloat = 16
    public static let sessionInset: CGFloat = 20
    public static let rowMinHeight: CGFloat = 52
}

public enum DSFont {
    public static let largeTitle   = Font.system(.largeTitle, design: .default).weight(.bold)
    public static let readerTitle  = Font.system(.title, design: .default).weight(.bold)
    public static let scoreHeadline = Font.system(.title2, design: .default).weight(.bold)
    public static let question     = Font.system(.title3, design: .default).weight(.bold)
    public static let headline     = Font.system(.headline, design: .default)
    public static let body         = Font.system(.body, design: .default)
    public static let subheadline  = Font.system(.subheadline, design: .default)
    public static let sectionHeader = Font.system(.subheadline, design: .default).weight(.semibold)
    public static let footnote     = Font.system(.footnote, design: .default)
    public static let badge        = Font.system(.caption2, design: .default)
    public static let tabLabel     = Font.system(.caption2, design: .default)
}

public enum DSCode {
    public static let background = Color(.sRGB, red: 0x23/255, green: 0x24/255, blue: 0x2B/255)
    public static let border = Color(.sRGB, red: 0x33/255, green: 0x34/255, blue: 0x3C/255)
    public static let header = Color(.sRGB, red: 0x8E/255, green: 0x93/255, blue: 0xA3/255)
    public static let gutter = Color(.sRGB, red: 0x56/255, green: 0x5B/255, blue: 0x66/255)

    public static let keyword = Color(.sRGB, red: 0xFC/255, green: 0x5F/255, blue: 0xA3/255)
    public static let type = Color(.sRGB, red: 0xD0/255, green: 0xA8/255, blue: 0xFF/255)
    public static let functionDecl = Color(.sRGB, red: 0x5D/255, green: 0xD8/255, blue: 0xFF/255)
    public static let call = Color(.sRGB, red: 0x67/255, green: 0xB7/255, blue: 0xA4/255)
    public static let string = Color(.sRGB, red: 0xFC/255, green: 0x6A/255, blue: 0x5D/255)
    public static let number = Color(.sRGB, red: 0xD0/255, green: 0xBF/255, blue: 0x69/255)
    public static let comment = Color(.sRGB, red: 0x7F/255, green: 0x8C/255, blue: 0x98/255)
    public static let plain = Color(.sRGB, red: 0xDF/255, green: 0xDF/255, blue: 0xE0/255)
}
