import Foundation

// MARK: - Presupuestos

public struct BudgetLimit: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var budgetID: EntityID
    public var period: DateInterval
    public var amount: Money
    public var spent: Money

    public init(id: EntityID, budgetID: EntityID, period: DateInterval, amount: Money, spent: Money) {
        self.id = id
        self.budgetID = budgetID
        self.period = period
        self.amount = amount
        self.spent = spent
    }

    /// Lo que queda (negativo si se ha excedido).
    public var remaining: Money {
        Money(amount.amount - spent.amount.magnitudeValue, amount.currency)
    }

    /// Fracción consumida entre 0 y 1 (acotada).
    public var progress: Double {
        guard amount.amount > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: spent.amount.magnitudeValue / amount.amount).doubleValue
        return min(max(ratio, 0), 1)
    }

    public var isOverspent: Bool { remaining.amount < 0 }
}

public struct Budget: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var name: String
    public var isActive: Bool
    /// Gasto del periodo consultado por divisa (en positivo).
    public var spent: [Money]
    public var limits: [BudgetLimit]

    public init(id: EntityID, name: String, isActive: Bool, spent: [Money], limits: [BudgetLimit]) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.spent = spent
        self.limits = limits
    }
}

// MARK: - Categorías

public struct Category: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var name: String
    public var notes: String?
    public var spent: [Money]
    public var earned: [Money]

    public init(id: EntityID, name: String, notes: String? = nil, spent: [Money] = [], earned: [Money] = []) {
        self.id = id
        self.name = name
        self.notes = notes
        self.spent = spent
        self.earned = earned
    }
}

// MARK: - Facturas (suscripciones en Firefly ≥ 6.2)

public enum RepeatFrequency: String, Sendable, Codable, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case halfYear
    case yearly
}

public struct Bill: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var name: String
    public var amountMin: Money
    public var amountMax: Money
    public var startDate: Date
    public var frequency: RepeatFrequency
    public var skip: Int
    public var isActive: Bool
    public var nextExpectedMatch: Date?
    /// Fechas esperadas de pago dentro del periodo consultado.
    public var payDates: [Date]
    /// Fechas en las que se pagó dentro del periodo consultado.
    public var paidDates: [Date]
    public var notes: String?

    public init(
        id: EntityID,
        name: String,
        amountMin: Money,
        amountMax: Money,
        startDate: Date,
        frequency: RepeatFrequency,
        skip: Int = 0,
        isActive: Bool = true,
        nextExpectedMatch: Date? = nil,
        payDates: [Date] = [],
        paidDates: [Date] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amountMin = amountMin
        self.amountMax = amountMax
        self.startDate = startDate
        self.frequency = frequency
        self.skip = skip
        self.isActive = isActive
        self.nextExpectedMatch = nextExpectedMatch
        self.payDates = payDates
        self.paidDates = paidDates
        self.notes = notes
    }

    public enum Status: Sendable, Hashable {
        case paid
        case pending
        case upcoming
        case inactive
    }

    /// Estado en el periodo consultado.
    public var status: Status {
        guard isActive else { return .inactive }
        if !paidDates.isEmpty { return .paid }
        if !payDates.isEmpty { return .pending }
        return .upcoming
    }

    /// Importe esperado (media entre mínimo y máximo).
    public var expectedAmount: Money {
        Money((amountMin.amount + amountMax.amount) / 2, amountMin.currency)
    }
}

// MARK: - Huchas

public struct PiggyBank: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var name: String
    public var target: Money?
    public var current: Money
    public var startDate: Date?
    public var targetDate: Date?
    public var accounts: [NamedReference]
    public var isActive: Bool
    public var notes: String?

    public init(
        id: EntityID,
        name: String,
        target: Money?,
        current: Money,
        startDate: Date? = nil,
        targetDate: Date? = nil,
        accounts: [NamedReference] = [],
        isActive: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.current = current
        self.startDate = startDate
        self.targetDate = targetDate
        self.accounts = accounts
        self.isActive = isActive
        self.notes = notes
    }

    public var progress: Double {
        guard let target, target.amount > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: current.amount / target.amount).doubleValue
        return min(max(ratio, 0), 1)
    }

    public var leftToSave: Money? {
        guard let target else { return nil }
        return Money(max(target.amount - current.amount, 0), target.currency)
    }
}

// MARK: - Etiquetas

public struct Tag: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var name: String
    public var description: String?
    public var date: Date?

    public init(id: EntityID, name: String, description: String? = nil, date: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.date = date
    }
}

extension Decimal {
    var magnitudeValue: Decimal { self < 0 ? -self : self }
}
