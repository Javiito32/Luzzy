import Foundation
import LuzzyCore

// DTO → dominio. Toda la tolerancia a datos incompletos vive aquí.

enum FireflyMapping {
    static func currency(code: String?, symbol: String?, decimals: Int?) -> Currency {
        Currency(code: code ?? "EUR", symbol: symbol, decimalPlaces: decimals ?? 2)
    }

    static func money(_ text: String?, code: String?, symbol: String?, decimals: Int?) -> Money {
        Money(Decimal(fireflyAmount: text) ?? 0, currency(code: code, symbol: symbol, decimals: decimals))
    }

    static func sums(_ sums: FlexibleSums?, fallback: Currency? = nil) -> [Money] {
        (sums?.entries ?? []).compactMap { entry in
            guard let amount = Decimal(fireflyAmount: entry.sum) else { return nil }
            let currency = entry.currencyCode == nil && fallback != nil
                ? fallback!
                : currency(code: entry.currencyCode, symbol: entry.currencySymbol, decimals: entry.currencyDecimalPlaces)
            return Money(amount < 0 ? -amount : amount, currency)
        }
    }

    // MARK: Cuentas

    static func accountKind(_ type: String?) -> AccountKind {
        switch type?.lowercased() {
        case "asset", "asset account", "default account": .asset
        case "expense", "expense account", "beneficiary account": .expense
        case "revenue", "revenue account": .revenue
        case "liability", "liabilities", "loan", "debt", "mortgage": .liability
        case "cash", "cash account": .cash
        default: .other
        }
    }

    static func accountRole(_ role: String?) -> AccountRole? {
        switch role {
        case "defaultAsset": .defaultAsset
        case "sharedAsset": .sharedAsset
        case "savingAsset": .savingAsset
        case "ccAsset": .creditCard
        case "cashWalletAsset": .cashWallet
        default: nil
        }
    }

    static func account(_ resource: JSONAPIResource<AccountAttributes>) -> Account {
        let a = resource.attributes
        return Account(
            id: resource.id,
            name: a.name,
            kind: accountKind(a.type),
            role: accountRole(a.accountRole),
            liabilityKind: a.liabilityType.flatMap(LiabilityKind.init(rawValue:)),
            balance: money(a.currentBalance, code: a.currencyCode, symbol: a.currencySymbol, decimals: a.currencyDecimalPlaces),
            iban: a.iban?.nilIfEmpty,
            accountNumber: a.accountNumber?.nilIfEmpty,
            isActive: a.active ?? true,
            includeInNetWorth: a.includeNetWorth ?? true,
            notes: a.notes?.nilIfEmpty,
            lastActivity: FireflyDates.parse(a.lastActivity)
        )
    }

    // MARK: Movimientos

    static func transactionKind(_ type: String?) -> TransactionKind {
        switch type?.lowercased() {
        case "deposit": .deposit
        case "transfer": .transfer
        case "reconciliation": .reconciliation
        case "opening balance", "opening_balance": .openingBalance
        default: .withdrawal
        }
    }

    static func transactionType(_ kind: TransactionKind) -> String {
        switch kind {
        case .withdrawal: "withdrawal"
        case .deposit: "deposit"
        case .transfer: "transfer"
        case .reconciliation: "reconciliation"
        case .openingBalance: "opening balance"
        }
    }

    static func group(_ resource: JSONAPIResource<TransactionGroupAttributes>) -> TransactionGroup {
        let splits = resource.attributes.transactions.enumerated().map { index, dto in
            split(dto, fallbackID: "\(resource.id)-\(index)")
        }
        return TransactionGroup(id: resource.id, title: resource.attributes.groupTitle?.nilIfEmpty, splits: splits)
    }

