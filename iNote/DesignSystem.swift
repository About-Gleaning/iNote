import SwiftUI

struct AppColors {
    static let background = Color(hex: "F9F9F9") // Brighter background
    static let cardBackground = Color.white
    static let primaryText = Color(hex: "1A1A1A") // Near black for better contrast
    static let secondaryText = Color(hex: "555555") // Darker gray for better readability
    static let accent = Color(hex: "3498DB") // Muted Blue
    static let success = Color(hex: "27AE60")
    static let warning = Color(hex: "F39C12")
    static let error = Color(hex: "E74C3C")
    static let divider = Color(hex: "E0E0E0") // Slightly darker divider
}

struct AppFonts {
    static func title1() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func title2() -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func headline() -> Font { .system(size: 18, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 16, weight: .regular, design: .rounded) }
    static func subheadline() -> Font { .system(size: 14, weight: .regular, design: .rounded) }
    static func caption() -> Font { .system(size: 12, weight: .medium, design: .rounded) }
}

struct AppDimens {
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let cardElevation: CGFloat = 2
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .cornerRadius(AppDimens.cornerRadius)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
}
