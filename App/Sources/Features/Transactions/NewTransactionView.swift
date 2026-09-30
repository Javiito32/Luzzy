import LuzzyCore
import LuzzyStore
import LuzzyUI
import Observation
import SwiftUI

/// Estado del formulario de alta. Construye un `TransactionDraft` independiente del backend.
@MainActor
@Observable
final class NewTransactionModel {
    struct SplitRow: Identifiable {
        let id = UUID()
        var amountText = ""
        var description = ""
        var category = ""
    }

    var kind: TransactionKind = .withdrawal
    var date = Date.now
    var groupTitle = ""
    var splits: [SplitRow] = [SplitRow()]
    var source: AccountSelection?
    var destination: AccountSelection?
    /// Cuenta fija del plan gratuito: origen de los gastos y destino de los ingresos.
    var lockedAccount: AccountSelection?

    var isSourceLocked: Bool { lockedAccount != nil && kind != .deposit }
    var isDestinationLocked: Bool { lockedAccount != nil && kind == .deposit }

    /// Coloca la cuenta fija en el lado que le corresponde según el tipo.
    func applyLock() {
        guard let lockedAccount else { return }
        if kind == .deposit {
            destination = lockedAccount
            if source == lockedAccount { source = nil }
        } else {
            source = lockedAccount
            if destination == lockedAccount { destination = nil }
        }
    }
    var budget: NamedReference?
    var tagsText = ""
    var notes = ""

    private(set) var isSaving = false
    var errorMessage: String?

    var isSplit: Bool { splits.count > 1 }

    /// Tipos de cuenta válidos como origen y destino según el tipo de movimiento.
    var sourceKinds: Set<AccountKind> {
        switch kind {
        case .deposit: [.revenue]
        default: [.asset, .liability]
        }
    }

    var destinationKinds: Set<AccountKind> {
        switch kind {
        case .withdrawal: [.expense]
        default: [.asset, .liability]
        }
    }

    /// Solo los gastos permiten crear la contrapartida escribiendo un nombre nuevo.
    var allowsNewSource: Bool { kind == .deposit }
    var allowsNewDestination: Bool { kind == .withdrawal }

    func amount(_ text: String, locale: Locale) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        if let value = try? Decimal(cleaned, format: .number.locale(locale)) { return value }
        return Decimal(string: cleaned.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    func draft(locale: Locale) -> TransactionDraft {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return TransactionDraft(
            kind: kind,
            date: date,
            groupTitle: isSplit ? groupTitle : nil,
            splits: splits.map { row in
                TransactionDraftSplit(
                    amount: amount(row.amountText, locale: locale) ?? 0,
                    description: isSplit ? row.description : (row.description.isEmpty ? groupTitle : row.description),
                    source: source,
                    destination: destination,
                    categoryName: kind == .transfer ? nil : row.category,
                    budgetID: kind == .withdrawal ? budget?.id : nil,
                    tags: tags,
                    notes: notes
                )
            }
        )
    }

    func save(session: Session, locale: Locale) async -> TransactionGroup? {
        let draft = draft(locale: locale)
        if let issue = draft.validate().first {
            errorMessage = message(for: issue)
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        do {
            return try await session.dataSource.transactions.create(draft)
        } catch let error as DataSourceError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = DataSourceError.unknown("").userMessage
        }
        return nil
    }

    private func message(for issue: TransactionDraft.ValidationIssue) -> String {
        switch issue {
        case .noSplits, .nonPositiveAmount: String(localized: "Introduce un importe mayor que cero.")
        case .missingDescription: String(localized: "Añade una descripción.")
        case .missingSource: String(localized: "Elige la cuenta de origen.")
        case .missingDestination: String(localized: "Elige la cuenta de destino.")
        case .sameSourceAndDestination: String(localized: "El origen y el destino no pueden ser la misma cuenta.")
        case .missingGroupTitle: String(localized: "Un movimiento dividido necesita un título.")
        }
    }
}

struct NewTransactionView: View {
    let session: Session
    /// Plan gratuito: la única cuenta que se puede usar.
    var lockedAccountID: EntityID? = nil
    let onSaved: (TransactionGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PurchaseManager.self) private var purchases
    @State private var model = NewTransactionModel()
    @State private var budgets: [Budget] = []
    @State private var showingPaywall = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $model.kind) {
                        Text("Gasto").tag(TransactionKind.withdrawal)
                        Text("Ingreso").tag(TransactionKind.deposit)
                        Text("Transferencia").tag(TransactionKind.transfer)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .onChange(of: model.kind) { oldKind, newKind in
                        if lockedAccountID != nil, newKind == .transfer {
                            // Las transferencias necesitan dos cuentas: son Premium.
                            model.kind = oldKind
                            showingPaywall = true
                            return
                        }
                        model.source = nil
                        model.destination = nil
                        model.applyLock()
                    }
                }

