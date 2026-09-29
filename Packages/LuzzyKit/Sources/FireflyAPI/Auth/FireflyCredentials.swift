#if canImport(Security)
import Foundation
import LuzzyCore
import LuzzySecurity

/// Credencial de acceso a un servidor Firefly III.
public enum FireflyCredential: Codable, Sendable, Equatable {
    case personalAccessToken(String)
    case oauth(clientID: String, token: OAuthToken)
}

/// Almacén de credenciales en el Llavero, una entrada por perfil.
public struct FireflyCredentialStore: Sendable {
    private let keychain: KeychainStore

    public init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    public func credential(for profileID: String) throws -> FireflyCredential? {
        try keychain.value(FireflyCredential.self, for: key(profileID))
    }

    public func save(_ credential: FireflyCredential, for profileID: String) throws {
        try keychain.setValue(credential, for: key(profileID))
    }

    public func remove(for profileID: String) throws {
        try keychain.remove(key(profileID))
    }

    private func key(_ profileID: String) -> String { "firefly.credential.\(profileID)" }
}

/// Proveedor de tokens respaldado por el Llavero con renovación OAuth.
///
/// - El token solo vive en memoria mientras la app está en uso.
/// - Las renovaciones concurrentes se agrupan en una única petición.
public actor KeychainFireflyAuthorizer: FireflyAuthorizing {
    private let store: FireflyCredentialStore
    private let profileID: String
    private let server: FireflyServer
    private let transport: any HTTPTransport
    private var cached: FireflyCredential?
    private var refreshTask: Task<OAuthToken, any Error>?

    public init(store: FireflyCredentialStore, profileID: String, server: FireflyServer, transport: any HTTPTransport) {
        self.store = store
        self.profileID = profileID
        self.server = server
        self.transport = transport
    }

    public func accessToken() async throws(DataSourceError) -> String {
        switch try loadCredential() {
        case .personalAccessToken(let token):
            return token
        case .oauth(let clientID, let token):
            guard token.isExpired() else { return token.accessToken }
            return try await refreshed(clientID: clientID, token: token).accessToken
        }
    }

    public func refreshAfterUnauthorized(failedToken: String) async -> Bool {
        guard case .oauth(let clientID, let token)? = try? loadCredential() else { return false }
        if token.accessToken != failedToken { return true } // otra tarea ya lo renovó
        return (try? await refreshed(clientID: clientID, token: token)) != nil
    }

    /// Olvida la copia en memoria (p. ej. al bloquear la app).
    public func purgeMemory() {
        cached = nil
    }

    private func loadCredential() throws(DataSourceError) -> FireflyCredential {
        if let cached { return cached }
        guard let credential = try? store.credential(for: profileID) else { throw .notAuthenticated }
        cached = credential
        return credential
    }

    private func refreshed(clientID: String, token: OAuthToken) async throws(DataSourceError) -> OAuthToken {
        if let refreshTask {
            return try await Self.value(of: refreshTask)
        }
        let client = FireflyOAuthClient(server: server, clientID: clientID, transport: transport)
        let task = Task { try await client.refresh(token) }
        refreshTask = task
        defer { refreshTask = nil }

        let newToken = try await Self.value(of: task)
        let credential = FireflyCredential.oauth(clientID: clientID, token: newToken)
        try? store.save(credential, for: profileID)
        cached = credential
        return newToken
    }

    private static func value(of task: Task<OAuthToken, any Error>) async throws(DataSourceError) -> OAuthToken {
        do {
            return try await task.value
        } catch let error as DataSourceError {
            throw error
        } catch {
            throw .notAuthenticated
        }
    }
}
#endif
