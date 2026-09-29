import Foundation
import LuzzyCore

extension DataSourceError {
    /// Mensaje para el usuario. Nunca incluye tokens, URLs completas ni datos financieros.
    var userMessage: String {
        switch self {
        case .notAuthenticated:
            String(localized: "La sesión ha caducado o el token no es válido. Vuelve a conectar el servidor.")
        case .forbidden:
            String(localized: "Tu usuario no tiene permiso para esta acción.")
        case .notFound:
            String(localized: "No se ha encontrado. Puede que se haya borrado en el servidor.")
        case .validation(let message, let fields):
            fields.values.flatMap { $0 }.first ?? (message.isEmpty ? String(localized: "El servidor ha rechazado los datos.") : message)
        case .rateLimited:
            String(localized: "Demasiadas peticiones. Espera un momento.")
        case .server:
            String(localized: "El servidor ha tenido un error. Inténtalo más tarde.")
        case .offline:
            String(localized: "No se puede contactar con el servidor. Comprueba la conexión.")
        case .timedOut:
            String(localized: "El servidor tarda demasiado en responder.")
        case .insecureConnection:
            String(localized: "Conexión bloqueada: usa HTTPS o una dirección de tu red local.")
        case .certificateMismatch:
            String(localized: "El certificado del servidor ha cambiado. Por seguridad no se ha enviado nada.")
        case .untrustedCertificate:
            String(localized: "El certificado del servidor no es de confianza.")
        case .decoding:
            String(localized: "La respuesta no parece de un servidor Firefly III compatible.")
        case .unsupported:
            String(localized: "Esta función no está disponible con este servidor.")
        case .cancelled:
            String(localized: "Operación cancelada.")
        case .unknown:
            String(localized: "Ha ocurrido un error inesperado.")
        }
    }
}

extension ServerURLError {
    var userMessage: String {
        switch self {
        case .empty: String(localized: "Escribe la dirección de tu servidor.")
        case .malformed: String(localized: "La dirección no es válida.")
        case .unsupportedScheme: String(localized: "La dirección debe empezar por https://")
        case .insecureScheme: String(localized: "Por seguridad, las conexiones sin cifrar (http) solo se permiten en tu red local.")
        case .embeddedCredentials: String(localized: "No incluyas usuario ni contraseña en la dirección.")
        }
    }
}
