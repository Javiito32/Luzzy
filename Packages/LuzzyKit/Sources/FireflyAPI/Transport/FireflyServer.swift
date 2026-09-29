import Foundation
import LuzzySecurity

/// Servidor Firefly III al que se conecta la app.
public struct FireflyServer: Sendable, Equatable {
    /// URL raíz ya normalizada con `ServerURLPolicy` (sin `/api/v1`).
    public var baseURL: URL
    public var trustPolicy: ServerTrustPolicy

    public init(baseURL: URL, trustPolicy: ServerTrustPolicy = .system) {
        self.baseURL = baseURL
        self.trustPolicy = trustPolicy
    }

    public var host: String { baseURL.host() ?? "" }
    public var apiURL: URL { baseURL.appending(path: "api/v1") }
}