                if !model.isSplit {
                    Section {
                        TextField("0,00", text: $model.splits[0].amountText)
                            .keyboardType(.decimalPad)
                            .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.center)
                            .focused($amountFocused)
                            .accessibilityLabel(Text("Importe"))
                    }
                }

                Section {
                    TextField(descriptionPlaceholder, text: model.isSplit ? $model.groupTitle : $model.splits[0].description)
                    if model.isSourceLocked {
                        LockedAccountRow(title: sourceTitle, selection: model.source)
                    } else {
                        AccountField(
                            title: sourceTitle,
                            selection: $model.source,
                            kinds: model.sourceKinds,
                            allowsNew: model.allowsNewSource,
                            session: session
                        )
                    }
                    if model.isDestinationLocked {
                        LockedAccountRow(title: destinationTitle, selection: model.destination)
                    } else {
                        AccountField(
                            title: destinationTitle,
                            selection: $model.destination,
                            kinds: model.destinationKinds,
                            allowsNew: model.allowsNewDestination,
                            session: session
                        )
                    }
                    DatePicker("Fecha", selection: $model.date)
                }

                if model.isSplit {
                    ForEach($model.splits) { $row in
                        Section {
                            TextField("Importe", text: $row.amountText).keyboardType(.decimalPad)
                            TextField("Descripción", text: $row.description)
                            if model.kind != .transfer {
                                TextField("Categoría", text: $row.category)
                            }
                        } header: {
                            Text("Parte")
                        }
                    }
                    .onDelete { offsets in
                        model.splits.remove(atOffsets: offsets)
                        if model.splits.isEmpty { model.splits = [.init()] }
                    }
                }

                Section {
                    if model.kind != .transfer, !model.isSplit {
                        TextField("Categoría", text: $model.splits[0].category)
                    }
                    if model.kind == .withdrawal {
                        if purchases.isUnlocked(.budgets) {
                            Picker("Presupuesto", selection: $model.budget) {
                                Text("Ninguno").tag(NamedReference?.none)
                                ForEach(budgets) { budget in
                                    Text(budget.name).tag(Optional(NamedReference(id: budget.id, name: budget.name)))
                                }
                            }
                        } else {
                            Button { showingPaywall = true } label: {
                                LabeledContent("Presupuesto") { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    TextField("Etiquetas (separadas por comas)", text: $model.tagsText)
                        .textInputAutocapitalization(.never)
                    TextField("Notas", text: $model.notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    Button {
                        if purchases.isUnlocked(.splitTransactions) {
                            model.splits.append(.init())
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("Dividir en varias partes", systemImage: "arrow.triangle.branch")
                    }
                }

                if let error = model.errorMessage {
                    Section { Text(error).foregroundStyle(LuzzyTheme.negative) }
                }
            }
            .navigationTitle("Nuevo movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar", systemImage: "checkmark") {
                            Task {
                                if let group = await model.save(session: session, locale: locale) {
                                    onSaved(group)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .task {
                amountFocused = true
                if let lockedAccountID {
                    let account = try? await session.dataSource.accounts.account(id: lockedAccountID)
                    model.lockedAccount = .existing(id: lockedAccountID, name: account?.name ?? "")
                    model.applyLock()
                }
                if purchases.isUnlocked(.budgets) {
                    budgets = (try? await session.dataSource.budgets.budgets(in: .month(containing: .now))) ?? []
                }
            }
        }
    }

    private var accent: Color {
        switch model.kind {
        case .withdrawal: LuzzyTheme.negative
        case .deposit: LuzzyTheme.positive
        default: LuzzyTheme.transfer
        }
    }

    private var descriptionPlaceholder: LocalizedStringKey {
        model.isSplit ? "Título del movimiento" : "Descripción"
    }

    private var sourceTitle: LocalizedStringKey {
        model.kind == .deposit ? "Pagador" : "Desde"
    }

    private var destinationTitle: LocalizedStringKey {
        model.kind == .withdrawal ? "Comercio" : "Hacia"
    }
}

/// Cuenta fija del plan gratuito (no editable).
private struct LockedAccountRow: View {
    let title: LocalizedStringKey
    let selection: AccountSelection?

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text(selection?.displayName ?? "")
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

/// Selector de cuenta con búsqueda en el origen de datos.
private struct AccountField: View {
    let title: LocalizedStringKey
    @Binding var selection: AccountSelection?
    let kinds: Set<AccountKind>
    let allowsNew: Bool
    let session: Session

    var body: some View {
        NavigationLink {
            AccountPickerView(selection: $selection, kinds: kinds, allowsNew: allowsNew, session: session)
        } label: {
            LabeledContent(title) {
                Text(selection?.displayName ?? String(localized: "Elegir"))
                    .foregroundStyle(selection == nil ? .secondary : .primary)
            }
        }
    }
}

private struct AccountPickerView: View {
    @Binding var selection: AccountSelection?
    let kinds: Set<AccountKind>
    let allowsNew: Bool
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [AccountSuggestion] = []

    var body: some View {
        List {
            if allowsNew, !trimmedQuery.isEmpty, !results.contains(where: { $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame }) {
                Button {
                    selection = .named(trimmedQuery)
                    dismiss()
                } label: {
                    Label("Crear «\(trimmedQuery)»", systemImage: "plus.circle")
                }
            }
            ForEach(results) { account in
                Button {
                    selection = .existing(id: account.id, name: account.name)
                    dismiss()
                } label: {
                    HStack {
                        InitialAvatar(account.name, size: 32)
                        Text(account.name).foregroundStyle(.primary)
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            results = (try? await session.dataSource.accounts.suggestions(matching: trimmedQuery, kinds: kinds)) ?? []
        }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
}
