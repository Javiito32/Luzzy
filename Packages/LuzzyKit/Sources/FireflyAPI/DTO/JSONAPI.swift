import Foundation

// Envoltorios JSON:API que usa Firefly III.

struct JSONAPIList<Attributes: Decodable & Sendable>: Decodable, Sendable {
    let data: [JSONAPIResource<Attributes>]
    let meta: JSONAPIMeta?
}

struct JSONAPISingle<Attributes: Decodable & Sendable>: Decodable, Sendable {
    let data: JSONAPIResource<Attributes>
}

struct JSONAPIResource<Attributes: Decodable & Sendable>: Decodable, Sendable {
    let id: String
    let type: String?
    let attributes: Attributes
}

struct JSONAPIMeta: Decodable, Sendable {
    struct Pagination: Decodable, Sendable {
        let total: Int?
        let count: Int?
        let perPage: Int?
        let currentPage: Int?
        let totalPages: Int?
    }

    let pagination: Pagination?
}

/// Número que puede llegar como JSON number o como texto.
struct FlexibleDecimal: Decodable, Sendable {
    let value: Decimal?

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let decimal = try? container.decode(Decimal.self) {
            value = decimal
        } else if let text = try? container.decode(String.self) {
            value = Decimal(fireflyAmount: text)
        } else {
            value = nil
        }
    }
}

/// Lista de sumas por divisa. Versiones antiguas de Firefly devolvían un texto.
struct FlexibleSums: Decodable, Sendable {
    let entries: [CurrencySumDTO]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([CurrencySumDTO].self) {
            entries = list
        } else if let text = try? container.decode(String.self) {
            entries = [CurrencySumDTO(currencyCode: nil, currencySymbol: nil, currencyDecimalPlaces: nil, sum: text)]
        } else {
            entries = []
        }
    }
}

struct CurrencySumDTO: Decodable, Sendable {
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let sum: String?
}

extension Decimal {
    /// Firefly envía importes como texto con punto decimal ("123.45").
    init?(fireflyAmount text: String?) {
        guard let text, let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        self = value
    }

    /// Formato que espera Firefly al enviar importes.
    var fireflyString: String {
        var copy = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &copy, 12, .plain)
        return NSDecimalNumber(decimal: rounded).description(withLocale: Locale(identifier: "en_US_POSIX"))
    }
}
