import FireflyAPI
import LuzzyUI
import SwiftUI

struct ConnectServerView: View {
    @Environment(AppModel.self) private var app
    @State private var model = ConnectServerModel()
    @FocusState private var focused: Field?

    enum Field { case url, token, clientID }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 28) {
                header
                form
                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(LuzzyTheme.groupedBackground)
        .safeAreaInset(edge: .bottom) { actions }
        .sheet(item: $model.pendingCertificate) { pending in
            CertificateTrustSheet(pending: pending) {
                Task { await model.trustPendingCertificate(app: app) }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            LuzzyMark(size: 88)
            Text("Luzzy")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Conecta tu servidor Firefly III y gestiona tus finanzas desde el iPhone.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var form: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            FieldCard(title: "URL del servidor") {
                TextField("https://firefly.tudominio.com", text: $model.urlText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .url)
                    .submitLabel(.next)
            }
            if model.showsLocalHTTPWarning {
                Label("Conexión sin cifrar en tu red local. Usa HTTPS si el servidor es accesible desde fuera.", systemImage: "exclamationmark.shield")
                    .font(.footnote)
                    .foregroundStyle(LuzzyTheme.warning)
                    .padding(.horizontal, 6)
            }

            Picker("Método de acceso", selection: $model.method) {
                Text("Token personal").tag(ConnectServerModel.Method.token)
                Text("OAuth").tag(ConnectServerModel.Method.oauth)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 6)

            switch model.method {
            case .token:
                FieldCard(title: "Token de acceso personal") {
                    SecureField("Pega aquí tu token", text: $model.token)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .token)
                }
                Text("Créalo en Firefly III › Opciones › Perfil › OAuth › Tokens de acceso personales.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            case .oauth:
                FieldCard(title: "Client ID") {
                    TextField("p. ej. 4", text: $model.clientID)
                        .keyboardType(.numberPad)
                        .focused($focused, equals: .clientID)
                }
                Text("Crea un cliente OAuth NO confidencial con la redirección \(FireflyOAuthClient.redirectURI). Iniciarás sesión en una ventana privada que no guarda cookies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            DisclosureGroup("Opciones avanzadas") {
                Toggle("Anclar el certificado del servidor", isOn: $model.pinCertificate)
                    .padding(.top, 8)
                Text("Solo se aceptará exactamente este certificado. Si lo renuevas tendrás que volver a conectar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)

            if let error = model.errorMessage {
                Label(error, systemImage: "xmark.octagon")
                    .font(.footnote)
                    .foregroundStyle(LuzzyTheme.negative)
                    .padding(.horizontal, 6)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private var privacyNote: some View {
        Label("Luzzy solo se comunica con tu servidor. Sin analítica, sin anuncios, sin terceros. Las credenciales se guardan en el Llavero de este iPhone.", systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                focused = nil
                Task { await model.connect(app: app) }
            } label: {
                if model.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("Conectar")
                }
            }
            .buttonStyle(ProminentCapsuleButtonStyle())
            .disabled(!model.canSubmit)
            .opacity(model.canSubmit ? 1 : 0.5)

            Button("Probar con datos de ejemplo") {
                app.startDemo()
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(.bar)
    }
}

/// Campo agrupado en tarjeta, al estilo de Ajustes.
private struct FieldCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content
                .font(.body)
                .frame(minHeight: 28)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luzzyCard()
    }
}

/// Confirmación explícita de un certificado autofirmado (TOFU).
private struct CertificateTrustSheet: View {
    let pending: ConnectServerModel.PendingCertificate
    let onTrust: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("El certificado de este servidor no está firmado por una autoridad reconocida. Esto es normal en servidores caseros con certificado propio.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(LuzzyTheme.warning)
                }
                Section("Servidor") {
                    Text(pending.url.host() ?? "")
                    if let subject = pending.inspection.subjectSummary {
                        LabeledContent("Certificado", value: subject)
                    }
                }
                Section {
                    Text(pending.inspection.fingerprint.formatted)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                } header: {
                    Text("Huella SHA-256")
                } footer: {
                    Text("Compárala con la de tu servidor antes de confiar. Luzzy solo aceptará este certificado exacto; si cambia, bloqueará la conexión.")
                }
            }
            .navigationTitle("¿Confiar en el certificado?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confiar") {
                        dismiss()
                        onTrust()
                    }
                }
            }
        }
    }
}
