import SwiftUI

// Liquid Glass (iOS 26) con alternativa de materiales para iOS 17/18.
//
// Regla de Apple: el cristal es para la capa de controles y navegación
// (barras, botones flotantes, hojas). El contenido usa superficies sólidas.

public extension View {
    /// Aplica cristal interactivo en iOS 26 o un material translúcido en versiones anteriores.
    @ViewBuilder
    func luzzyGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = true) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            glassEffect(LuzzyGlass.make(tint: tint, interactive: interactive), in: shape)
        } else {
            modifier(LegacyGlass(shape: shape, tint: tint))
        }
        #else
        modifier(LegacyGlass(shape: shape, tint: tint))
        #endif
    }

    /// Superficie sólida para contenido (tarjetas, listas).
    func luzzyCard(cornerRadius: CGFloat = LuzzyTheme.cardCornerRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LuzzyTheme.cardBackground)
        )
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, macOS 26.0, *)
private enum LuzzyGlass {
    static func make(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}
#endif

/// Material translúcido con brillo de borde para iOS 17 y 18.
private struct LegacyGlass<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint { shape.fill(tint.opacity(0.9)) }
                shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
    }
}

/// Botón circular de cristal para la barra superior (44 pt, objetivo táctil mínimo).
public struct GlassIconButton: View {
    private let systemImage: String
    private let accessibilityLabel: Text
    private let prominent: Bool
    private let action: () -> Void

    public init(systemImage: String, accessibilityLabel: Text, prominent: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.prominent = prominent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .luzzyGlass(in: Circle(), tint: prominent ? LuzzyTheme.accent : nil)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Estilo de botón principal en cápsula.
public struct ProminentCapsuleButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(LuzzyTheme.accent))
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
