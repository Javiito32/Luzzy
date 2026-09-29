import Foundation
@testable import LuzzyCore
import Testing

@Suite("Política de URL del servidor")
struct ServerURLPolicyTests {
    @Test("Añade https y elimina el sufijo /api/v1")
    func normalizesURL() throws {
        let url = try ServerURLPolicy.normalize("  firefly.example.org/api/v1/  ")
        #expect(url.absoluteString == "https://firefly.example.org")
    }

    @Test("Conserva subrutas de instalación")
    func keepsSubpath() throws {
        let url = try ServerURLPolicy.normalize("https://example.org/firefly/")
        #expect(url.absoluteString == "https://example.org/firefly")
    }

    @Test("Rechaza HTTP hacia hosts públicos")
    func rejectsPublicHTTP() {
        #expect(throws: ServerURLError.insecureScheme) {
            try ServerURLPolicy.normalize("http://firefly.example.org")
        }
    }

    @Test("Permite HTTP en red local", arguments: [
        "http://192.168.1.20:8080", "http://10.0.0.5", "http://nas.local", "http://nas", "http://localhost:8080",
        "http://100.100.1.2", "http://[fd12:3456::1]",
    ])
    func allowsLocalHTTP(_ input: String) throws {
        _ = try ServerURLPolicy.normalize(input)
    }

    @Test("Rechaza credenciales embebidas")
    func rejectsEmbeddedCredentials() {
        #expect(throws: ServerURLError.embeddedCredentials) {
            try ServerURLPolicy.normalize("https://user:pass@firefly.example.org")
        }
    }

    @Test("Rechaza esquemas no web")
    func rejectsOtherSchemes() {
        #expect(throws: ServerURLError.unsupportedScheme) {
            try ServerURLPolicy.normalize("ftp://firefly.example.org")
        }
    }

    @Test("No confunde IP públicas con privadas", arguments: ["8.8.8.8", "172.32.0.1", "192.169.0.1", "100.128.0.1"])
    func publicIPsAreNotLocal(_ host: String) {
        #expect(!ServerURLPolicy.isLocalNetworkHost(host))
    }
}

@Suite("Dinero")
struct MoneyTests {
    let usd = Currency(code: "USD", symbol: "$")

    @Test("Suma por divisa conservando el orden")
    func totalsByCurrency() {
        let totals = [Money(10, .euro), Money(5, usd), Money(2.5, .euro)].totalsByCurrency()
        #expect(totals == [Money(12.5, .euro), Money(5, usd)])
    }

    @Test("No suma divisas distintas")
    func refusesMixedCurrencies() {
        #expect(Money(1, .euro).adding(Money(1, usd)) == nil)
    }

    @Test("Signo según el tipo de movimiento")
    func signedAmounts() {
        let reference = AccountReference(id: "1", name: "A", kind: .asset)
        func split(_ kind: TransactionKind) -> TransactionSplit {
            TransactionSplit(id: "1", kind: kind, date: .now, amount: Money(10, .euro), description: "x", source: reference, destination: reference)
        }
        #expect(split(.withdrawal).signedAmount.amount == -10)
        #expect(split(.deposit).signedAmount.amount == 10)
        #expect(split(.transfer).signedAmount.amount == 10)
    }

    @Test("El número de cuenta se enmascara")
    func masksAccountNumber() {
        let account = Account(id: "1", name: "A", kind: .asset, balance: .zero(.euro), iban: "ES91 2100 0418 4502 0005 1332")
        #expect(account.maskedNumber == "···· 1332")
    }
}

@Suite("Planificación")
struct PlanningTests {
    @Test("Límite excedido")
    func overspentLimit() {
        let limit = BudgetLimit(id: "l", budgetID: "b", period: DateInterval(start: .now, duration: 86_400), amount: Money(120, .euro), spent: Money(148, .euro))
        #expect(limit.isOverspent)
        #expect(limit.remaining.amount == -28)
        #expect(limit.progress == 1)
    }

