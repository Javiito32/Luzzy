import Foundation

public enum ServerURLError: Error, Sendable, Equatable {
    case empty
    case malformed
    case unsupportedScheme
    /// HTTP sin cifrar hacia un host público.
    case insecureScheme
    /// La URL incluye usuario/contraseña embebidos.
    case embeddedCredentials
}

/// Normaliza y valida la URL del servidor antes de conectar.
///
/// Política: HTTPS obligatorio. HTTP solo se permite hacia la red local
/// (localhost, nombres sin dominio, `.local` o IP privadas), que es lo que
/// App Transport Security permite con `NSAllowsLocalNetworking`.
public enum ServerURLPolicy {
    public static func normalize(_ input: String) throws(ServerURLError) -> URL {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw .empty }
        if !text.contains("://") {
            text = "https://" + text
        }
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty
        else { throw .malformed }

        guard scheme == "https" || scheme == "http" else { throw .unsupportedScheme }
        guard components.user == nil, components.password == nil else { throw .embeddedCredentials }
        if scheme == "http", !isLocalNetworkHost(host) { throw .insecureScheme }

        components.scheme = scheme
        // Las IPv6 se dejan tal cual para no perder los corchetes.
        if !host.contains(":") { components.host = host }
        components.query = nil
        components.fragment = nil

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        for suffix in ["/api/v1", "/api"] where path.lowercased().hasSuffix(suffix) {
            path.removeLast(suffix.count)
            break
        }
        components.path = path

        guard let url = components.url else { throw .malformed }
        return url
    }

    /// `true` si el host pertenece a la red local según los criterios de ATS.
    public static func isLocalNetworkHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host.hasSuffix(".local") { return true }
        if let octets = ipv4Octets(host) { return isPrivateIPv4(octets) }
        if host.contains(":") { return isPrivateIPv6(host) }
        // Nombre sin dominio (p. ej. "nas").
        return !host.contains(".")
    }

    private static func ipv4Octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return nil }
        return octets
    }

    private static func isPrivateIPv4(_ o: [Int]) -> Bool {
        switch (o[0], o[1]) {
        case (10, _), (127, _): true
        case (172, 16...31): true
        case (192, 168): true
        case (169, 254): true
        case (100, 64...127): true // CGNAT (p. ej. Tailscale)
        default: false
        }
    }

    private static func isPrivateIPv6(_ host: String) -> Bool {
        if host == "::1" { return true }
        let first = host.split(separator: ":").first.map(String.init)?.lowercased() ?? ""
        guard let value = Int(first, radix: 16) else { return false }
        let isUniqueLocal = (value & 0xFE00) == 0xFC00 // fc00::/7
        let isLinkLocal = (value & 0xFFC0) == 0xFE80 // fe80::/10
        return isUniqueLocal || isLinkLocal
    }
}
