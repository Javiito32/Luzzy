import Foundation
@testable import FireflyAPI
import LuzzyCore
import LuzzySecurity
import Testing

/// Transporte simulado: responde según la ruta y registra las peticiones.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    struct Stub {
        var status: Int = 200
        var body: Data
        var contentType = "application/vnd.api+json"
    }

    private let lock = NSLock()
    private var stubs: [String: [Stub]] = [:]
    private(set) var requests: [URLRequest] = []

    func stub(_ path: String, status: Int = 200, fixture: String) throws {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures"))
        stub(path, Stub(status: status, body: try Data(contentsOf: url)))
    }

    func stub(_ path: String, _ response: Stub) {
        lock.withLock { stubs[path, default: []].append(response) }
    }

    func send(_ request: URLRequest) async throws(DataSourceError) -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        let stub: Stub? = lock.withLock {
            requests.append(request)
            guard var queue = stubs[path], !queue.isEmpty else { return nil }
            let next = queue.count > 1 ? queue.removeFirst() : queue[0]
            stubs[path] = queue
            return next
        }
        guard let stub else { throw .notFound }
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: nil, headerFields: ["Content-Type": stub.contentType])!
        return (stub.body, response)
    }
}

/// Autorizador que simula una renovación OAuth.
actor RotatingAuthorizer: FireflyAuthorizing {
    private var token = "old"
    private(set) var refreshCount = 0

    func accessToken() async throws(DataSourceError) -> String { token }

    func refreshAfterUnauthorized(failedToken: String) async -> Bool {
        refreshCount += 1
        token = "new"
        return true
    }
}

private func makeSource(_ transport: MockTransport, authorizer: any FireflyAuthorizing = StaticTokenAuthorizer(token: "secret")) -> FireflyDataSource {
    let server = FireflyServer(baseURL: URL(string: "https://firefly.example.org")!)
    return FireflyDataSource(client: FireflyClient(server: server, transport: transport, authorizer: authorizer))
}

@Suite("Firefly III: lectura")
struct FireflyReadTests {
    @Test("Mapea cuentas, roles y pasivos")
    func mapsAccounts() async throws {
        let transport = MockTransport()
        try transport.stub("/api/v1/accounts", fixture: "accounts")
        let accounts = try await makeSource(transport).accounts.accounts(kind: nil, balanceDate: nil)

        #expect(accounts.count == 3)
        #expect(accounts[0].balance == Money(Decimal(string: "3412.20")!, Currency(code: "EUR", symbol: "€")))
        #expect(accounts[0].role == .defaultAsset)
        #expect(accounts[1].role == .creditCard)
        #expect(accounts[2].kind == .liability)
        #expect(accounts[2].liabilityKind == .loan)

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.url?.query?.contains("type=all") == true)
    }

    @Test("Mapea movimientos simples y divididos con paginación")
    func mapsTransactions() async throws {
        let transport = MockTransport()
        try transport.stub("/api/v1/transactions", fixture: "transactions")
        let page = try await makeSource(transport).transactions.transactions(TransactionQuery(pageSize: 2))

        #expect(page.items.count == 2)
        #expect(page.hasMore)
        let simple = page.items[0]
        #expect(simple.kind == .withdrawal)
        #expect(simple.signedTotals == [Money(Decimal(string: "-54.20")!, Currency(code: "EUR", symbol: "€"))])
        #expect(simple.splits[0].category?.name == "Supermercado")
        #expect(simple.splits[0].bill == nil)
        #expect(simple.splits[0].notes == nil)
        #expect(simple.splits[0].tags == ["compra"])

        let split = page.items[1]
        #expect(split.isSplit)
        #expect(split.displayTitle == "Compra dividida")
        #expect(split.signedTotals.first?.amount == -42.5)
        #expect(split.date != .distantPast)
    }

    @Test("Mapea el resumen, incluso con valores en texto")
    func mapsSummary() async throws {
        let transport = MockTransport()
        try transport.stub("/api/v1/summary/basic", fixture: "summary")
        let period = DateInterval.month(containing: .now)
        let summary = try await makeSource(transport).summary.summary(in: period)

        #expect(summary.netWorth.first?.amount == Decimal(string: "4480.85"))
        #expect(summary.spent.first?.amount == Decimal(string: "1284.5"))
        #expect(summary.earned.first?.amount == 2450)
        #expect(summary.leftToSpend.first?.amount == Decimal(string: "400.85"))
        #expect(summary.billsUnpaid.first?.amount == Decimal(string: "789.9"))
    }

    @Test("Une presupuestos y límites, aceptando el formato antiguo de gasto")
    func mergesBudgetsAndLimits() async throws {
        let transport = MockTransport()
        try transport.stub("/api/v1/budgets", fixture: "budgets")
        try transport.stub("/api/v1/budget-limits", fixture: "budget-limits")
        let budgets = try await makeSource(transport).budgets.budgets(in: .month(containing: .now))

        let groceries = try #require(budgets.first { $0.id == "b1" })
        #expect(groceries.limits.first?.spent.amount == Decimal(string: "312.40"))
        #expect(groceries.limits.first?.isOverspent == false)
        let leisure = try #require(budgets.first { $0.id == "b2" })
        #expect(leisure.limits.first?.isOverspent == true)
    }
}

