import Foundation

/// Resumen financiero de un periodo. Cada campo es una lista por divisa.
public struct FinancialSummary: Hashable, Sendable, Codable {
    public var period: DateInterval
    public var netWorth: [Money]
    public var balance: [Money]
    public var spent: [Money]
    public var earned: [Money]
    public var billsPaid: [Money]
    public var billsUnpaid: [Money]
    public var leftToSpend: [Money]

    public init(
        period: DateInterval,
        netWorth: [Money] = [],
        balance: [Money] = [],
        spent: [Money] = [],
        earned: [Money] = [],
        billsPaid: [Money] = [],
        billsUnpaid: [Money] = [],
        leftToSpend: [Money] = []
    ) {
        self.period = period
        self.netWorth = netWorth
        self.balance = balance
        self.spent = spent
        self.earned = earned
        self.billsPaid = billsPaid
        self.billsUnpaid = billsUnpaid
        self.leftToSpend = leftToSpend
    }
}

/// Información del origen de datos (versión del servidor, usuario…).
public struct DataSourceInfo: Hashable, Sendable, Codable {
    public var displayName: String
    public var serverVersion: String?
    public var apiVersion: String?
    public var userEmail: String?

    public init(displayName: String, serverVersion: String? = nil, apiVersion: String? = nil, userEmail: String? = nil) {
        self.displayName = displayName
        self.serverVersion = serverVersion
        self.apiVersion = apiVersion
        self.userEmail = userEmail
    }
}

/// Página de resultados.
public struct Page<Item: Sendable>: Sendable {
    public var items: [Item]
    public var currentPage: Int
    public var totalPages: Int
    public var totalItems: Int?

    public init(items: [Item], currentPage: Int, totalPages: Int, totalItems: Int? = nil) {
        self.items = items
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalItems = totalItems
    }

    public var hasMore: Bool { currentPage < totalPages }
}

extension Page: Equatable where Item: Equatable {}
extension Page: Codable where Item: Codable {}
