import Foundation
import LuzzyCore

/// Implementación de `FinanceDataSource` sobre la API REST de Firefly III.
public final class FireflyDataSource: FinanceDataSource {
    public let kind: DataSourceKind = .firefly
    public let capabilities: DataSourceCapabilities = [
        .rules, .recurringTransactions, .webhooks, .attachments, .multiCurrency, .serverSideSearch,
    ]

    private let client: FireflyClient
    private let repository: FireflyRepository

    public init(client: FireflyClient) {
        self.client = client
        repository = FireflyRepository(client: client)
    }

    public var accounts: any AccountRepository { repository }
    public var transactions: any TransactionRepository { repository }
    public var budgets: any BudgetRepository { repository }
    public var categories: any CategoryRepository { repository }
    public var bills: any BillRepository { repository }
    public var piggyBanks: any PiggyBankRepository { repository }
    public var tags: any TagRepository { repository }
    public var summary: any SummaryRepository { repository }

    public func info() async throws -> DataSourceInfo {
        let about: AboutDTO = try await client.get("about")
        let user: JSONAPISingle<UserAttributes>? = try? await client.get("about/user")
        return DataSourceInfo(
            displayName: client.server.host,
            serverVersion: about.data.version,
            apiVersion: about.data.apiVersion,
            userEmail: user?.data.attributes.email
        )
    }
}