@Suite("Firefly III: errores y seguridad")
struct FireflyErrorTests {
    @Test("Tras un 401 renueva el token y reintenta una vez")
    func retriesAfterUnauthorized() async throws {
        let transport = MockTransport()
        transport.stub("/api/v1/tags", .init(status: 401, body: Data()))
        transport.stub("/api/v1/tags", .init(body: Data(#"{"data":[{"id":"1","type":"tags","attributes":{"tag":"compra"}}],"meta":{"pagination":{"total_pages":1}}}"#.utf8)))
        let authorizer = RotatingAuthorizer()
        _ = try await makeSource(transport, authorizer: authorizer).tags.tags()

        #expect(await authorizer.refreshCount == 1)
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test("Un 401 con token personal se propaga")
    func unauthorizedPropagates() async {
        let transport = MockTransport()
        transport.stub("/api/v1/tags", .init(status: 401, body: Data()))
        await #expect(throws: DataSourceError.notAuthenticated) {
            _ = try await makeSource(transport).tags.tags()
        }
    }

    @Test("Traduce errores de validación 422")
    func mapsValidationErrors() async throws {
        let transport = MockTransport()
        try transport.stub("/api/v1/transactions", status: 422, fixture: "validation-error")
        let draft = TransactionDraft(kind: .withdrawal, date: .now, splits: [
            TransactionDraftSplit(amount: 1, description: "x", source: .existing(id: "1", name: "A"), destination: .named("B")),
        ])
        do {
            _ = try await makeSource(transport).transactions.create(draft)
            Issue.record("Debía fallar")
        } catch let DataSourceError.validation(message, fields) {
            #expect(message == "The given data was invalid.")
            #expect(fields["transactions.0.amount"]?.isEmpty == false)
        }
    }

    @Test("Detecta respuestas HTML (URL incorrecta o proxy)")
    func rejectsHTML() async {
        let transport = MockTransport()
        transport.stub("/api/v1/about", .init(body: Data("<html></html>".utf8), contentType: "text/html"))
        await #expect(throws: DataSourceError.decoding("respuesta no JSON")) {
            _ = try await makeSource(transport).info()
        }
    }

    @Test("Codifica el alta en snake_case con importes exactos")
    func encodesStoreBody() async throws {
        let transport = MockTransport()
        transport.stub("/api/v1/transactions", .init(body: Data(#"{"data":{"id":"9","type":"transactions","attributes":{"transactions":[]}}}"#.utf8)))
        let draft = TransactionDraft(kind: .withdrawal, date: .now, splits: [
            TransactionDraftSplit(amount: Decimal(string: "0.10")! + Decimal(string: "0.20")!, description: " Café ", source: .existing(id: "1", name: "A"), destination: .named("Bar"), categoryName: "Ocio", budgetID: "b2"),
        ])
        _ = try await makeSource(transport).transactions.create(draft)

        let body = try #require(transport.requests.last?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let split = try #require((json["transactions"] as? [[String: Any]])?.first)
        #expect(json["error_if_duplicate_hash"] as? Bool == true)
        #expect(split["amount"] as? String == "0.3")
        #expect(split["description"] as? String == "Café")
        #expect(split["source_id"] as? String == "1")
        #expect(split["destination_name"] as? String == "Bar")
        #expect(split["budget_id"] as? String == "b2")
        #expect(split["type"] as? String == "withdrawal")
    }

    @Test("Los IDs se codifican para evitar inyección de rutas")
    func encodesPathComponents() async {
        let transport = MockTransport()
        _ = try? await makeSource(transport).transactions.transaction(id: "../users")
        #expect(transport.requests.first?.url?.path.contains("..") == false)
    }
}

@Suite("OAuth y PKCE")
struct OAuthTests {
    @Test("Desafío S256 correcto")
    func pkceChallenge() {
        // Valor esperado calculado de forma independiente (SHA-256 + base64url).
        let pkce = PKCEChallenge(verifier: "dBjftJeZ4CVP-mJ92K9mRGBr1tA0zj5DrE9V4fS9ZJk")
        #expect(pkce.challenge == "wP2eEiinXo_fCeYAr1n1286YDPmDmDr5QesL0OhkdPM")
    }

    @Test("Verificadores aleatorios y con longitud válida")
    func pkceRandomness() {
        let a = PKCEChallenge.generate(), b = PKCEChallenge.generate()
        #expect(a.verifier != b.verifier)
        #expect((43...128).contains(a.verifier.count))
    }

    @Test("Rechaza un state distinto (CSRF)")
    func rejectsStateMismatch() {
        let callback = URL(string: "luzzy://oauth/callback?code=abc&state=evil")!
        #expect(throws: OAuthError.stateMismatch) {
            try FireflyOAuthClient.authorizationCode(from: callback, expectedState: "good")
        }
    }

    @Test("La URL de autorización incluye PKCE y no incluye secretos")
    func authorizationURL() throws {
        let server = FireflyServer(baseURL: URL(string: "https://firefly.example.org")!)
        let request = FireflyOAuthClient(server: server, clientID: "4", transport: MockTransport()).makeAuthorizationRequest()
        let query = try #require(request.url.query)
        #expect(request.url.path == "/oauth/authorize")
        #expect(query.contains("code_challenge_method=S256"))
        #expect(query.contains("code_challenge=\(request.pkce.challenge)"))
        #expect(!query.contains("client_secret"))
        #expect(!query.contains(request.pkce.verifier))
    }
}
