import LuzzyCore
import LuzzyUI
import SwiftUI

/// Datos del inicio en el plan gratuito: solo la cuenta elegida.
struct AccountDashboardSnapshot: Codable, Sendable {
    var account: Account
    var spent: [Money]
    var earned: [Money]
    var recent: [TransactionGroup]
}

/// Inicio del plan gratuito: saldo, gastos e ingresos del mes de UNA cuenta.
struct SingleAccountDashboardView: View {
    let session: Session
    let accountID: EntityID
    @Binding var selection: MainTabView.TabID

    @State private var resource = Resource<AccountDashboardSnapshot>()
    @State private var showingNewTransaction = false
    private let period = DateInterval.month(containing: .now)

    var body: some View {
        NavigationStack {
            ScrollView {
                LoadableView(state: resource.state, retry: load) { snapshot in
                    VStack(spacing: 18) {
                        balanceCard(snapshot.account)
                        HStack(spacing: 12) {
                            tile("Gastado este mes", snapshot.spent, positive: false)
                            tile("Ingresado este mes", snapshot.earned, positive: true)
                        }
                        recentSection(snapshot.recent)
                        PremiumTeaser(feature: .multipleAccounts)
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
            .task(id: accountID) { await load() }
            .sheet(isPresented: $showingNewTransaction) {
                NewTransactionView(session: session, lockedAccountID: accountID) { _ in Task { await load() } }
            }
        }
    }

    private func load() async {
        let source = session.dataSource
        let accountID = accountID
        let period = period
        await resource.load(key: "dashboard.single.\(accountID).\(Int(period.start.timeIntervalSince1970))", session: session) {
            async let account = source.accounts.account(id: accountID)
            // Movimientos del mes de esta cuenta (con un tope de páginas por seguridad).
            var month: [TransactionGroup] = []
            var page = 1
            while page <= 10 {
                let result = try await source.transactions.transactions(
                    TransactionQuery(period: period, accountID: accountID, page: page, pageSize: 100)
                )
                month += result.items
                guard result.hasMore else { break }
                page += 1
            }
            let splits = month.flatMap(\.splits)
            let spent = splits
                .filter { $0.kind == .withdrawal && $0.source.id == accountID }
                .map(\.amount)
                .totalsByCurrency()
            let earned = splits
                .filter { $0.kind == .deposit && $0.destination.id == accountID }
                .map(\.amount)
                .totalsByCurrency()
            let recent: [TransactionGroup]
            if month.count >= 5 {
                recent = Array(month.sorted { $0.date > $1.date }.prefix(5))
            } else {
                recent = try await source.transactions.transactions(TransactionQuery(accountID: accountID, page: 1, pageSize: 5)).items
            }
            return AccountDashboardSnapshot(account: try await account, spent: spent, earned: earned, recent: recent)
        }
    }

    private func balanceCard(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(account.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            MoneyText(account.balance)
                .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let masked = account.maskedNumber {
                Text(masked)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: LuzzyTheme.heroCornerRadius, style: .continuous).fill(LuzzyTheme.accent))
    }

    private func tile(_ title: LocalizedStringKey, _ values: [Money], positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            ForEach(values.isEmpty ? [Money.zero(.euro)] : values, id: \.currency.code) { money in
                MoneyText(money)
                    .font(LuzzyTheme.amountFont(.title3, weight: .bold))
                    .foregroundStyle(positive ? LuzzyTheme.positive : .primary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luzzyCard()
    }

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
