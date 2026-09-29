import Foundation

public enum TransactionKind: String, Sendable, Codable, CaseIterable {
    case withdrawal
    case deposit
    case transfer
    case reconciliation
    case openingBalance
}

/// Una parte de un movimiento. Firefly permite dividir un movimiento en varias partes.
public struct TransactionSplit: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var kind: TransactionKind
    public var date: Date
    public var amount: Money
    public var foreignAmount: Money?
    public var description: String
    public var source: AccountReference
    public var destination: AccountReference
    public var category: NamedReference?
    public var budget: NamedReference?
    public var bill: NamedReference?
    public var tags: [String]
    public var notes: String?
    public var isReconciled: Bool

    public init(
        id: EntityID,
        kind: TransactionKind,
        date: Date,
        amount: Money,
        foreignAmount: Money? = nil,
        description: String,
        source: AccountReference,
        destination: AccountReference,
        category: NamedReference? = nil,
        budget: NamedReference? = nil,
        bill: NamedReference? = nil,
        tags: [String] = [],
        notes: String? = nil,
        isReconciled: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.amount = amount
        self.foreignAmount = foreignAmount
        self.description = description
        self.source = source
        self.destination = destination
        self.category = category
        self.budget = budget
        self.bill = bill
        self.tags = tags
        self.notes = notes
        self.isReconciled = isReconciled
    }

    /// Importe con signo desde el punto de vista del usuario:
    /// gastos en negativo, ingresos en positivo, transferencias sin signo.
    public var signedAmount: Money {
        switch kind {
        case .withdrawal: amount.magnitude.negated
        case .deposit: amount.magnitude
        default: amount.magnitude
        }
    }
}

/// Grupo de movimientos (lo que el usuario ve como "un movimiento").
public struct TransactionGroup: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var title: String?
    public var splits: [TransactionSplit]

    public init(id: EntityID, title: String?, splits: [TransactionSplit]) {
        self.id = id
        self.title = title
        self.splits = splits
    }

    public var kind: TransactionKind { splits.first?.kind ?? .withdrawal }
    public var date: Date { splits.first?.date ?? .distantPast }
    public var isSplit: Bool { splits.count > 1 }

    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return splits.first?.description ?? ""
    }

    /// Totales con signo por divisa.
    public var signedTotals: [Money] {
        splits.map(\.signedAmount).totalsByCurrency()
    }
}
