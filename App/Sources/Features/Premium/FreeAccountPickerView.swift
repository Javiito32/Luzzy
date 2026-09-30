import LuzzyCore
import LuzzyUI
import SwiftUI

/// Elección de la única cuenta del plan gratuito.
struct FreeAccountPickerView: View {
    let session: Session
    /// `true` cuando se abre desde Más para cambiar de cuenta (se puede cerrar).
    var isChanging = false

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var resource = Resource<[Account]>()
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("La versión gratuita de Luzzy gestiona una cuenta: sus gastos e ingresos. Con Premium tendrás todas tus cuentas, transferencias y planificación.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                if let accounts = resource.value {
                    Section("Tus cuentas") {
                        if accounts.isEmpty {
                            Text("No hay cuentas de activo. Crea una en tu servidor y vuelve a intentarlo.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(accounts) { account in
                            Button {
                                app.selectFreeAccount(account.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    InitialAvatar(account.name)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.name).foregroundStyle(.primary)
                                        if let masked = account.maskedNumber {
                                            Text(masked).font(.footnote).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if account.id == app.accessScope.limitedAccountID {
                                        Image(systemName: "checkmark").foregroundStyle(LuzzyTheme.accent)
                                    }
                                }
                            }
                        }
                    }
                } else if let error = resource.state.error {
                    Section {
                        Text(error.userMessage).foregroundStyle(.secondary)
                        Button("Reintentar") { Task { await load() } }
                    }
                } else {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                }

                Section {
                    Button { showingPaywall = true } label: {
                        Label("Usar todas mis cuentas con Premium", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("Elige tu cuenta")
            .toolbar {
                if isChanging {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!isChanging)
            .task { await load() }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }

    private func load() async {
        let source = session.dataSource
        await resource.load(key: CacheKey.accounts(.asset), session: session) {
            try await source.accounts.accounts(kind: .asset, balanceDate: nil)
                .filter(\.isActive)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
