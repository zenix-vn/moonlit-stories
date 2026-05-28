import SwiftUI

enum MoonlitTheme {
    enum ColorToken {
        static let background = Color(red: 0.035, green: 0.025, blue: 0.075)
        static let backgroundMid = Color(red: 0.080, green: 0.045, blue: 0.150)
        static let backgroundDeep = Color(red: 0.030, green: 0.025, blue: 0.060)
        static let surface = Color(red: 0.094, green: 0.071, blue: 0.145)
        static let elevatedSurface = Color(red: 0.137, green: 0.102, blue: 0.208)
        static let primary = Color(red: 0.635, green: 0.459, blue: 1.000)
        static let secondary = Color(red: 1.000, green: 0.620, blue: 0.470)
        static let accent = Color(red: 0.420, green: 0.820, blue: 0.900)
        static let gold = Color(red: 1.000, green: 0.800, blue: 0.360)
        static let onSurface = Color(red: 0.965, green: 0.945, blue: 1.000)
        static let onSurfaceMuted = Color(red: 0.710, green: 0.670, blue: 0.820)
        static let onPrimaryAction = Color(red: 0.070, green: 0.045, blue: 0.110)
        static let outline = Color.white.opacity(0.14)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }
}
