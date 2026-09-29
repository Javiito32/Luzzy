import Foundation

// DTOs de la API v1 (verificados contra la especificación OpenAPI v6.7.6).
// Todos los campos son opcionales salvo los imprescindibles: los servidores
// reales omiten campos según versión y configuración.

struct AccountAttributes: Decodable, Sendable {
    let name: String
    let type: String?
    let accountRole: String?
    let active: Bool?
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let currentBalance: String?
    let iban: String?
    let accountNumber: String?
    let includeNetWorth: Bool?
    let notes: String?
    let liabilityType: String?
    let lastActivity: String?
}

struct TransactionGroupAttributes: Decodable, Sendable {
    let groupTitle: String?
    let transactions: [TransactionSplitDTO]
}

struct TransactionSplitDTO: Decodable, Sendable {
    let transactionJournalId: String?
    let type: String?
    let date: String?
    let amount: String?
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let foreignAmount: String?
    let foreignCurrencyCode: String?
    let foreignCurrencySymbol: String?
    let foreignCurrencyDecimalPlaces: Int?
    let description: String?
    let sourceId: String?
    let sourceName: String?
    let sourceType: String?
    let destinationId: String?
    let destinationName: String?
    let destinationType: String?
    let budgetId: String?
    let budgetName: String?
    let categoryId: String?
    let categoryName: String?
    let billId: String?
    let billName: String?
    let subscriptionId: String?
    let subscriptionName: String?
    let tags: [String]?
    let notes: String?
    let reconciled: Bool?
}

struct BudgetAttributes: Decodable, Sendable {
    let name: String
    let active: Bool?
    let spent: FlexibleSums?
}

struct BudgetLimitAttributes: Decodable, Sendable {
    let start: String?
    let end: String?
    let budgetId: String?
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let amount: String?
    let spent: FlexibleSums?
}

struct CategoryAttributes: Decodable, Sendable {
    let name: String
    let notes: String?
    let spent: FlexibleSums?
    let earned: FlexibleSums?
}

struct BillAttributes: Decodable, Sendable {
    struct PaidDate: Decodable, Sendable {
        let date: String?
    }

    let name: String
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let amountMin: String?
    let amountMax: String?
    let date: String?
    let repeatFreq: String?
    let skip: Int?
    let active: Bool?
    let notes: String?
    let nextExpectedMatch: String?
    let payDates: [String]?
    let paidDates: [PaidDate]?
}

struct PiggyBankAttributes: Decodable, Sendable {
    struct LinkedAccount: Decodable, Sendable {
        let accountId: String?
        let name: String?
    }

    let name: String
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let targetAmount: String?
    let currentAmount: String?
    let startDate: String?
    let targetDate: String?
    let active: Bool?
    let notes: String?
    /// Firefly ≥ 6.2: una hucha puede estar ligada a varias cuentas.
    let accounts: [LinkedAccount]?
    /// Firefly < 6.2.
    let accountId: String?
    let accountName: String?
}

struct TagAttributes: Decodable, Sendable {
    let tag: String
    let description: String?
    let date: String?
}

struct SummaryEntryDTO: Decodable, Sendable {
    let key: String?
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
    let monetaryValue: FlexibleDecimal?
}

struct AboutDTO: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        let version: String?
        let apiVersion: String?
    }

    let data: Info
}

struct UserAttributes: Decodable, Sendable {
    let email: String?
}

struct AutocompleteAccountDTO: Decodable, Sendable {
    let id: String
    let name: String
    let type: String?
    let currencyCode: String?
    let currencySymbol: String?
    let currencyDecimalPlaces: Int?
}

// MARK: - Escritura

struct TransactionStoreDTO: Encodable, Sendable {
    let errorIfDuplicateHash: Bool
    let applyRules: Bool
    let fireWebhooks: Bool
    let groupTitle: String?
    let transactions: [SplitStoreDTO]
}

struct TransactionUpdateDTO: Encodable, Sendable {
    let applyRules: Bool
    let fireWebhooks: Bool
    let groupTitle: String?
    let transactions: [SplitStoreDTO]
}

struct SplitStoreDTO: Encodable, Sendable {
    var transactionJournalId: String?
    let type: String
    let date: String
    let amount: String
    let description: String
    let currencyCode: String?
    let sourceId: String?
    let sourceName: String?
    let destinationId: String?
    let destinationName: String?
    let categoryName: String?
    let budgetId: String?
    let billId: String?
    let tags: [String]?
    let notes: String?
}
