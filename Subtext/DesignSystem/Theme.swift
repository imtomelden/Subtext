import SwiftUI

/// App-wide theming — accent colour preset and optional ambient background.
///
/// Inject once at the App level and read anywhere via
/// `@Environment(Theme.self)`.
///
///     // SubtextApp:
///     @State private var theme = Theme()
///     WindowGroup { ContentView() }
///         .environment(theme)
///         .tint(theme.accent)           // propagates to Color.accentColor
///
/// Persist changes by calling `setAccent(_:)` / `setAmbient(_:)` rather
/// than mutating properties directly — they write through to `UserDefaults`.
@Observable
final class Theme {

    // MARK: - Accent

    var accentPreset: AccentPreset = .teal

    /// The resolved `Color` for the current accent preset.
    var accent: Color { accentPreset.color }

    enum AccentPreset: String, CaseIterable, Identifiable {
        case teal
        case blue
        case purple
        case rose
        case orange

        var id: String { rawValue }

        var label: String {
            switch self {
            case .teal:   "Teal"
            case .blue:   "Blue"
            case .purple: "Purple"
            case .rose:   "Rose"
            case .orange: "Orange"
            }
        }

        var color: Color {
            switch self {
            case .teal:   Color(red: 0x1F / 255.0, green: 0x8A / 255.0, blue: 0x66 / 255.0)
            case .blue:   Color(red: 0x23 / 255.0, green: 0x76 / 255.0, blue: 0xF0 / 255.0)
            case .purple: Color(red: 0x7C / 255.0, green: 0x3A / 255.0, blue: 0xED / 255.0)
            case .rose:   Color(red: 0xE1 / 255.0, green: 0x1D / 255.0, blue: 0x48 / 255.0)
            case .orange: Color(red: 0xEA / 255.0, green: 0x58 / 255.0, blue: 0x0C / 255.0)
            }
        }
    }

    // MARK: - Ambient background

    var ambient: AmbientStyle = .none

    enum AmbientStyle: String, CaseIterable, Identifiable {
        case none
        case aurora
        case dusk
        case warmPaper

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none:      "None"
            case .aurora:    "Aurora"
            case .dusk:      "Dusk"
            case .warmPaper: "Warm Paper"
            }
        }
    }

    // MARK: - Persistence

    private static let accentKey  = "SubtextThemeAccentPreset"
    private static let ambientKey = "SubtextThemeAmbient"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.accentKey),
           let preset = AccentPreset(rawValue: raw) {
            accentPreset = preset
        }
        if let raw = UserDefaults.standard.string(forKey: Self.ambientKey),
           let style = AmbientStyle(rawValue: raw) {
            ambient = style
        }
    }

    func setAccent(_ preset: AccentPreset) {
        accentPreset = preset
        UserDefaults.standard.set(preset.rawValue, forKey: Self.accentKey)
    }

    func setAmbient(_ style: AmbientStyle) {
        ambient = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.ambientKey)
    }
}
