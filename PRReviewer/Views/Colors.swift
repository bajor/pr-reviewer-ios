import SwiftUI

// Gruvbox Dark color scheme
struct GruvboxColors {
    // Background colors
    static let bg0Hard = Color(red: 0.11, green: 0.11, blue: 0.10)      // #1d2021
    static let bg0 = Color(red: 0.16, green: 0.16, blue: 0.14)          // #282828
    static let bg1 = Color(red: 0.23, green: 0.22, blue: 0.20)          // #3c3836
    static let bg2 = Color(red: 0.31, green: 0.29, blue: 0.27)          // #504945
    static let bg3 = Color(red: 0.40, green: 0.38, blue: 0.35)          // #665c54
    static let bg4 = Color(red: 0.49, green: 0.46, blue: 0.42)          // #7c6f64

    // Foreground colors
    static let fg0 = Color(red: 0.98, green: 0.94, blue: 0.84)          // #fbf1c7
    static let fg1 = Color(red: 0.92, green: 0.86, blue: 0.70)          // #ebdbb2
    static let fg2 = Color(red: 0.84, green: 0.78, blue: 0.61)          // #d5c4a1
    static let fg3 = Color(red: 0.74, green: 0.69, blue: 0.55)          // #bdae93
    static let fg4 = Color(red: 0.66, green: 0.60, blue: 0.47)          // #a89984

    // Accent colors
    static let red = Color(red: 0.80, green: 0.14, blue: 0.11)          // #cc241d
    static let redLight = Color(red: 0.98, green: 0.29, blue: 0.20)     // #fb4934
    static let green = Color(red: 0.60, green: 0.59, blue: 0.10)        // #98971a
    static let greenLight = Color(red: 0.72, green: 0.73, blue: 0.15)   // #b8bb26
    static let yellow = Color(red: 0.84, green: 0.60, blue: 0.13)       // #d79921
    static let yellowLight = Color(red: 0.98, green: 0.74, blue: 0.18)  // #fabd2f
    static let blue = Color(red: 0.27, green: 0.52, blue: 0.53)         // #458588
    static let blueLight = Color(red: 0.51, green: 0.65, blue: 0.60)    // #83a598
    static let purple = Color(red: 0.69, green: 0.38, blue: 0.53)       // #b16286
    static let purpleLight = Color(red: 0.83, green: 0.53, blue: 0.66)  // #d3869b
    static let aqua = Color(red: 0.41, green: 0.62, blue: 0.42)         // #689d6a
    static let aquaLight = Color(red: 0.56, green: 0.75, blue: 0.49)    // #8ec07c
    static let orange = Color(red: 0.84, green: 0.36, blue: 0.06)       // #d65d0e
    static let orangeLight = Color(red: 0.99, green: 0.52, blue: 0.15)  // #fe8019

    // Diff colors (dark backgrounds)
    static let diffAdditionBg = Color(red: 0.08, green: 0.22, blue: 0.08)     // Dark green background
    static let diffDeletionBg = Color(red: 0.28, green: 0.08, blue: 0.08)     // Dark red background
    static let diffContextBg = bg0

    // Comment colors
    static let commentBg = Color(red: 0.30, green: 0.28, blue: 0.22)          // Slightly different from bg
    static let commentBorder = yellow
}

// Extension for diff line colors
extension DiffLine {
    var gruvboxBackgroundColor: Color {
        switch type {
        case .addition: return GruvboxColors.diffAdditionBg
        case .deletion: return GruvboxColors.diffDeletionBg
        case .context: return GruvboxColors.bg0  // Normal background
        case .hunkHeader: return GruvboxColors.bg1
        }
    }

    // White text for all code
    var gruvboxTextColor: Color {
        switch type {
        case .hunkHeader: return GruvboxColors.fg4
        default: return GruvboxColors.fg0  // White/light text for all code
        }
    }
}
