import LuzzyCore
import LuzzyStore
import LuzzyUI
import StoreKit
import SwiftUI

struct MoreView: View {
    let session: Session

    @Environment(AppModel.self) private var app
    @Environment(PurchaseManager.self) private var purchases
    @State private var info = Resource<DataSourceInfo>()
    @State private var showingPaywall = false
    @State private var showingManageSubscriptions = false
    @State private var confirmingDisconnect = false

    var body: some View {
        NavigationStack {
            List {
                Section { serverRow }

                Section {
                    premiumRow
                }

                Section("Organizar") {
                    NavigationLink { BillsAndPiggyBanksView(session: session) } label: {
                        SettingsLabel("Facturas y huchas", systemImage: "calendar", color: .orange)
                    }
                    NavigationLink { CategoriesView(session: session) } label: {
                        SettingsLabel("Categorías", systemImage: "folder", color: LuzzyTheme.accent)
                    }
                    NavigationLink { TagsView(session: session) } label: {
                        SettingsLabel("Etiquetas", systemImage: "tag", color: .purple)
                    }
                }

                Section("Ajustes") {
                    NavigationLink { PrivacySettingsView(session: session) } label: {
                        SettingsLabel("Privacidad y seguridad", systemImage: "lock.shield", color: .blue)
                    }
                    NavigationLink { AboutView() } label: {
                        SettingsLabel("Acerca de Luzzy", systemImage: "info.circle", color: .gray)
                    }
                }

                Section {
                    Button(role: .destructive) { confirmingDisconnect = true } label: {
                        SettingsLabel(disconnectTitle, systemImage: "rectangle.portrait.and.arrow.right", color: LuzzyTheme.negative)
                    }
                } footer: {
                    if !session.isDemo {
                        Text("Se borrarán de este iPhone el token, la configuración y la caché de este servidor. Tus datos en Firefly III no se modifican.")
                    }
                }
            }
            .navigationTitle("Más")
            .task { await loadInfo() }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
            .confirmationDialog(disconnectQuestion, isPresented: $confirmingDisconnect, titleVisibility: .visible) {
                Button(disconnectConfirmation, role: .destructive) {
                    Task { await app.disconnect() }
                }
            }
        }
    }

    private var disconnectTitle: LocalizedStringKey {
        session.isDemo ? "Salir del modo demo" : "Desconectar servidor"
    }

    private var disconnectQuestion: LocalizedStringKey {
        session.isDemo ? "¿Salir del modo demo?" : "¿Desconectar el servidor?"
    }

    private var disconnectConfirmation: LocalizedStringKey {
        session.isDemo ? "Salir" : "Desconectar y borrar datos locales"
    }

    private var serverRow: some View {
        HStack(spacing: 14) {
            LuzzyMark(size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.profile?.displayName ?? String(localized: "Modo demo"))
                    .font(.headline)
                if let value = info.value {
                    Text([value.userEmail, value.serverVersion.map { "Firefly III \($0)" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let error = info.state.error {
                    Text(error.userMessage).font(.footnote).foregroundStyle(LuzzyTheme.negative)
                }
                if session.profile?.usesUnencryptedHTTP == true {
                    Label("Conexión sin cifrar (red local)", systemImage: "exclamationmark.shield")
                        .font(.caption)
                        .foregroundStyle(LuzzyTheme.warning)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var premiumRow: some View {
        switch purchases.entitlement {
        case .free:
            Button { showingPaywall = true } label: {
                SettingsLabel("Luzzy Premium", systemImage: "sparkles", color: LuzzyTheme.accent)
            }
            .foregroundStyle(.primary)
        case .lifetime:
            SettingsLabel("Luzzy Premium de por vida", systemImage: "checkmark.seal.fill", color: LuzzyTheme.accent)
        case .subscription(_, let expiresAt, let willRenew):
            Button { showingManageSubscriptions = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    SettingsLabel("Luzzy Premium", systemImage: "checkmark.seal.fill", color: LuzzyTheme.accent)
                    if let expiresAt {
                        Group {
                            if willRenew {
                                Text("Se renueva el \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                            } else {
                                Text("Activa hasta el \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 44)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private func loadInfo() async {
        let source = session.dataSource
        await info.load(key: nil, session: session) { try await source.info() }
    }
}

/// Etiqueta con icono en cuadrado de color, como en Ajustes de iOS.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color

    init(_ title: LocalizedStringKey, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    LuzzyMark(size: 72)
                    Text("Luzzy").font(.title.bold())
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                Text("Luzzy es un cliente independiente para Firefly III. No está afiliado al proyecto Firefly III.")
                Link("Política de privacidad", destination: AppConfiguration.privacyPolicyURL)
                Link("Términos de uso", destination: AppConfiguration.termsURL)
                Link("Firefly III", destination: URL(string: "https://www.firefly-iii.org")!)
            }
        }
        .navigationTitle("Acerca de")
    }
}
