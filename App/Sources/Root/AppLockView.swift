import LuzzySecurity
import LuzzyUI
import SwiftUI

struct AppLockView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            LuzzyMark(size: 80)
            Text("Luzzy está bloqueada")
                .font(.title2.bold())
            Spacer()
            Button {
                Task { await app.unlock() }
            } label: {
                Label(unlockTitle, systemImage: unlockIcon)
            }
            .buttonStyle(ProminentCapsuleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .task { await app.unlock() }
    }

    private var unlockTitle: LocalizedStringKey {
        switch app.biometryKind {
        case .faceID: "Desbloquear con Face ID"
        case .touchID: "Desbloquear con Touch ID"
        case .opticID: "Desbloquear con Optic ID"
        case .none: "Desbloquear"
        }
    }

    private var unlockIcon: String {
        switch app.biometryKind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock.open"
        }
    }
}
