#if canImport(Security) && canImport(CryptoKit)
import CryptoKit
import Foundation
import Security

/// Huella SHA-256 del certificado hoja de un servidor.
public struct CertificateFingerprint: Hashable, Sendable, Codable {
    public let sha256Hex: String

    public init(sha256Hex: String) {
        self.sha256Hex = sha256Hex.lowercased().replacingOccurrences(of: ":", with: "")
    }

    public init(certificate: SecCertificate) {
        let der = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: der)
        sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Formato legible "AB:CD:…" para mostrar al usuario.
    public var formatted: String {
        stride(from: 0, to: sha256Hex.count, by: 2).map { offset in
            let start = sha256Hex.index(sha256Hex.startIndex, offsetBy: offset)
            let end = sha256Hex.index(start, offsetBy: 2)
            return sha256Hex[start..<end].uppercased()
        }.joined(separator: ":")
    }
}

/// Política de confianza TLS para el servidor del usuario.
public enum ServerTrustPolicy: Sendable, Equatable {
    /// Validación estándar del sistema (recomendado con certificados públicos).
    case system
    /// Validación del sistema Y además el certificado debe coincidir con la huella anclada.
    case systemAndPinned(CertificateFingerprint)
    /// Solo la huella anclada (servidores autofirmados aceptados expresamente por el usuario).
    case pinnedOnly(CertificateFingerprint)
}

/// Delegado de URLSession que aplica `ServerTrustPolicy` al host configurado.
public final class ServerTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    public let host: String
    public let policy: ServerTrustPolicy

    public init(host: String, policy: ServerTrustPolicy) {
        self.host = host.lowercased()
        self.policy = policy
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }
        // Nunca se aplica una política relajada a otros hosts.
        guard challenge.protectionSpace.host.lowercased() == host else {
            return (.performDefaultHandling, nil)
        }
        return Self.evaluate(trust: trust, policy: policy)
            ? (.useCredential, URLCredential(trust: trust))
            : (.cancelAuthenticationChallenge, nil)
    }

    static func evaluate(trust: SecTrust, policy: ServerTrustPolicy) -> Bool {
        let systemValid = SecTrustEvaluateWithError(trust, nil)
        let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        let fingerprint = leaf.map(CertificateFingerprint.init(certificate:))
        switch policy {
        case .system:
            return systemValid
        case .systemAndPinned(let pinned):
            return systemValid && fingerprint == pinned
        case .pinnedOnly(let pinned):
            return fingerprint == pinned
        }
    }
}

/// Resultado de inspeccionar el certificado de un servidor antes de confiar en él.
public struct CertificateInspection: Sendable, Equatable {
    public let fingerprint: CertificateFingerprint
    public let subjectSummary: String?
    public let isTrustedBySystem: Bool
}

/// Obtiene el certificado del servidor sin enviar credenciales,
/// para que el usuario pueda verificar la huella (TOFU) si es autofirmado.
public final class CertificateInspector: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var inspection: CertificateInspection?

    public static func inspect(_ url: URL) async -> CertificateInspection? {
        let inspector = CertificateInspector()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration, delegate: inspector, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        _ = try? await session.data(for: request)
        return inspector.result
    }

    private var result: CertificateInspection? {
        lock.withLock { inspection }
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let trust = challenge.protectionSpace.serverTrust,
              let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        else { return (.cancelAuthenticationChallenge, nil) }

        let captured = CertificateInspection(
            fingerprint: CertificateFingerprint(certificate: leaf),
            subjectSummary: SecCertificateCopySubjectSummary(leaf) as String?,
            isTrustedBySystem: SecTrustEvaluateWithError(trust, nil)
        )
        lock.withLock { inspection = captured }
        // Solo inspeccionamos: nunca continuamos la conexión.
        return (.cancelAuthenticationChallenge, nil)
    }
}
#endif
