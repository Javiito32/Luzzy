import Foundation
import LuzzyCore

/// Proveedor del token de acceso (token personal u OAuth con renovación).
public protocol FireflyAuthorizing: Sendable {
    func accessToken() async throws(DataSourceError) -> String
    /// Se invoca tras un 401. Devuelve `true` si se obtuvo un token nuevo y conviene reintentar.
    func refreshAfterUnauthorized(failedToken: String) async -> Bool
}

/// Token fijo (se usa para validar un token antes de guardarlo).
public struct StaticTokenAuthorizer: FireflyAuthorizing {
    private let token: String
    public init(token: String) { self.token = token }
    public func accessToken() async throws(DataSourceError) -> String { token }
    public func refreshAfterUnauthorized(failedToken: String) async -> Bool { false }
}

/// Cliente de bajo nivel de la API v1 de Firefly III.
public final class FireflyClient: Sendable {
    public let server: FireflyServer
    private let transport: any HTTPTransport
    private let authorizer: any FireflyAuthorizing

    public init(server: FireflyServer, transport: any HTTPTransport, authorizer: any FireflyAuthorizing) {
        self.server = server
        self.transport = transport
        self.authorizer = authorizer
    }

    // MARK: Peticiones tipadas

    func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws(DataSourceError) -> Response {
        let data = try await perform(method: "GET", path: path, query: query, body: nil)
        return try decode(Response.self, from: data)
    }

    func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        body: Body
    ) async throws(DataSourceError) -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let payload: Data
        do { payload = try encoder.encode(body) } catch { throw .unknown("codificación") }
        let data = try await perform(method: method, path: path, query: [], body: payload)
        return try decode(Response.self, from: data)
    }

    func delete(_ path: String) async throws(DataSourceError) {
        _ = try await perform(method: "DELETE", path: path, query: [], body: nil)
    }

    /// Descarga todas las páginas de un listado, con un límite de seguridad.
    func getAllPages<Attributes: Decodable & Sendable>(
        _ path: String,
        query: [URLQueryItem] = [],
        pageSize: Int = 100,
        maxPages: Int = 50
    ) async throws(DataSourceError) -> [JSONAPIResource<Attributes>] {
        var resources: [JSONAPIResource<Attributes>] = []
        var page = 1
        while page <= maxPages {
            let items = query + [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: String(pageSize))]
            let list: JSONAPIList<Attributes> = try await get(path, query: items)
            resources += list.data
            let totalPages = list.meta?.pagination?.totalPages ?? 1
            if page >= totalPages || list.data.isEmpty { break }
            page += 1
        }
        return resources
    }

    // MARK: Núcleo

    func perform(method: String, path: String, query: [URLQueryItem], body: Data?) async throws(DataSourceError) -> Data {
        let token = try await authorizer.accessToken()
        let (data, response) = try await transport.send(request(method, path, query, body, token: token))
        if response.statusCode == 401, await authorizer.refreshAfterUnauthorized(failedToken: token) {
            let retryToken = try await authorizer.accessToken()
            let (retryData, retryResponse) = try await transport.send(request(method, path, query, body, token: retryToken))
            return try validate(retryData, retryResponse)
        }
        return try validate(data, response)
    }

    private func request(_ method: String, _ path: String, _ query: [URLQueryItem], _ body: Data?, token: String) -> URLRequest {
        var components = URLComponents(url: server.apiURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        var request = URLRequest(url: components?.url ?? server.apiURL)
        request.httpMethod = method
        request.setValue("application/vnd.api+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func validate(_ data: Data, _ response: HTTPURLResponse) throws(DataSourceError) -> Data {
        switch response.statusCode {
        case 200..<300:
            let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            // Un proxy o una URL incorrecta suelen devolver HTML con 200.
            if !data.isEmpty, !contentType.contains("json") {
                throw .decoding("respuesta no JSON")
            }
            return data
        case 401: throw .notAuthenticated
        case 403: throw .forbidden
        case 404: throw .notFound
        case 422:
            let error = try? JSONDecoder().decode(ValidationErrorDTO.self, from: data)
            throw .validation(message: error?.message ?? "", fields: error?.errors ?? [:])
        case 429: throw .rateLimited
        case 500...: throw .server(status: response.statusCode)
        default: throw .unknown("HTTP \(response.statusCode)")
        }
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws(DataSourceError) -> Response {
        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response { return empty }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Response.self, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw .decoding("falta \(key.stringValue)")
        } catch let DecodingError.typeMismatch(_, context) {
            throw .decoding("tipo inesperado en \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch {
            throw .decoding("JSON no válido")
        }
    }
}

struct EmptyResponse: Decodable, Sendable {}

struct ValidationErrorDTO: Decodable {
    let message: String?
    let errors: [String: [String]]?
}
