import Foundation

public enum TransactionFilter: String, Sendable, Codable, CaseIterable {
    case all
    case withdrawals
    case deposits
    case transfers
}

public struct TransactionQuery: Hashable, Sendable {
    public var period: DateInterval?
    public var filter: TransactionFilter
    public var accountID: EntityID?
    public var page: Int
    public var pageSize: Int

    public init(
        period: DateInterval? = nil,
        filter: TransactionFilter = .all,
        accountID: EntityID? = nil,
        page: Int = 1,
        pageSize: Int = 50
    ) {
        self.period = period
        self.filter = filter
        self.accountID = accountID
        self.page = page
        self.pageSize = pageSize
    }
}

/// Cuenta elegida en el formulario: existente o nueva (por nombre).
public enum AccountSelection: Hashable, Sendable, Codable {
    case existing(id: EntityID, name: String)
    case named(String)

    public var displayName: String {
        switch self {
        case .existing(_, let name): name
        case .named(let name): name
        }
    }
}

/// Parte de un borrador de movimiento.
public struct TransactionDraftSplit: Hashable, Sendable, Codable {
    public var amount: Decimal
    public var description: String
    public var source: AccountSelection?
    public var destination: AccountSelection?
    public var categoryName: String?
    public var budgetID: EntityID?
    public var billID: EntityID?
    public var tags: [String]
    public var notes: String?

    public init(
        amount: Decimal,
        description: String,
        source: AccountSelection? = nil,
        destination: AccountSelection? = nil,
        categoryName: String? = nil,
        budgetID: EntityID? = nil,
        billID: EntityID? = nil,
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.amount = amount
        self.description = description
        self.source = source
        self.destination = destination
        self.categoryName = categoryName
        self.budgetID = budgetID
        self.billID = billID
        self.tags = tags
        self.notes = notes
    }
}

/// Borrador para crear o editar un movimiento, independiente del backend.
public struct TransactionDraft: Hashable, Sendable, Codable {
    public var kind: TransactionKind
    public var date: Date
    public var currencyCode: String?
    public var groupTitle: String?
    public var splits: [TransactionDraftSplit]

    public init(
        kind: TransactionKind,
        date: Date,
        currencyCode: String? = nil,
        groupTitle: String? = nil,
        splits: [TransactionDraftSplit]
    ) {
        self.kind = kind
        self.date = date
        self.currencyCode = currencyCode
        self.groupTitle = groupTitle
        self.splits = splits
    }

    public enum ValidationIssue: Hashable, Sendable {
        case noSplits
        case nonPositiveAmount(splitIndex: Int)
        case missingDescription(splitIndex: Int)
        case missingSource(splitIndex: Int)
        case missingDestination(splitIndex: Int)
        case sameSourceAndDestination(splitIndex: Int)
        case missingGroupTitle
    }

    /// Validación local antes de enviar nada al servidor.
    public func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if splits.isEmpty { return [.noSplits] }
        if splits.count > 1, (groupTitle ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.missingGroupTitle)
        }
        for (index, split) in splits.enumerated() {
            if split.amount <= 0 { issues.append(.nonPositiveAmount(splitIndex: index)) }
            if split.description.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(.missingDescription(splitIndex: index))
            }
            if split.source == nil { issues.append(.missingSource(splitIndex: index)) }
            if split.destination == nil { issues.append(.missingDestination(splitIndex: index)) }
            if let source = split.source, source == split.destination {
                issues.append(.sameSourceAndDestination(splitIndex: index))
            }
        }
        return issues
    }
}
