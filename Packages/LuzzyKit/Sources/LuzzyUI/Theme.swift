import SwiftUI

/// Colores de la app. Se adaptan automáticamente a modo claro/oscuro
/// usando los colores semánticos del sistema salvo el acento de marca.
public enum LuzzyTheme {
    /// Verde Luzzy (contraste AA sobre blanco y con texto blanco encima).
    public static let accent = Color(red: 0.110, green: 0.420, blue: 0.341)
    public static let positive = Color(red: 0.110, green: 0.420, blue: 0.341)
    public static let negative = Color(red: 0.753, green: 0.212, blue: 0.173)
    public static let transfer = Color(red: 0.145, green: 0.275, blue: 0.478)
    public static let warning = Color(red: 0.780, green: 0.478, blue: 0.071)

    /// Superficie de tarjetas sobre el fondo agrupado del sistema.
    public static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.secondary.opacity(0.08)
        #endif
    }

    public static var groupedBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color.clear
        #endif
    }

    public static let cardCornerRadius: CGFloat = 24
    public static let heroCornerRadius: CGFloat = 30

    /// Fuente para cifras: redondeada y con dígitos tabulares.
    public static func amountFont(_ style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }

    /// Paleta para avatares a partir de un texto (estable entre ejecuciones).
    public static func avatarColors(for seed: String) -> (background: Color, foreground: Color) {
        let palette: [(Color, Color)] = [
            (Color(red: 0.87, green: 0.94, blue: 0.91), Color(red: 0.11, green: 0.42, blue: 0.34)),
            (Color(red: 0.98, green: 0.92, blue: 0.82), Color(red: 0.54, green: 0.31, blue: 0.00)),
            (Color(red: 0.87, green: 0.91, blue: 0.96), Color(red: 0.15, green: 0.27, blue: 0.48)),
            (Color(red: 0.96, green: 0.88, blue: 0.87), Color(red: 0.56, green: 0.20, blue: 0.13)),
            (Color(red: 0.93, green: 0.89, blue: 0.96), Color(red: 0.33, green: 0.23, blue: 0.48)),
        ]
        let index = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF } % palette.count
        return palette[index]
    }
}