struct FireflyRepository: AccountRepository, TransactionRepository, BudgetRepository, CategoryRepository,
    BillRepository, PiggyBankRepository, TagRepository, SummaryRepository
{
    let client: FireflyClient

    // MARK: Cuentas

    func accounts(kind: AccountKind?, balanceDate: Date?) async throws -> [Account] {
        var query = [URLQueryItem(name: "type", value: Self.accountFilter(kind))]
        if let balanceDate { query.append(URLQueryItem(name: "date", value: FireflyDates.day(balanceDate))) }
        let resources: [JSONAPIResource<AccountAttributes>] = try await client.getAllPages("accounts", query: query)
        return resources.map(FireflyMapping.account)
    }

    func account(id: EntityID) async throws -> Account {
        let single: JSONAPISingle<AccountAttributes> = try await client.get("accounts/\(id.pathSafe)")
        return FireflyMapping.account(single.data)
    }

    func suggestions(matching query: String, kinds: Set<AccountKind>) async throws -> [AccountSuggestion] {
        var items = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "limit", value: "20")]
        let types = kinds.flatMap(Self.autocompleteTypes)
        if !types.isEmpty { items.append(URLQueryItem(name: "types", value: types.joined(separator: ","))) }
        let results: [AutocompleteAccountDTO] = try await client.get("autocomplete/accounts", query: items)
        return results.map {
            AccountSuggestion(
                id: $0.id,
                name: $0.name,
                kind: FireflyMapping.accountKind($0.type),
                currency: FireflyMapping.currency(code: $0.currencyCode, symbol: $0.currencySymbol, decimals: $0.currencyDecimalPlaces)
            )
        }
    }

    static func accountFilter(_ kind: AccountKind?) -> String {
        switch kind {
        case nil, .other: "all"
        case .asset: "asset"
        case .expense: "expense"
        case .revenue: "revenue"
        case .liability: "liabilities"
        case .cash: "cash"
        }
    }

    static func autocompleteTypes(_ kind: AccountKind) -> [String] {
        switch kind {
        case .asset: ["Asset account"]
        case .expense: ["Expense account"]
        case .revenue: ["Revenue account"]
        case .liability: ["Loan", "Debt", "Mortgage"]
        case .cash: ["Cash account"]
        case .other: []
        }
    }

    // MARK: Movimientos

    func transactions(_ query: TransactionQuery) async throws -> Page<TransactionGroup> {
        var items = [
            URLQueryItem(name: "page", value: String(query.page)),
            URLQueryItem(name: "limit", value: String(query.pageSize)),
            URLQueryItem(name: "type", value: Self.transactionFilter(query.filter)),
        ]
        if let period = query.period { items += FireflyDates.rangeQuery(period) }
        let path = query.accountID.map { "accounts/\($0.pathSafe)/transactions" } ?? "transactions"
        let list: JSONAPIList<TransactionGroupAttributes> = try await client.get(path, query: items)
        return Page(
            items: list.data.map(FireflyMapping.group),
            currentPage: list.meta?.pagination?.currentPage ?? query.page,
            totalPages: list.meta?.pagination?.totalPages ?? query.page,
            totalItems: list.meta?.pagination?.total
        )
    }

    static func transactionFilter(_ filter: TransactionFilter) -> String {
        switch filter {
        case .all: "all"
        case .withdrawals: "withdrawal"
        case .deposits: "deposit"
        case .transfers: "transfer"
        }
    }

    func transaction(id: EntityID) async throws -> TransactionGroup {
        let single: JSONAPISingle<TransactionGroupAttributes> = try await client.get("transactions/\(id.pathSafe)")
        return FireflyMapping.group(single.data)
    }

    func create(_ draft: TransactionDraft) async throws -> TransactionGroup {
        let body = TransactionStoreDTO(
            errorIfDuplicateHash: true,
            applyRules: true,
            fireWebhooks: true,
            groupTitle: draft.splits.count > 1 ? draft.groupTitle : nil,
            transactions: FireflyMapping.store(draft)
        )
        let single: JSONAPISingle<TransactionGroupAttributes> = try await client.send("POST", "transactions", body: body)
        return FireflyMapping.group(single.data)
    }

    func update(id: EntityID, with draft: TransactionDraft) async throws -> TransactionGroup {
        // Firefly identifica cada parte por su journal ID: se conservan en orden.
        let existing = try await transaction(id: id)
        var splits = FireflyMapping.store(draft)
        for index in splits.indices where index < existing.splits.count {
            splits[index].transactionJournalId = existing.splits[index].id
        }
        let body = TransactionUpdateDTO(
            applyRules: true,
            fireWebhooks: true,
            groupTitle: draft.splits.count > 1 ? draft.groupTitle : nil,
            transactions: splits
        )
        let single: JSONAPISingle<TransactionGroupAttributes> = try await client.send("PUT", "transactions/\(id.pathSafe)", body: body)
        return FireflyMapping.group(single.data)
    }

    func delete(id: EntityID) async throws {
        try await client.delete("transactions/\(id.pathSafe)")
    }

    // MARK: Presupuestos

    func budgets(in period: DateInterval) async throws -> [Budget] {
        let range = FireflyDates.rangeQuery(period)
        async let budgetsTask: [JSONAPIResource<BudgetAttributes>] = client.getAllPages("budgets", query: range)
        let limits = try await budgetLimits(in: period)
        return try await budgetsTask.map { FireflyMapping.budget($0, limits: limits) }
    }

    private func budgetLimits(in period: DateInterval) async throws -> [BudgetLimit] {
        let list: JSONAPIList<BudgetLimitAttributes> = try await client.get("budget-limits", query: FireflyDates.rangeQuery(period))
        return list.data.compactMap { FireflyMapping.budgetLimit($0) }
    }

    // MARK: Categorías, facturas, huchas, etiquetas

    func categories(in period: DateInterval?) async throws -> [LuzzyCore.Category] {
        let query = period.map(FireflyDates.rangeQuery) ?? []
        let resources: [JSONAPIResource<CategoryAttributes>] = try await client.getAllPages("categories", query: query)
        return resources.map(FireflyMapping.category)
    }

    func bills(in period: DateInterval) async throws -> [Bill] {
        let range = FireflyDates.rangeQuery(period)
        let resources: [JSONAPIResource<BillAttributes>]
        do {
            // Firefly ≥ 6.2 renombró las facturas a "subscriptions".
            resources = try await client.getAllPages("subscriptions", query: range)
        } catch DataSourceError.notFound {
            resources = try await client.getAllPages("bills", query: range)
        }
        return resources.map(FireflyMapping.bill)
    }

    func piggyBanks() async throws -> [PiggyBank] {
        let resources: [JSONAPIResource<PiggyBankAttributes>] = try await client.getAllPages("piggy-banks")
        return resources.map(FireflyMapping.piggyBank)
    }

    func tags() async throws -> [Tag] {
        let resources: [JSONAPIResource<TagAttributes>] = try await client.getAllPages("tags")
        return resources.map(FireflyMapping.tag)
    }

    // MARK: Resumen

    func summary(in period: DateInterval) async throws -> FinancialSummary {
        let entries: [String: SummaryEntryDTO] = try await client.get("summary/basic", query: FireflyDates.rangeQuery(period))
        return FireflyMapping.summary(entries, period: period)
    }
}

private extension String {
    /// Evita inyección de rutas: un ID solo puede contener letras, dígitos, "-" o "_".
    var pathSafe: String {
        String(filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }
}
