import LuzzyCore
import LuzzyUI
import Observation
import SwiftUI

/// Listado paginado de movimientos con filtros y búsqueda local.
@MainActor
@Observable
final class TransactionsModel {
    var filter: TransactionFilter = .all
    var searchText = ""
    /// Cuenta a la que se limita el listado (plan gratuito).
    var accountID: EntityID?
    private(set) var groups: [TransactionGroup] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var error: DataSourceError?
    private var page = 1
    private var loadedFilter: TransactionFilter?
    private var loadedAccountID: EntityID?

    var visibleSections: [DaySection] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? groups : groups.filter { group in
            group.displayTitle.localizedCaseInsensitiveContains(query)
                || group.splits.contains { split in
                    split.description.localizedCaseInsensitiveContains(query)
                        || split.source.name.localizedCaseInsensitiveContains(query)
                        || split.destination.name.localizedCaseInsensitiveContains(query)
                        || (split.category?.name.localizedCaseInsensitiveContains(query) ?? false)
                        || split.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                }
        }
        return DaySection.make(from: filtered)
    }

    func reload(session: Session) async {
        let query = TransactionQuery(filter: filter, accountID: accountID, page: 1, pageSize: 50)
        let source = session.dataSource
        isLoading = true
        error = nil
        if loadedFilter != filter || loadedAccountID != accountID { groups = [] }
        defer { isLoading = false }
        do {
            let result = try await session.fetcher.fetch(key: CacheKey.transactions(query), cached: { [weak self] hit in
                await self?.apply(hit.value, replacing: true)
            }, remote: {
                try await source.transactions.transactions(query)
            })
            apply(result, replacing: true)
            loadedFilter = filter
            loadedAccountID = accountID
        } catch let error as DataSourceError {
            self.error = error
        } catch {
            self.error = .unknown("")
        }
    }

    func loadMore(session: Session) async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await session.dataSource.transactions.transactions(TransactionQuery(filter: filter, accountID: accountID, page: page + 1, pageSize: 50))
            apply(next, replacing: false)
        } catch let error as DataSourceError {
            self.error = error
        } catch {}
    }

    func delete(_ group: TransactionGroup, session: Session) async {
        do {
            try await session.dataSource.transactions.delete(id: group.id)
            groups.removeAll { $0.id == group.id }
        } catch let error as DataSourceError {
            self.error = error
        } catch {}
    }

    private func apply(_ page: Page<TransactionGroup>, replacing: Bool) {
        if replacing {
            groups = page.items
        } else {
            let known = Set(groups.map(\.id))
            groups += page.items.filter { !known.contains($0.id) }
        }
        self.page = page.currentPage
        hasMore = page.hasMore
    }
}

struct TransactionsView: View {
    let session: Session

    @Environment(AppModel.self) private var app
    @State private var model = TransactionsModel()
    @State private var showingNewTransaction = false
    @State private var pendingDeletion: TransactionGroup?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    Picker("Tipo", selection: $model.filter) {
                        Text("Todos").tag(TransactionFilter.all)
                        Text("Gastos").tag(TransactionFilter.withdrawals)
                        Text("Ingresos").tag(TransactionFilter.deposits)
                        if !app.accessScope.isLimited {
                            Text("Transferencias").tag(TransactionFilter.transfers)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if let error = model.error {
                    Section {
                        Label(error.userMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(model.visibleSections) { section in
                    Section {
                        ForEach(section.groups) { group in
                            NavigationLink(value: group) {
                                TransactionRow(group: group)
                            }
                            .swipeActions {
                                Button("Borrar", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = group
                                }
                            }
                        }
                    } header: {
                        DayTitle(day: section.day)
                    }
                }

                if model.hasMore, model.searchText.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task { await model.loadMore(session: session) }
                }

                if model.groups.isEmpty, !model.isLoading, model.error == nil {
                    ContentUnavailableView("Sin movimientos", systemImage: "tray", description: Text("Los movimientos que registres aparecerán aquí."))
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Movimientos")
            .searchable(text: $model.searchText, prompt: Text("Buscar: descripción, cuenta, etiqueta…"))
            .navigationDestination(for: TransactionGroup.self) { group in
                TransactionDetailView(session: session, group: group) {
                    Task { await model.reload(session: session) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewTransaction = true } label: {
                        Label("Nuevo movimiento", systemImage: "plus")
                    }
                }
            }
            .refreshable { await model.reload(session: session) }
            .task(id: ReloadKey(filter: model.filter, accountID: app.accessScope.limitedAccountID)) {
                model.accountID = app.accessScope.limitedAccountID
                if app.accessScope.isLimited, model.filter == .transfers { model.filter = .all }
                await model.reload(session: session)
            }
            .sheet(isPresented: $showingNewTransaction) {
                NewTransactionView(session: session, lockedAccountID: app.accessScope.limitedAccountID) { _ in
                    Task { await model.reload(session: session) }
                }
            }
            .confirmationDialog(
                "¿Borrar este movimiento?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { group in
                Button("Borrar en el servidor", role: .destructive) {
                    Task { await model.delete(group, session: session) }
                }
            } message: { _ in
                Text("Se eliminará también en Firefly III. No se puede deshacer.")
            }
        }
    }
}

/// Clave de recarga: cambia al cambiar el filtro o la cuenta del plan.
private struct ReloadKey: Equatable {
    let filter: TransactionFilter
    let accountID: EntityID?
}

/// Detalle de un movimiento con todas sus partes.
struct TransactionDetailView: View {
    let session: Session
    let group: TransactionGroup
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.signedTotals, id: \.currency.code) { total in
                        MoneyText(total, showsSign: group.kind == .deposit, coloring: .positiveHighlight)
                            .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                    }
                    Text(group.date, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            ForEach(Array(group.splits.enumerated()), id: \.element.id) { index, split in
                Section(group.isSplit ? LocalizedStringKey("Parte \(index + 1)") : LocalizedStringKey("Detalles")) {
                    LabeledContent("Descripción", value: split.description)
                    if group.isSplit {
                        LabeledContent("Importe") { MoneyText(split.amount) }
                    }
                    LabeledContent("Origen", value: split.source.name)
                    LabeledContent("Destino", value: split.destination.name)
                    if let category = split.category { LabeledContent("Categoría", value: category.name) }
                    if let budget = split.budget { LabeledContent("Presupuesto", value: budget.name) }
                    if let bill = split.bill { LabeledContent("Factura", value: bill.name) }
                    if !split.tags.isEmpty { LabeledContent("Etiquetas", value: split.tags.joined(separator: ", ")) }
                    if let foreign = split.foreignAmount {
                        LabeledContent("Importe en divisa") { MoneyText(foreign) }
                    }
                    if let notes = split.notes {
                        Text(notes).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LuzzyTheme.negative) }
            }

            Section {
                Button("Borrar movimiento", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(group.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Borrar este movimiento?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Borrar en el servidor", role: .destructive) {
                Task { await delete() }
            }
        } message: {
            Text("Se eliminará también en Firefly III. No se puede deshacer.")
        }
    }

    private func delete() async {
        do {
            try await session.dataSource.transactions.delete(id: group.id)
            onChange()
            dismiss()
        } catch let error as DataSourceError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = DataSourceError.unknown("").userMessage
        }
    }
}
