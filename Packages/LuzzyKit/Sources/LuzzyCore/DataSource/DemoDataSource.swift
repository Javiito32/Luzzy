import Foundation

/// Origen de datos en memoria con datos ficticios.
///
/// Sirve para: previsualizaciones de SwiftUI, tests, el "modo demo" que usa
/// App Review sin servidor, y como prueba de que la UI no depende de Firefly.
public final class DemoDataSource: FinanceDataSource {
    public let kind: DataSourceKind = .demo
    public let capabilities: DataSourceCapabilities = []

    private let store: DemoStore

    public init(now: Date = .now) {
        store = DemoStore(seed: DemoSeed.make(now: now))
    }

    public var accounts: any AccountRepository { store }
    public var transactions: any TransactionRepository { store }
    public var budgets: any BudgetRepository { store }
    public var categories: any CategoryRepository { store }
    public var bills: any BillRepository { store }
    public var piggyBanks: any PiggyBankRepository { store }
    public var tags: any TagRepository { store }
    public var summary: any SummaryRepository { store }

    public func info() async throws -> DataSourceInfo {
        DataSourceInfo(displayName: "Demo")
    }
}

struct DemoSeed: Sendable {
    var accounts: [Account]
    var groups: [TransactionGroup]
    var budgets: [Budget]
    var categories: [Category]
    var bills: [Bill]
    var piggyBanks: [PiggyBank]
    var tags: [Tag]