    @Test("Estado de factura")
    func billStatus() {
        let base = Bill(id: "1", name: "Alquiler", amountMin: Money(750, .euro), amountMax: Money(750, .euro), startDate: .now, frequency: .monthly)
        var paid = base
        paid.paidDates = [.now]
        var pending = base
        pending.payDates = [.now]
        #expect(paid.status == .paid)
        #expect(pending.status == .pending)
        #expect(base.status == .upcoming)
    }
}

@Suite("Borradores de movimiento")
struct DraftValidationTests {
    @Test("Detecta campos obligatorios")
    func detectsMissingFields() {
        let draft = TransactionDraft(kind: .withdrawal, date: .now, splits: [TransactionDraftSplit(amount: 0, description: " ")])
        let issues = draft.validate()
        #expect(issues.contains(.nonPositiveAmount(splitIndex: 0)))
        #expect(issues.contains(.missingDescription(splitIndex: 0)))
        #expect(issues.contains(.missingSource(splitIndex: 0)))
        #expect(issues.contains(.missingDestination(splitIndex: 0)))
    }

    @Test("Un movimiento dividido necesita título")
    func splitNeedsTitle() {
        let split = TransactionDraftSplit(amount: 1, description: "a", source: .named("A"), destination: .named("B"))
        let draft = TransactionDraft(kind: .withdrawal, date: .now, splits: [split, split])
        #expect(draft.validate() == [.missingGroupTitle])
    }
}

@Suite("Origen de datos demo")
struct DemoDataSourceTests {
    @Test("Crear un movimiento lo añade al listado")
    func createAppearsInList() async throws {
        let source = DemoDataSource()
        let draft = TransactionDraft(kind: .withdrawal, date: .now, splits: [
            TransactionDraftSplit(amount: 9.99, description: "Café", source: .existing(id: "1", name: "Cuenta nómina"), destination: .named("Cafetería")),
        ])
        let created = try await source.transactions.create(draft)
        let page = try await source.transactions.transactions(TransactionQuery())
        #expect(page.items.first?.id == created.id)
        #expect(created.splits.first?.destination.name == "Cafetería")
    }

    @Test("El filtro por tipo funciona")
    func filtersByKind() async throws {
        let page = try await DemoDataSource().transactions.transactions(TransactionQuery(filter: .transfers))
        #expect(!page.items.isEmpty)
        #expect(page.items.allSatisfy { $0.kind == .transfer })
    }
}

@Suite("Caché con actualización")
struct CachedFetcherTests {
    actor MemoryCache: SnapshotCache {
        var storage: [String: Data] = [:]

        func load<Value: Codable & Sendable>(_ type: Value.Type, key: String) async -> CachedValue<Value>? {
            guard let data = storage[key], let value = try? JSONDecoder().decode(Value.self, from: data) else { return nil }
            return CachedValue(value: value, updatedAt: .now)
        }

        func store<Value: Codable & Sendable>(_ value: Value, key: String) async {
            storage[key] = try? JSONEncoder().encode(value)
        }

        func removeAll() async { storage = [:] }
    }

    @Test("Emite la caché y luego guarda el valor fresco")
    func emitsCachedThenFresh() async throws {
        let cache = MemoryCache()
        await cache.store([1, 2], key: "k")
        let fetcher = CachedFetcher(cache: cache)
        let seen = Seen()
        let fresh = try await fetcher.fetch(key: "k", cached: { (hit: CachedValue<[Int]>) in await seen.record(hit.value) }, remote: { [3] })
        #expect(fresh == [3])
        #expect(await seen.values == [[1, 2]])
        #expect(await cache.load([Int].self, key: "k")?.value == [3])
    }

    actor Seen {
        var values: [[Int]] = []
        func record(_ value: [Int]) { values.append(value) }
    }
}
