#if canImport(AuthenticationServices) && os(iOS)
import AuthenticationServices
import Foundation
import UIKit

public enum WebAuthenticationError: Error, Sendable, Equatable {
    case cancelled
    case failed
}

/// Abre la página de inicio de sesión del servidor en una sesión web efímera.
///
/// `prefersEphemeralWebBrowserSession = true`: no se comparten cookies con
/// Safari y no queda sesión abierta tras volver a la app.
@MainActor
public final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    override public init() {}

    public func authenticate(url: URL, callbackScheme: String) async throws(WebAuthenticationError) -> URL {
        let result: Result<URL, WebAuthenticationError> = await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                if let callback {
                    continuation.resume(returning: .success(callback))
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(returning: .failure(.cancelled))
                } else {
                    continuation.resume(returning: .failure(.failed))
                }
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                continuation.resume(returning: .failure(.failed))
            }
        }
        session = nil
        return try result.get()
    }

    public nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            return keyWindow ?? ASPresentationAnchor()
        }
    }
}
#endif
