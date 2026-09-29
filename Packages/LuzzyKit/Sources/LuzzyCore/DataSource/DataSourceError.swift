import Foundation

/// Errores normalizados de cualquier origen de datos.
///
/// Los mensajes para el usuario se localizan en la app, no aquí: así este módulo
/// no depende de recursos y los textos no filtran detalles internos.
public enum DataSourceError: Error, Sendable, Equatable {
    /// Credenciales ausentes, caducadas o revocadas.
    case notAuthenticated
    case forbidden
    case notFound
    /// Error de validación del servidor (HTTP 422).
    case validation(message: String, fields: [String: [String]])
    case rateLimited
    case server(status: Int)
    case offline
    case timedOut
    /// Conexión rechazada por política de seguridad (HTTP sin cifrar, ATS…).
    case insecureConnection
    /// El certificado del servidor no coincide con el anclado por el usuario.
    case certificateMismatch
    /// Certificado no válido (autofirmado, caducado, nombre incorrecto…).
    case untrustedCertificate
    case decoding(String)
    case unsupported
    case cancelled
    case unknown(String)
}
