import LuzzyCore
import LuzzyStore
import LuzzyUI
import SwiftUI

struct BillsAndPiggyBanksSnapshot: Codable, Sendable {
    var bills: [Bill]
    var piggyBanks: [PiggyBank]
}

struct BillsAndPiggyBanksView: View {
    let session: Session

    @Environment(PurchaseManager.self) private var purchases
    @State private var resource = Resource<BillsAndPiggyBanksSnapshot>()
    private let period = DateInterval.month(containing: .now)

    var body: some View {
        Group {
            if purchases.isUnlocked(.billsAndPiggyBanks) {
                LoadableView(state: resource.state, retry: load) { snapshot in
                    List {
                        billsSection(snapshot.bills)
                        piggySection(snapshot.piggyBanks)
                    }
                }
                .refreshable { await load() }
                .task { await load() }
            } else {
                PremiumLockedView(feature: .billsAndPiggyBanks)
            }
        }
        .navigationTitle("Facturas y huchas")
    }

    private func load() async {
        let source = session.dataSource
        let period = period
        await resource.load(key: CacheKey.bills(period), session: session) {
            async let bills = source.bills.bills(in: period)
            async let piggies = source.piggyBanks.piggyBanks()
            return BillsAndPiggyBanksSnapshot(
                bills: try await bills.filter(\.isActive).sorted { ($0.nextExpectedMatch ?? .distantFuture) < ($1.nextExpectedMatch ?? .distantFuture) },
                piggyBanks: try await piggies.filter(\.isActive)
            )
        }
    }

    @ViewBuilder
    private func billsSection(_ bills: [Bill]) -> some View {
        Section {
            if bills.isEmpty {
                Text("Sin facturas activas.").foregroundStyle(.secondary)
            }
            ForEach(bills) { bill in
                HStack(spacing: 12) {
                    DateBadge(date: bill.nextExpectedMatch ?? bill.paidDates.last)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name)
                        Text(bill.frequency.title).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        MoneyText(bill.expectedAmount).font(LuzzyTheme.amountFont())
                        StatusBadge(bill.status.title, tint: bill.status.tint)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Facturas")
        } footer: {
            let pending = bills.filter { $0.status == .pending }.map(\.expectedAmount).totalsByCurrency()
            if let first = pending.first {
                HStack(spacing: 4) {
                    Text("Pendiente este mes:")
                    MoneyText(first)
                }
            }
        }
    }

    @ViewBuilder
    private func piggySection(_ piggies: [PiggyBank]) -> some View {
        Section("Huchas") {
            if piggies.isEmpty {
                Text("Sin huchas.").foregroundStyle(.secondary)
            }
            ForEach(piggies) { piggy in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(piggy.name).font(.headline)
                        Spacer()
                        if let target = piggy.targetDate {
                            Text(target, format: .dateTime.day().month().year()).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        MoneyText(piggy.current).font(LuzzyTheme.amountFont(.title2, weight: .bold))
                        if let target = piggy.target {
                            Text("de").foregroundStyle(.secondary)
                            MoneyText(target).foregroundStyle(.secondary)
                        }
                    }
                    if piggy.target != nil {
                        ProgressBar(progress: piggy.progress, tint: LuzzyTheme.warning)
                    }
                    if !piggy.accounts.isEmpty {
                        Text(piggy.accounts.map(\.name).joined(separator: ", ")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

private struct DateBadge: View {
    let date: Date?

    var body: some View {
        VStack(spacing: 0) {
            if let date {
                Text(date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(LuzzyTheme.negative)
                Text(date, format: .dateTime.day())
                    .font(LuzzyTheme.amountFont(.headline, weight: .bold))
            } else {
                Text(verbatim: "—")
            }
        }
        .frame(width: 44, height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.secondary.opacity(0.1)))
        .accessibilityHidden(true)
    }
}

extension RepeatFrequency {
    var title: LocalizedStringKey {
        switch self {
        case .weekly: "Semanal"
        case .monthly: "Mensual"
        case .quarterly: "Trimestral"
        case .halfYear: "Semestral"
        case .yearly: "Anual"
        }
    }
}

extension Bill.Status {
    var title: Text {
        switch self {
        case .paid: Text("Pagada")
        case .pending: Text("Pendiente")
        case .upcoming: Text("Próxima")
        case .inactive: Text("Inactiva")
        }
    }

    var tint: Color {
        switch self {
        case .paid: LuzzyTheme.positive
        case .pending: LuzzyTheme.warning
        case .upcoming, .inactive: .secondary
        }
    }
}

/// Categorías con su gasto del mes.
struct CategoriesView: View {
    let session: Session
    @Environment(PurchaseManager.self) private var purchases
    @State private var resource = Resource<[LuzzyCore.Category]>()

    var body: some View {
        Group {
            if purchases.isUnlocked(.categoriesAndTags) {
                LoadableView(state: resource.state, retry: load) { categories in
                    List(categories) { category in
                        HStack {
                            InitialAvatar(category.name, size: 32)
                            Text(category.name)
                            Spacer()
                            if let spent = category.spent.first {
                                MoneyText(spent).font(LuzzyTheme.amountFont()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable { await load() }
                .task { await load() }
            } else {
                PremiumLockedView(feature: .categoriesAndTags)
            }
        }
        .navigationTitle("Categorías")
    }

    private func load() async {
        let source = session.dataSource
        await resource.load(key: CacheKey.categories, session: session) {
            try await source.categories.categories(in: .month(containing: .now))
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}

struct TagsView: View {
    let session: Session
    @Environment(PurchaseManager.self) private var purchases
    @State private var resource = Resource<[Tag]>()

    var body: some View {
        Group {
            if purchases.isUnlocked(.categoriesAndTags) {
                LoadableView(state: resource.state, retry: load) { tags in
                    List(tags) { tag in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(tag.name, systemImage: "tag")
                            if let description = tag.description {
                                Text(description).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable { await load() }
                .task { await load() }
            } else {
                PremiumLockedView(feature: .categoriesAndTags)
            }
        }
        .navigationTitle("Etiquetas")
    }

    private func load() async {
        let source = session.dataSource
        await resource.load(key: CacheKey.tags, session: session) {
            try await source.tags.tags().sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
