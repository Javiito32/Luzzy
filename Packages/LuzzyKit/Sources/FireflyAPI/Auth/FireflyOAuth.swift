import Foundation
import LuzzyCore
import LuzzySecurity

/// Token OAuth guardado en el Llavero.
public struct OAuthToken: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date

    public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// Se considera caducado un minuto antes para evitar carreras.
    public func isExpired(at date: Date = .now) -> Bool {
        date.addingTimeInterval(60) >= expiresAt
    }
}

public enum OAuthError: Error, Sendable, Equatable {
    case stateMismatch
    case missingCode
    case accessDenied
    case invalidResponse
}

/// Flujo OAuth 2.0 "authorization code" con PKCE contra Firefly III (Laravel Passport).
///
/// El cliente OAuth debe crearse en Firefly como NO confidencial: la app nunca
/// almacena un client secret, solo el client ID (que no es secreto).
public struct FireflyOAuthClient: Sendable {
    public static let callbackScheme = "luzzy"
    public static let redirectURI = "luzzy://oauth/callback"

    public let server: FireflyServer
    public let clientID: String
    private let transport: any HTTPTransport

    public init(server: FireflyServer, clientID: String, transport: any HTTPTransport) {
        self.server = server
        self.clientID = clientID
        self.transport = transport
    }

    public struct AuthorizationRequest: Sendable {
        public let url: URL
        public let pkce: PKCEChallenge
        public let state: String
    }

    public func makeAuthorizationRequest() -> AuthorizationRequest {
        let pkce = PKCEChallenge.generate()
        let state = OAuthState.generate()
        var components = URLComponents(url: server.baseURL.appending(path: "oauth/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: ""),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method),
        ]
        return AuthorizationRequest(url: components?.url ?? server.baseURL, pkce: pkce, state: state)
    }

    /// Extrae el código de la URL de retorno validando `state`.
    public static func authorizationCode(from callback: URL, expectedState: String) throws(OAuthError) -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if value("error") != nil { throw .accessDenied }
        guard value("state") == expectedState else { throw .stateMismatch }
        guard let code = value("code"), !code.isEmpty else { throw .missingCode }
        return code
    }

    public func exchange(code: String, pkce: PKCEChallenge) async throws -> OAuthToken {
        try await tokenRequest([
            "grant_type": "authorization_code",
            "client_id": clientID,
            "redirect_uri": Self.redirectURI,
            "code_verifier": pkce.verifier,
            "code": code,
        ], previousRefreshToken: nil)
    }

    public func refresh(_ token: OAuthToken) async throws -> OAuthToken {
        guard let refreshToken = token.refreshToken else { throw DataSourceError.notAuthenticated }
        return try await tokenRequest([
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken,
            "scope": "",
        ], previousRefreshToken: refreshToken)
    }

    private func tokenRequest(_ form: [String: String], previousRefreshToken: String?) async throws -> OAuthToken {
        var request = URLRequest(url: server.baseURL.appending(path: "oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Self.formEncode(form)

        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300: break
        case 400, 401: throw DataSourceError.notAuthenticated
        default: throw DataSourceError.server(status: response.statusCode)
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw OAuthError.invalidResponse
        }
        return OAuthToken(
            accessToken: token.access_token,
            refreshToken: token.refresh_token ?? previousRefreshToken,
            expiresAt: Date.now.addingTimeInterval(token.expires_in ?? 3600)
        )
    }

    static func formEncode(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = form
            .sorted { $0.key < $1.key }
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}
