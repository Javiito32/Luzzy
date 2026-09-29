import Foundation
import LuzzyCore
import LuzzySecurity

/// Capa de transporte HTTP sustituible en tests.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws(DataSourceError) -> (Data, HTTPURLResponse)
}

/// Transporte real sobre `URLSession`, configurado para no dejar rastro:
/// sesión efímera, sin caché HTTP, sin cookies, sin almacén de credenciales,
/// TLS ≥ 1.2 y un User-Agent genérico que no revela el modelo ni la versión de iOS.
public final class URLSessionTransport: HTTPTransport {
    private let session: URLSession
    private let usesPinning: Bool

    public init(server: FireflyServer, timeout: TimeInterval = 30) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = timeout
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.httpAdditionalHeaders = ["User-Agent": "Luzzy"]

        let delegate = ServerTrustDelegate(host: server.host, policy: server.trustPolicy)
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        usesPinning = server.trustPolicy != .system
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    public func send(_ request: URLRequest) async throws(DataSourceError) -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw DataSourceError.unknown("respuesta no HTTP") }
            return (data, http)
        } catch let error as DataSourceError {
            throw error
        } catch let error as URLError {
            throw Self.map(error, usesPinning: usesPinning)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .unknown(String(describing: type(of: error)))
        }
    }

    static func map(_ error: URLError, usesPinning: Bool) -> DataSourceError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .timedOut:
            return .timedOut
        case .appTransportSecurityRequiresSecureConnection:
            return .insecureConnection
        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .secureConnectionFailed, .clientCertificateRejected:
            return .untrustedCertificate
        case .cancelled:
            // Un desafío TLS rechazado por el anclaje llega como cancelación.
            return Task.isCancelled ? .cancelled : (usesPinning ? .certificateMismatch : .cancelled)
        default:
            return .unknown("URLError \(error.code.rawValue)")
        }
    }
}
