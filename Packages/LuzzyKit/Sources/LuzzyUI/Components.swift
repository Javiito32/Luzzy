import LuzzyCore
import SwiftUI

// MARK: - Modo discreto

private struct AmountsHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Oculta todos los importes (modo discreto) para usar la app en público.
    var amountsHidden: Bool {
        get { self[AmountsHiddenKey.self] }
        set { self[AmountsHiddenKey.self] = newValue }
    }
}

/// Importe formateado que respeta el modo discreto y colorea según el signo.
public struct MoneyText: View {
    public enum Coloring: Sendable {
        case none
        /// Verde para positivos; los negativos quedan en el color principal.
        case positiveHighlight
        /// Rojo para negativos.
        case negativeHighlight
    }

    private let money: Money
    private let showsSign: Bool
    private let coloring: Coloring
    @Environment(\.amountsHidden) private var hidden
    @Environment(\.locale) private var locale

    public init(_ money: Money, showsSign: Bool = false, coloring: Coloring = .none) {
        self.money = money
        self.showsSign = showsSign
        self.coloring = coloring
    }

    public var body: some View {
        let text = Text(hidden ? "••••" : money.formatted(locale: locale, showsSign: showsSign))
        Group {
            if let color {
                text.foregroundStyle(color)
            } else {
                text
            }
        }
        .contentTransition(.numericText())
        .accessibilityLabel(hidden ? Text(verbatim: "••••") : Text(money.formatted(locale: locale)))
    }

    /// `nil` hereda el estilo del contenedor.
    private var color: Color? {
        switch coloring {
        case .none: nil
        case .positiveHighlight: money.amount > 0 ? LuzzyTheme.positive : nil
        case .negativeHighlight: money.amount < 0 ? LuzzyTheme.negative : nil
        }
    }
}

// MARK: - Piezas comunes

/// Avatar circular con la inicial de un nombre.
public struct InitialAvatar: View {
    private let name: String
    private let size: CGFloat

    public init(_ name: String, size: CGFloat = 40) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let colors = LuzzyTheme.avatarColors(for: name)
        Text(String(name.trimmingCharacters(in: .whitespaces).first ?? "·").uppercased())
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(colors.foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(colors.background))
            .accessibilityHidden(true)
    }
}

/// Barra de progreso de presupuestos y huchas.
public struct ProgressBar: View {
    private let progress: Double
    private let tint: Color

    public init(progress: Double, tint: Color = LuzzyTheme.accent) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(tint).frame(width: max(proxy.size.width * progress, progress > 0 ? 8 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

/// Anillo de progreso para resúmenes.
public struct ProgressRing: View {
    private let progress: Double
    private let lineWidth: CGFloat

    public init(progress: Double, lineWidth: CGFloat = 12) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LuzzyTheme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(LuzzyTheme.amountFont(.title3, weight: .bold))
        }
    }
}

/// Etiqueta de estado en cápsula.
public struct StatusBadge: View {
    private let title: Text
    private let tint: Color

    public init(_ title: Text, tint: Color) {
        self.title = title
        self.tint = tint
    }

    public var body: some View {
        title
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