    static func make(now: Date) -> DemoSeed {
        let eur = Currency.euro
        let cal = Calendar(identifier: .gregorian)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: -offset, to: now) ?? now }
        // Vía texto para que los importes sean decimales exactos.
        func m(_ value: Double) -> Money { Money(Decimal(string: String(value)) ?? 0, eur) }

        let checking = Account(id: "1", name: "Cuenta nómina", kind: .asset, role: .defaultAsset, balance: m(3412.20), iban: "ES00 0000 0000 0000 0000 4521")
        let savings = Account(id: "2", name: "Ahorro", kind: .asset, role: .savingAsset, balance: m(8900), iban: "ES00 0000 0000 0000 0000 0930")
        let wallet = Account(id: "3", name: "Cartera", kind: .asset, role: .cashWallet, balance: m(118.65))
        let card = Account(id: "4", name: "Tarjeta de crédito", kind: .asset, role: .creditCard, balance: m(-1750))
        let loan = Account(id: "5", name: "Préstamo coche", kind: .liability, liabilityKind: .loan, balance: m(-6200))
        let employer = Account(id: "10", name: "Empresa S.L.", kind: .revenue, balance: m(0))
        let market = Account(id: "20", name: "Supermercado", kind: .expense, balance: m(0))
        let fuel = Account(id: "21", name: "Gasolinera", kind: .expense, balance: m(0))
        let streaming = Account(id: "22", name: "Streaming", kind: .expense, balance: m(0))

        func ref(_ a: Account) -> AccountReference { AccountReference(id: a.id, name: a.name, kind: a.kind) }
        let groceries = NamedReference(id: "c1", name: "Supermercado")
        let leisure = NamedReference(id: "c2", name: "Ocio")
        let transport = NamedReference(id: "c3", name: "Transporte")
        let bGroceries = NamedReference(id: "b1", name: "Supermercado")
        let bLeisure = NamedReference(id: "b2", name: "Ocio")
        let bTransport = NamedReference(id: "b3", name: "Transporte")

        let groups: [TransactionGroup] = [
            .init(id: "100", title: nil, splits: [.init(id: "1000", kind: .withdrawal, date: day(0), amount: m(54.20), description: "Compra semanal", source: ref(checking), destination: ref(market), category: groceries, budget: bGroceries)]),
            .init(id: "101", title: nil, splits: [.init(id: "1001", kind: .withdrawal, date: day(0), amount: m(60), description: "Depósito lleno", source: ref(card), destination: ref(fuel), category: transport, budget: bTransport)]),
            .init(id: "102", title: nil, splits: [.init(id: "1002", kind: .deposit, date: day(1), amount: m(2450), description: "Nómina", source: ref(employer), destination: ref(checking))]),
            .init(id: "103", title: nil, splits: [.init(id: "1003", kind: .transfer, date: day(1), amount: m(500), description: "Ahorro mensual", source: ref(checking), destination: ref(savings))]),
            .init(id: "104", title: nil, splits: [.init(id: "1004", kind: .withdrawal, date: day(3), amount: m(12.99), description: "Suscripción", source: ref(card), destination: ref(streaming), category: leisure, budget: bLeisure, tags: ["suscripción"])]),
        ]

        let month = DateInterval.month(containing: now, calendar: cal)
        func limit(_ id: String, _ budget: String, _ amount: Double, _ spent: Double) -> BudgetLimit {
            BudgetLimit(id: id, budgetID: budget, period: month, amount: m(amount), spent: m(spent))
        }
        let budgets = [
            Budget(id: "b1", name: "Supermercado", isActive: true, spent: [m(312.40)], limits: [limit("l1", "b1", 400, 312.40)]),
            Budget(id: "b2", name: "Ocio", isActive: true, spent: [m(148)], limits: [limit("l2", "b2", 120, 148)]),
            Budget(id: "b3", name: "Transporte", isActive: true, spent: [m(96.30)], limits: [limit("l3", "b3", 150, 96.30)]),
        ]

        let nextMonthStart = month.end
        let bills = [
            Bill(id: "s1", name: "Alquiler", amountMin: m(750), amountMax: m(750), startDate: day(400), frequency: .monthly, nextExpectedMatch: nextMonthStart, payDates: [nextMonthStart]),
            Bill(id: "s2", name: "Internet y móvil", amountMin: m(35), amountMax: m(45), startDate: day(400), frequency: .monthly, nextExpectedMatch: nextMonthStart, payDates: [nextMonthStart]),
            Bill(id: "s3", name: "Gimnasio", amountMin: m(34.90), amountMax: m(34.90), startDate: day(200), frequency: .monthly, paidDates: [day(20)]),
        ]

        return DemoSeed(
            accounts: [checking, savings, wallet, card, loan, employer, market, fuel, streaming],
            groups: groups,
            budgets: budgets,
            categories: [
                Category(id: "c1", name: "Supermercado", spent: [m(312.40)]),
                Category(id: "c2", name: "Ocio", spent: [m(148)]),
                Category(id: "c3", name: "Transporte", spent: [m(96.30)]),
            ],
            bills: bills,
            piggyBanks: [
                PiggyBank(id: "p1", name: "Vacaciones", target: m(2000), current: m(1240), accounts: [NamedReference(id: "2", name: "Ahorro")]),
                PiggyBank(id: "p2", name: "Fondo de emergencia", target: m(6000), current: m(4500), accounts: [NamedReference(id: "2", name: "Ahorro")]),
            ],
            tags: [Tag(id: "suscripción", name: "suscripción"), Tag(id: "compra", name: "compra")]
        )
    }
}

