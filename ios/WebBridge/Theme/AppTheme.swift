import SwiftUI

enum AppTheme {
    static let primary = Color(red: 21 / 255, green: 101 / 255, blue: 192 / 255)      // #1565C0
    static let primaryDark = Color(red: 13 / 255, green: 71 / 255, blue: 161 / 255)  // #0D47A1
    static let accent = Color(red: 38 / 255, green: 166 / 255, blue: 154 / 255)       // #26A69A
    static let background = Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255)  // #F5F7FA
    static let title = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)          // #0F172A
    static let subtitle = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)    // #64748B
}

enum AppDefaults {
    static let subdomain = "mhc"
    static let folder = "apps2"
}