    static func split(_ dto: TransactionSplitDTO, fallbackID: String) -> TransactionSplit {
        let foreign: Money? = dto.foreignAmount.flatMap { text in
            guard let value = Decimal(fireflyAmount: text), dto.foreignCurrencyCode != nil else { return nil }
            return Money(value, currency(code: dto.foreignCurrencyCode, symbol: dto.foreignCurrencySymbol, decimals: dto.foreignCurrencyDecimalPlaces))
        }
        let billID = dto.billId ?? dto.subscriptionId
        let billName = dto.billName ?? dto.subscriptionName
        return TransactionSplit(
            id: dto.transactionJournalId ?? fallbackID,
            kind: transactionKind(dto.type),
            date: FireflyDates.parse(dto.date) ?? .distantPast,
            amount: money(dto.amount, code: dto.currencyCode, symbol: dto.currencySymbol, decimals: dto.currencyDecimalPlaces).magnitude,
            foreignAmount: foreign?.magnitude,
            description: dto.description ?? "",
            source: AccountReference(id: dto.sourceId, name: dto.sourceName ?? "", kind: accountKind(dto.sourceType)),
            destination: AccountReference(id: dto.destinationId, name: dto.destinationName ?? "", kind: accountKind(dto.destinationType)),
            category: named(dto.categoryId, dto.categoryName),
            budget: named(dto.budgetId, dto.budgetName),
            bill: named(billID, billName),
            tags: dto.tags ?? [],
            notes: dto.notes?.nilIfEmpty,
            isReconciled: dto.reconciled ?? false
        )
    }

    static func named(_ id: String?, _ name: String?) -> NamedReference? {
        guard let id, !id.isEmpty, id != "0" else { return nil }
        return NamedReference(id: id, name: name ?? "")
    }

    static func store(_ draft: TransactionDraft) -> [SplitStoreDTO] {
        draft.splits.map { split in
            let (sourceID, sourceName) = selection(split.source)
            let (destinationID, destinationName) = selection(split.destination)
            return SplitStoreDTO(
                transactionJournalId: nil,
                type: transactionType(draft.kind),
                date: FireflyDates.timestamp(draft.date),
                amount: split.amount.fireflyString,
                description: split.description.trimmingCharacters(in: .whitespacesAndNewlines),
                currencyCode: draft.currencyCode,
                sourceId: sourceID,
                sourceName: sourceName,
                destinationId: destinationID,
                destinationName: destinationName,
                categoryName: split.categoryName?.nilIfEmpty,
                budgetId: draft.kind == .withdrawal ? split.budgetID : nil,
                billId: draft.kind == .withdrawal ? split.billID : nil,
                tags: split.tags.isEmpty ? nil : split.tags,
                notes: split.notes?.nilIfEmpty
            )
        }
    }

    private static func selection(_ selection: AccountSelection?) -> (String?, String?) {
        switch selection {
        case .existing(let id, _): (id, nil)
        case .named(let name): (nil, name.trimmingCharacters(in: .whitespacesAndNewlines))
        case nil: (nil, nil)
        }
    }

    // MARK: Planificación

