import Foundation

// MARK: - Capa de abstracción de datos
//
// La UI y los modelos de pantalla dependen EXCLUSIVAMENTE de estos protocolos.
// Hoy existe un backend (Firefly III vía API REST) más uno en memoria para
// previsualizaciones/demo. En el futuro se añadirá un backend sin servidor
// (SwiftData + CloudKit) que implementará exactamente las mismas interfaces.

public protocol AccountRepository: Sendable {
    func accounts(kind: AccountKind?, balanceDate: Date?) async throws -> [Account]
    func account(id: EntityID) async throws -> Account
    func suggestions(matching query: String, kinds: Set<AccountKind>) async throws -> [AccountSuggestion]
}

public protocol TransactionRepository: Sendable {
    func transactions(_ query: TransactionQuery) async throws -> Page<TransactionGroup>
    func transaction(id: EntityID) async throws -> TransactionGroup
    func create(_ draft: TransactionDraft) async throws -> TransactionGroup
    func update(id: EntityID, with draft: TransactionDraft) async throws -> TransactionGroup
    func delete(id: EntityID) async throws
}

public protocol BudgetRepository: Sendable {
    /// Presupuestos con sus límites y gasto para el periodo.
    func budgets(in period: DateInterval) async throws -> [Budget]
}

public protocol CategoryRepository: Sendable {
    func categories(in period: DateInterval?) async throws -> [Category]
}

public protocol BillRepository: Sendable {
    func bills(in period: DateInterval) async throws -> [Bill]
}

public protocol PiggyBankRepository: Sendable {
    func piggyBanks() async throws -> [PiggyBank]
}

public protocol TagRepository: Sendable {
    func tags() async throws -> [Tag]
}

public protocol SummaryRepository: Sendable {
    func summary(in period: DateInterval) async throws -> FinancialSummary
}

/// Tipo de backend. `.iCloud` está reservado para la futura versión sin servidor.
public enum DataSourceKind: String, Sendable, Codable {
    case firefly
    case demo
    case iCloud
}

/// Funcionalidades que dependen del backend (p. ej. las reglas solo existen en Firefly).
public struct DataSourceCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let rules = DataSourceCapabilities(rawValue: 1 << 0)
    public static let recurringTransactions = DataSourceCapabilities(rawValue: 1 << 1)
    public static let webhooks = DataSourceCapabilities(rawValue: 1 << 2)
    public static let attachments = DataSourceCapabilities(rawValue: 1 << 3)
    public static let multiCurrency = DataSourceCapabilities(rawValue: 1 << 4)
    public static let serverSideSearch = DataSourceCapabilities(rawValue: 1 << 5)
}

/// Punto de entrada único a los datos financieros.
public protocol FinanceDataSource: Sendable {
    var kind: DataSourceKind { get }
    var capabilities: DataSourceCapabilities { get }

    var accounts: any AccountRepository { get }
    var transactions: any TransactionRepository { get }
    var budgets: any BudgetRepository { get }
    var categories: any CategoryRepository { get }
    var bills: any BillRepository { get }
    var piggyBanks: any PiggyBankRepository { get }
    var tags: any TagRepository { get }
    var summary: any SummaryRepository { get }

    /// Comprueba que el origen responde y devuelve su información.
    func info() async throws -> DataSourceInfo
}
