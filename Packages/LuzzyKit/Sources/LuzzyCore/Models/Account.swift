import Foundation

/// Identificador opaco. Firefly usa enteros en texto; iCloud usará UUID.
public typealias EntityID = String

public enum AccountKind: String, Sendable, Codable, CaseIterable {
    case asset
    case expense
    case revenue
    case liability
    case cash
    case other
}

public enum AccountRole: String, Sendable, Codable {
    case defaultAsset
    case sharedAsset
    case savingAsset
    case creditCard
    case cashWallet
}

public enum LiabilityKind: String, Sendable, Codable {
    case loan
    case debt
    case mortgage
}

public struct Account: Identifiable, Hashable, Sendable, Codable {
    public var id: EntityID
    public var name: String
    public var kind: AccountKind
    public var role: AccountRole?
    public var liabilityKind: LiabilityKind?
    public var balance: Money
    public var iban: String?
    public var accountNumber: String?
    public var isActive: Bool
    public var includeInNetWorth: Bool
    public var notes: String?
    public var lastActivity: Date?

    public init(
        id: EntityID,
        name: String,
        kind: AccountKind,
        role: AccountRole? = nil,
        liabilityKind: LiabilityKind? = nil,
        balance: Money,
        iban: String? = nil,
        accountNumber: String? = nil,
        isActive: Bool = true,
        includeInNetWorth: Bool = true,
        notes: String? = nil,
        lastActivity: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.role = role
        self.liabilityKind = liabilityKind
        self.balance = balance
        self.iban = iban
        self.accountNumber = accountNumber
        self.isActive = isActive
        self.includeInNetWorth = includeInNetWorth
        self.notes = notes
        self.lastActivity = lastActivity
    }

    /// Últimos 4 dígitos del IBAN o número de cuenta, para mostrar sin exponer el dato completo.
    public var maskedNumber: String? {
        let raw = (iban ?? accountNumber)?.replacingOccurrences(of: " ", with: "")
        guard let raw, raw.count >= 4 else { return nil }
        return "···· " + raw.suffix(4)
    }
}

/// Referencia ligera a una cuenta dentro de un movimiento.
public struct AccountReference: Hashable, Sendable, Codable {
    public var id: EntityID?
    public var name: String
    public var kind: AccountKind?

    public init(id: EntityID?, name: String, kind: AccountKind?) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

/// Referencia ligera a una entidad con nombre (categoría, presupuesto, factura…).
public struct NamedReference: Hashable, Sendable, Codable, Identifiable {
    public var id: EntityID
    public var name: String

    public init(id: EntityID, name: String) {
        self.id = id
        self.name = name
    }
}

/// Resultado de búsqueda de cuentas para los selectores del formulario.
public struct AccountSuggestion: Hashable, Sendable, Codable, Identifiable {
    public var id: EntityID
    public var name: String
    public var kind: AccountKind
    public var currency: Currency

    public init(id: EntityID, name: String, kind: AccountKind, currency: Currency) {
        self.id = id
        self.name = name
        self.kind = kind
        self.currency = currency
    }
}
