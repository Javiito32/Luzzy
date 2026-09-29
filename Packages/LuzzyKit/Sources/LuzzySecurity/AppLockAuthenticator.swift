#if canImport(LocalAuthentication)
import Foundation
import LocalAuthentication

public enum BiometryKind: Sendable {
    case none
    case touchID
    case faceID
    case opticID
}

/// Autenticación local para desbloquear la app (Face ID/Touch ID con código como alternativa).
public struct AppLockAuthenticator: Sendable {
    public init() {}

    public var biometryKind: BiometryKind {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    /// `true` si el dispositivo tiene código o biometría configurados.
    public var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Solicita autenticación. `reason` debe estar localizado por la app.
    public func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = nil
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
#endif
