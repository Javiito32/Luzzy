import LuzzyCore
import LuzzyStore
import LuzzyUI
import SwiftUI

/// Datos del inicio, cargados en paralelo y guardados como una sola instantánea.
struct DashboardSnapshot: Codable, Sendable {
    var summary: FinancialSummary
    var assets: [Money]
    var liabilities: [Money]
    var budgets: [Budget]
    var recent: [TransactionGroup]
}

struct DashboardView: View {
    let session: Session
    @Binding var selection: MainTabView.TabID

    @Environment(PurchaseManager.self) private var purchases
    @State private var resource = Resource<DashboardSnapshot>()
    @State private var showingNewTransaction = false
    private let period = DateInterval.month(containing: .now)

    var body: some View {
        NavigationStack {
            ScrollView {
                LoadableView(state: resource.state, retry: load) { snapshot in
                    VStack(spacing: 18) {
                        NetWorthCard(snapshot: snapshot)
                        MonthTiles(summary: snapshot.summary, budgets: snapshot.budgets)
                        budgetsSection(snapshot.budgets)
                        recentSection(snapshot.recent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(LuzzyTheme.groupedBackground)
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewTransaction = true } label: {
                        Label("Nuevo movimiento", systemImage: "plus")
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showingNewTransaction) {
                NewTransactionView(session: session) { _ in Task { await load() } }
            }
        }
    }

    private func load() async {
        let source = session.dataSource
        let period = period
        let includeBudgets = purchases.isPremium
        await resource.load(key: "dashboard.\(Int(period.start.timeIntervalSince1970)).\(includeBudgets)", session: session) {
            async let summary = source.summary.summary(in: period)
            async let accounts = source.accounts.accounts(kind: nil, balanceDate: nil)
            async let recent = source.transactions.transactions(TransactionQuery(page: 1, pageSize: 5))
            let budgets = includeBudgets ? try await source.budgets.budgets(in: period) : []
            let all = try await accounts
            return DashboardSnapshot(
                summary: try await summary,
                assets: all.filter { $0.kind == .asset && $0.includeInNetWorth }.map(\.balance).totalsByCurrency(),
                liabilities: all.filter { $0.kind == .liability && $0.includeInNetWorth }.map(\.balance).totalsByCurrency(),
                budgets: budgets,
                recent: try await recent.items
            )
        }
    }

    @ViewBuilder
    private func budgetsSection(_ budgets: [Budget]) -> some View {
        VStack(spacing: 8) {
            SectionHeader("Presupuestos") {
                Button("Ver todo") { selection = .budgets }
            }
            if !purchases.isPremium {
                PremiumTeaser(feature: .budgets)
            } else if budgets.isEmpty {
                Text("Aún no tienes presupuestos para este mes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .luzzyCard()
            } else {
                VStack(spacing: 14) {
                    ForEach(budgets.compactMap { budget in budget.limits.first.map { (budget, $0) } }.prefix(3), id: \.0.id) { budget, limit in
                        BudgetProgressRow(name: budget.name, limit: limit, compact: true)
                    }
                }
                .padding(16)
                .luzzyCard()
            }
        }
    }

    @ViewBuilder
    private func recentSection(_ recent: [TransactionGroup]) -> some View {
        VStack(spacing: 8) {
            SectionHeader("Últimos movimientos") {
                Button("Ver todo") { selection = .transactions }
            }
            VStack(spacing: 0) {
                if recent.isEmpty {
                    Text("Todavía no hay movimientos.")
                        .foregroundStyle(.secondary)
                        .padding(16)
                }
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, group in
                    if index > 0 { Divider().padding(.leading, 68) }
                    TransactionRow(group: group).padding(.horizontal, 16).padding(.vertical, 6)
                }
            }
            .luzzyCard()
        }
    }
}

/// Tarjeta principal con el patrimonio neto.
private struct NetWorthCard: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Patrimonio neto")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            ForEach(netWorth, id: \.currency.code) { money in
                MoneyText(money)
                    .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                tile(title: "Activos", values: snapshot.assets)
                tile(title: "Pasivos", values: snapshot.liabilities)
            }
            .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: LuzzyTheme.heroCornerRadius, style: .continuous).fill(LuzzyTheme.accent))
        .environment(\.colorScheme, .dark)
    }

    private var netWorth: [Money] {
        snapshot.summary.netWorth.isEmpty
            ? (snapshot.assets + snapshot.liabilities).totalsByCurrency()
            : snapshot.summary.netWorth
    }

    private func tile(title: LocalizedStringKey, values: [Money]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.85))
            ForEach(values, id: \.currency.code) { money in
                MoneyText(money).font(LuzzyTheme.amountFont(.headline, weight: .bold)).foregroundStyle(.white)
            }
            if values.isEmpty { Text("—").foregroundStyle(.white) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luzzyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: false)
    }
}

/// Gastado e ingresado este mes.
private struct MonthTiles: View {
    let summary: FinancialSummary
    let budgets: [Budget]

    var body: some View {
        HStack(spacing: 12) {
            tile(title: "Gastado", values: summary.spent, budgeted: budgets.flatMap(\.limits).map(\.amount).totalsByCurrency().first)
            tile(title: "Ingresado", values: summary.earned, budgeted: nil, positive: true)
        }
    }

    private func tile(title: LocalizedStringKey, values: [Money], budgeted: Money?, positive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            ForEach(values.isEmpty ? [Money.zero(.euro)] : values, id: \.currency.code) { money in
                MoneyText(money)
                    .font(LuzzyTheme.amountFont(.title3, weight: .bold))
                    .foregroundStyle(positive ? LuzzyTheme.positive : .primary)
            }
            if let budgeted {
                HStack(spacing: 4) {
                    Text("Presupuestado:")
                    MoneyText(budgeted)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luzzyCard()
    }
}