/// Almacén en memoria aislado en un actor.
actor DemoStore: AccountRepository, TransactionRepository, BudgetRepository, CategoryRepository,
    BillRepository, PiggyBankRepository, TagRepository, SummaryRepository
{
    private var seed: DemoSeed
    private var nextID = 10_000

    init(seed: DemoSeed) {
        self.seed = seed
    }

    func accounts(kind: AccountKind?, balanceDate: Date?) async throws -> [Account] {
        seed.accounts.filter { kind == nil || $0.kind == kind }
    }

    func account(id: EntityID) async throws -> Account {
        guard let account = seed.accounts.first(where: { $0.id == id }) else { throw DataSourceError.notFound }
        return account
    }

    func suggestions(matching query: String, kinds: Set<AccountKind>) async throws -> [AccountSuggestion] {
        seed.accounts
            .filter { kinds.isEmpty || kinds.contains($0.kind) }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .map { AccountSuggestion(id: $0.id, name: $0.name, kind: $0.kind, currency: $0.balance.currency) }
    }

    func transactions(_ query: TransactionQuery) async throws -> Page<TransactionGroup> {
        let filtered = seed.groups
            .filter { group in
                switch query.filter {
                case .all: true
                case .withdrawals: group.kind == .withdrawal
                case .deposits: group.kind == .deposit
                case .transfers: group.kind == .transfer
                }
            }
            .filter { group in
                guard let accountID = query.accountID else { return true }
                return group.splits.contains { $0.source.id == accountID || $0.destination.id == accountID }
            }
            .filter { query.period?.contains($0.date) ?? true }
            .sorted { $0.date > $1.date }
        return Page(items: filtered, currentPage: 1, totalPages: 1, totalItems: filtered.count)
    }

    func transaction(id: EntityID) async throws -> TransactionGroup {
        guard let group = seed.groups.first(where: { $0.id == id }) else { throw DataSourceError.notFound }
        return group
    }

    func create(_ draft: TransactionDraft) async throws -> TransactionGroup {
        let group = makeGroup(id: newID(), from: draft)
        seed.groups.insert(group, at: 0)
        return group
    }

    func update(id: EntityID, with draft: TransactionDraft) async throws -> TransactionGroup {
        guard let index = seed.groups.firstIndex(where: { $0.id == id }) else { throw DataSourceError.notFound }
        let group = makeGroup(id: id, from: draft)
        seed.groups[index] = group
        return group
    }

    func delete(id: EntityID) async throws {
        seed.groups.removeAll { $0.id == id }
    }

    func budgets(in period: DateInterval) async throws -> [Budget] { seed.budgets }
    func categories(in period: DateInterval?) async throws -> [Category] { seed.categories }
    func bills(in period: DateInterval) async throws -> [Bill] { seed.bills }
    func piggyBanks() async throws -> [PiggyBank] { seed.piggyBanks }
    func tags() async throws -> [Tag] { seed.tags }

    func summary(in period: DateInterval) async throws -> FinancialSummary {
        let inPeriod = seed.groups.filter { period.contains($0.date) }.flatMap(\.splits)
        let spent = inPeriod.filter { $0.kind == .withdrawal }.map(\.amount).totalsByCurrency()
        let earned = inPeriod.filter { $0.kind == .deposit }.map(\.amount).totalsByCurrency()
        let netWorth = seed.accounts
            .filter { ($0.kind == .asset || $0.kind == .liability) && $0.includeInNetWorth }
            .map(\.balance)
            .totalsByCurrency()
        return FinancialSummary(period: period, netWorth: netWorth, spent: spent, earned: earned)
    }

    private func newID() -> EntityID {
        nextID += 1
        return String(nextID)
    }

    private func makeGroup(id: EntityID, from draft: TransactionDraft) -> TransactionGroup {
        let currency = Currency(code: draft.currencyCode ?? "EUR", symbol: draft.currencyCode == nil ? "€" : nil)
        let splits = draft.splits.map { split in
            TransactionSplit(
                id: newID(),
                kind: draft.kind,
                date: draft.date,
                amount: Money(split.amount, currency),
                description: split.description,
                source: reference(for: split.source),
                destination: reference(for: split.destination),
                category: split.categoryName.map { NamedReference(id: $0, name: $0) },
                tags: split.tags,
                notes: split.notes
            )
        }
        return TransactionGroup(id: id, title: draft.groupTitle, splits: splits)
    }

    private func reference(for selection: AccountSelection?) -> AccountReference {
        switch selection {
        case .existing(let id, let name):
            AccountReference(id: id, name: name, kind: seed.accounts.first { $0.id == id }?.kind)
        case .named(let name):
            AccountReference(id: nil, name: name, kind: nil)
        case nil:
            AccountReference(id: nil, name: "", kind: nil)
        }
    }
}