    static func budgetLimit(_ resource: JSONAPIResource<BudgetLimitAttributes>, budgetID fallbackBudgetID: String? = nil) -> BudgetLimit? {
        let a = resource.attributes
        guard let budgetID = a.budgetId ?? fallbackBudgetID,
              let start = FireflyDates.parse(a.start),
              let endDay = FireflyDates.parse(a.end)
        else { return nil }
        let amount = money(a.amount, code: a.currencyCode, symbol: a.currencySymbol, decimals: a.currencyDecimalPlaces)
        // Firefly devuelve `end` como último día inclusivo; el dominio usa fin exclusivo.
        let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: endDay)) ?? endDay
        let spentTotal = sums(a.spent, fallback: amount.currency)
            .filter { $0.currency.code == amount.currency.code }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return BudgetLimit(
            id: resource.id,
            budgetID: budgetID,
            period: DateInterval(start: start, end: max(end, start)),
            amount: amount,
            spent: Money(spentTotal, amount.currency)
        )
    }

    static func budget(_ resource: JSONAPIResource<BudgetAttributes>, limits: [BudgetLimit]) -> Budget {
        Budget(
            id: resource.id,
            name: resource.attributes.name,
            isActive: resource.attributes.active ?? true,
            spent: sums(resource.attributes.spent),
            limits: limits.filter { $0.budgetID == resource.id }
        )
    }

    static func category(_ resource: JSONAPIResource<CategoryAttributes>) -> LuzzyCore.Category {
        LuzzyCore.Category(
            id: resource.id,
            name: resource.attributes.name,
            notes: resource.attributes.notes?.nilIfEmpty,
            spent: sums(resource.attributes.spent),
            earned: sums(resource.attributes.earned)
        )
    }

    static func frequency(_ text: String?) -> RepeatFrequency {
        switch text {
        case "weekly": .weekly
        case "quarterly": .quarterly
        case "half-year": .halfYear
        case "yearly": .yearly
        default: .monthly
        }
    }

    static func bill(_ resource: JSONAPIResource<BillAttributes>) -> Bill {
        let a = resource.attributes
        return Bill(
            id: resource.id,
            name: a.name,
            amountMin: money(a.amountMin, code: a.currencyCode, symbol: a.currencySymbol, decimals: a.currencyDecimalPlaces),
            amountMax: money(a.amountMax, code: a.currencyCode, symbol: a.currencySymbol, decimals: a.currencyDecimalPlaces),
            startDate: FireflyDates.parse(a.date) ?? .distantPast,
            frequency: frequency(a.repeatFreq),
            skip: a.skip ?? 0,
            isActive: a.active ?? true,
            nextExpectedMatch: FireflyDates.parse(a.nextExpectedMatch),
            payDates: (a.payDates ?? []).compactMap { FireflyDates.parse($0) },
            paidDates: (a.paidDates ?? []).compactMap { FireflyDates.parse($0.date) },
            notes: a.notes?.nilIfEmpty
        )
    }

    static func piggyBank(_ resource: JSONAPIResource<PiggyBankAttributes>) -> PiggyBank {
        let a = resource.attributes
        let currency = currency(code: a.currencyCode, symbol: a.currencySymbol, decimals: a.currencyDecimalPlaces)
        var accounts = (a.accounts ?? []).compactMap { linked -> NamedReference? in
            guard let id = linked.accountId else { return nil }
            return NamedReference(id: id, name: linked.name ?? "")
        }
        if accounts.isEmpty, let id = a.accountId {
            accounts = [NamedReference(id: id, name: a.accountName ?? "")]
        }
        return PiggyBank(
            id: resource.id,
            name: a.name,
            target: Decimal(fireflyAmount: a.targetAmount).flatMap { $0 > 0 ? Money($0, currency) : nil },
            current: Money(Decimal(fireflyAmount: a.currentAmount) ?? 0, currency),
            startDate: FireflyDates.parse(a.startDate),
            targetDate: FireflyDates.parse(a.targetDate),
            accounts: accounts,
            isActive: a.active ?? true,
            notes: a.notes?.nilIfEmpty
        )
    }

    static func tag(_ resource: JSONAPIResource<TagAttributes>) -> Tag {
        Tag(
            id: resource.id,
            name: resource.attributes.tag,
            description: resource.attributes.description?.nilIfEmpty,
            date: FireflyDates.parse(resource.attributes.date)
        )
    }

    // MARK: Resumen

    static func summary(_ entries: [String: SummaryEntryDTO], period: DateInterval) -> FinancialSummary {
        var summary = FinancialSummary(period: period)
        for (key, entry) in entries {
            guard let value = entry.monetaryValue?.value else { continue }
            let money = Money(value, currency(code: entry.currencyCode, symbol: entry.currencySymbol, decimals: entry.currencyDecimalPlaces))
            let prefix = (entry.key ?? key).components(separatedBy: "-in-").first ?? ""
            switch prefix {
            case "net-worth": summary.netWorth.append(money)
            case "balance": summary.balance.append(money)
            case "spent": summary.spent.append(money.magnitude)
            case "earned": summary.earned.append(money.magnitude)
            case "bills-paid": summary.billsPaid.append(money.magnitude)
            case "bills-unpaid": summary.billsUnpaid.append(money.magnitude)
            case "left-to-spend": summary.leftToSpend.append(money)
            default: continue
            }
        }
        let byCode: (Money, Money) -> Bool = { $0.currency.code < $1.currency.code }
        summary.netWorth.sort(by: byCode)
        summary.balance.sort(by: byCode)
        summary.spent.sort(by: byCode)
        summary.earned.sort(by: byCode)
        summary.billsPaid.sort(by: byCode)
        summary.billsUnpaid.sort(by: byCode)
        summary.leftToSpend.sort(by: byCode)
        return summary
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
