import Foundation

/// Divisa tal y como la describe el origen de datos.
public struct Currency: Hashable, Sendable, Codable {
    public var code: String
    public var symbol: String
    public var decimalPlaces: Int

    public init(code: String, symbol: String? = nil, decimalPlaces: Int = 2) {
        self.code = code.uppercased()
        self.symbol = symbol ?? code.uppercased()
        self.decimalPlaces = decimalPlaces
    }

    public static let euro = Currency(code: "EUR", symbol: "€", decimalPlaces: 2)
}

/// Importe monetario exacto. Nunca se usa `Double` para dinero.
public struct Money: Hashable, Sendable, Codable {
    public var amount: Decimal
    public var currency: Currency

    public init(_ amount: Decimal, _ currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    public static func zero(_ currency: Currency) -> Money {
        Money(0, currency)
    }

    public var isNegative: Bool { amount < 0 }
    public var isZero: Bool { amount == 0 }

    public var magnitude: Money {
        Money(amount < 0 ? -amount : amount, currency)
    }

    public var negated: Money {
        Money(-amount, currency)
    }

    /// Suma solo si ambas cantidades están en la misma divisa.
    public func adding(_ other: Money) -> Money? {
        guard other.currency.code == currency.code else { return nil }
        return Money(amount + other.amount, currency)
    }
}

public extension Sequence where Element == Money {
    /// Agrupa y suma los importes por divisa, conservando el orden de aparición.
    func totalsByCurrency() -> [Money] {
        var order: [String] = []
        var totals: [String: Money] = [:]
        for money in self {
            if let existing = totals[money.currency.code] {
                totals[money.currency.code] = Money(existing.amount + money.amount, existing.currency)
            } else {
                order.append(money.currency.code)
                totals[money.currency.code] = money
            }
        }
        return order.compactMap { totals[$0] }
    }
}

public extension Money {
    /// Formato de moneda localizado. `showsSign` fuerza el signo "+" en positivos.
    func formatted(locale: Locale = .autoupdatingCurrent, showsSign: Bool = false) -> String {
        let style = Decimal.FormatStyle.Currency(code: currency.code, locale: locale)
            .precision(.fractionLength(currency.decimalPlaces))
            .sign(strategy: showsSign ? .always() : .automatic)
        return amount.formatted(style)
    }
}
