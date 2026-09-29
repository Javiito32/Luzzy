import LuzzyUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            switch app.phase {
            case .launching:
                LaunchView()
            case .onboarding:
                ConnectServerView()
                    .transition(.opacity)
            case .ready(let session):
                MainTabView(session: session)
                    .id(session.profile?.id ?? "demo")
                    .transition(.opacity)
            }

            if app.isLocked {
                AppLockView()
                    .transition(.opacity)
                    .zIndex(2)
            } else if app.isShielded {
                PrivacyShieldView()
                    .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.25), value: app.isLocked)
    }
}

/// Pantalla neutra durante el arranque.
struct LaunchView: View {
    var body: some View {
        LuzzyMark(size: 88)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LuzzyTheme.groupedBackground)
    }
}

/// Cubre los datos cuando la app pasa a segundo plano, para que la captura
/// del selector de apps no muestre saldos ni movimientos.
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            LuzzyMark(size: 72)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Logotipo de Luzzy (sol estilizado).
struct LuzzyMark: View {
    var size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LuzzyTheme.accent)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "sun.max")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: LuzzyTheme.accent.opacity(0.3), radius: 14, y: 8)
            .accessibilityHidden(true)
    }
}
