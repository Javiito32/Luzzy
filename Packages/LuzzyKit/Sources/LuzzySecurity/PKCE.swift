#if canImport(CryptoKit)
import CryptoKit
import Foundation

/// Par verificador/desafío para OAuth 2.0 con PKCE (RFC 7636, método S256).
public struct PKCEChallenge: Sendable, Equatable {
    public let verifier: String
    public let challenge: String
    public let method = "S256"

    public init(verifier: String) {
        self.verifier = verifier
        let digest = SHA256.hash(data: Data(verifier.utf8))
        challenge = Data(digest).base64URLEncodedString
    }

    /// Genera un verificador de 64 caracteres (48 bytes aleatorios).
    public static func generate() -> PKCEChallenge {
        PKCEChallenge(verifier: SecureRandom.bytes(48).base64URLEncodedString)
    }
}

/// Valor `state` anti-CSRF para el flujo OAuth.
public enum OAuthState {
    public static func generate() -> String {
        SecureRandom.bytes(24).base64URLEncodedString
    }
}
#endif
