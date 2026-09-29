import FireflyAPI
import Foundation
import LuzzyCore
import LuzzySecurity
import Observation

/// Lógica del alta de un servidor: valida la URL, gestiona la confianza TLS
/// y comprueba las credenciales ANTES de guardar nada.
@MainActor
@Observable
final class ConnectServerModel {
    enum Method: Hashable {
        case token
        case oauth
    }

    /// Certificado pendiente de que el usuario confirme su huella.
    struct PendingCertificate: Identifiable {
        let id = UUID()
        let url: URL
        let inspection: CertificateInspection
    }

    var urlText = ""
    var method: Method = .token
    var token = ""
    var clientID = ""
    var pinCertificate = false

    private(set) var isWorking = false
    var errorMessage: String?
    var pendingCertificate: PendingCertificate?

    private var acceptedFingerprint: CertificateFingerprint?

    /// Aviso si la URL usa HTTP en red local.
    var showsLocalHTTPWarning: Bool {
        guard let url = try? ServerURLPolicy.normalize(urlText) else { return false }
        return url.scheme == "http"
    }

    var canSubmit: Bool {
        guard !isWorking, !urlText.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch method {
        case .token: return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .oauth: return !clientID.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    func connect(app: AppModel) async {
        errorMessage = nil
        let baseURL: URL
        do throws(ServerURLError) {
            baseURL = try ServerURLPolicy.normalize(urlText)
        } catch {
            errorMessage = error.userMessage
            return
        }

        isWorking = true
        defer { isWorking = false }

        let trust = await resolveTrust(for: baseURL)
        guard let trust else { return }

        let profile = ServerProfile(
            id: UUID().uuidString,
            baseURL: baseURL,
            authMethod: method == .token ? .personalAccessToken : .oauth(clientID: clientID.trimmingCharacters(in: .whitespaces)),
            trust: trust,
            createdAt: .now
        )

        do {
            let credential = try await obtainCredential(for: profile)
            try await validate(profile: profile, credential: credential)
            try await app.activate(profile: profile, credential: credential)
            token = ""
        } catch let error as DataSourceError {
            errorMessage = error.userMessage
        } catch WebAuthenticationError.cancelled {
            // El usuario cerró la hoja de inicio de sesión: no es un error.
        } catch is OAuthError {
            errorMessage = String(localized: "No se pudo completar el inicio de sesión OAuth.")
        } catch {
            errorMessage = String(localized: "No se ha podido guardar la conexión de forma segura.")
        }
    }

    /// Usuario confirma la huella del certificado autofirmado.
    func trustPendingCertificate(app: AppModel) async {
        guard let pending = pendingCertificate else { return }
        acceptedFingerprint = pending.inspection.fingerprint
        pendingCertificate = nil
        await connect(app: app)
    }

    // MARK: Pasos

    /// Decide la política TLS. Si el certificado no es de confianza, pide confirmación de la huella.
    private func resolveTrust(for url: URL) async -> ServerProfile.Trust? {
        guard url.scheme == "https" else { return .system }
        if let accepted = acceptedFingerprint {
            return .pinnedOnly(fingerprint: accepted.sha256Hex)
        }
        guard let inspection = await CertificateInspector.inspect(url) else {
            errorMessage = DataSourceError.offline.userMessage
            return nil
        }
        if !inspection.isTrustedBySystem {
            pendingCertificate = PendingCertificate(url: url, inspection: inspection)
            return nil
        }
        return pinCertificate ? .systemAndPinned(fingerprint: inspection.fingerprint.sha256Hex) : .system
    }

    private func obtainCredential(for profile: ServerProfile) async throws -> FireflyCredential {
        switch profile.authMethod {
        case .personalAccessToken:
            return .personalAccessToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
        case .oauth(let clientID):
            let transport = URLSessionTransport(server: profile.server)
            let client = FireflyOAuthClient(server: profile.server, clientID: clientID, transport: transport)
            let request = client.makeAuthorizationRequest()
            let callback = try await WebAuthenticator().authenticate(url: request.url, callbackScheme: FireflyOAuthClient.callbackScheme)
            let code = try FireflyOAuthClient.authorizationCode(from: callback, expectedState: request.state)
            let oauthToken = try await client.exchange(code: code, pkce: request.pkce)
            return .oauth(clientID: clientID, token: oauthToken)
        }
    }

    private func validate(profile: ServerProfile, credential: FireflyCredential) async throws {
        let accessToken: String
        switch credential {
        case .personalAccessToken(let token): accessToken = token
        case .oauth(_, let token): accessToken = token.accessToken
        }
        let client = FireflyClient(
            server: profile.server,
            transport: URLSessionTransport(server: profile.server),
            authorizer: StaticTokenAuthorizer(token: accessToken)
        )
        _ = try await FireflyDataSource(client: client).info()
    }
}
