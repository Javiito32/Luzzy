import LuzzyUI
import SwiftUI

struct PrivacySettingsView: View {
    let session: Session

    @Environment(AppModel.self) private var app
    @Environment(AppSettings.self) private var settings
    @State private var confirmingErase = false
    @State private var cacheCleared = false

    var body: some View {
        @Bindable var settings = settings
        List {
            Section {
                Toggle(isOn: $settings.appLockEnabled) {
                    SettingsLabel(lockTitle, systemImage: lockIcon, color: .blue)
                }
                .disabled(!app.canUseAppLock)
                if settings.appLockEnabled {
                    Picker("Bloquear", selection: $settings.lockTimeout) {
                        Text("Al salir de la app").tag(AppSettings.LockTimeout.immediately)
                        Text("Tras 1 minuto").tag(AppSettings.LockTimeout.oneMinute)
                        Text("Tras 5 minutos").tag(AppSettings.LockTimeout.fiveMinutes)
                        Text("Tras 15 minutos").tag(AppSettings.LockTimeout.fifteenMinutes)
                    }
                }
            } footer: {
                if app.canUseAppLock {
                    Text("Al volver a la app se pedirá tu cara, huella o código del iPhone.")
                } else {
                    Text("Configura un código en el iPhone para poder bloquear la app.")
                }
            }

            Section {
                Toggle(isOn: $settings.amountsHidden) {
                    SettingsLabel("Modo discreto", systemImage: "eye.slash", color: .indigo)
                }
            } footer: {
                Text("Oculta todos los importes para usar la app en público. En el selector de apps el contenido siempre se oculta.")
            }

            if let profile = session.profile {
                Section("Conexión") {
                    LabeledContent("Servidor", value: profile.displayName)
                    LabeledContent("Cifrado") {
                        if profile.usesUnencryptedHTTP { Text("No (red local)") } else { Text(verbatim: "TLS") }
                    }
                    LabeledContent("Acceso") {
                        switch profile.authMethod {
                        case .personalAccessToken: Text("Token personal")
                        case .oauth: Text("OAuth (PKCE)")
                        }
                    }
                    if let fingerprint = profile.trust.pinnedFingerprint {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Certificado anclado")
                            Text(fingerprint.formatted)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section {
                Button("Borrar caché local") {
                    Task {
                        await app.clearCache()
                        cacheCleared = true
                    }
                }
                Button("Borrar todos los datos de Luzzy", role: .destructive) { confirmingErase = true }
            } header: {
                Text("Datos en este iPhone")
            } footer: {
                Text("La caché permite ver tus datos sin conexión. Está cifrada con una clave que solo existe en este iPhone y nunca se incluye en copias de seguridad.")
            }

            Section("Qué hace Luzzy con tus datos") {
                PrivacyFact(icon: "server.rack", text: "Solo se conecta a tu servidor y al App Store (para las compras).")
                PrivacyFact(icon: "chart.bar.xaxis", text: "Sin analítica, sin publicidad, sin SDKs de terceros.")
                PrivacyFact(icon: "key", text: "El token se guarda en el Llavero, solo en este dispositivo y sin sincronizar con iCloud.")
                PrivacyFact(icon: "internaldrive", text: "La caché está cifrada (AES-256) y protegida mientras el iPhone está bloqueado.")
            }
        }
        .navigationTitle("Privacidad y seguridad")
        .alert("Caché borrada", isPresented: $cacheCleared) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmingErase, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) {
                Task { await app.eraseEverything() }
            }
        } message: {
            Text("Se eliminarán servidores, tokens, caché y ajustes de este iPhone. Tus datos en Firefly III no se modifican.")
        }
    }

    private var lockTitle: LocalizedStringKey {
        switch app.biometryKind {
        case .faceID: "Bloquear con Face ID"
        case .touchID: "Bloquear con Touch ID"
        case .opticID: "Bloquear con Optic ID"
        case .none: "Bloquear con código"
        }
    }

    private var lockIcon: String {
        switch app.biometryKind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock"
        }
    }
}

private struct PrivacyFact: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: icon).foregroundStyle(LuzzyTheme.accent)
        }
    }
}
