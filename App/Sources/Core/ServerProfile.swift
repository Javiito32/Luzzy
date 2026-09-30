import FireflyAPI
import Foundation
import LuzzySecurity

/// Perfil de un servidor Firefly III. Se guarda en el Llavero (no en UserDefaults):
/// la URL del servidor también es un dato personal.
struct ServerProfile: Codable, Identifiable, Hashable, Sendable {
    enum AuthMethod: Codable, Hashable, Sendable {
        case personalAccessToken
        case oauth(clientID: String)
    }

    enum Trust: Codable, Hashable, Sendable {
        case system
        case systemAndPinned(fingerprint: String)
        case pinnedOnly(fingerprint: String)

        var policy: ServerTrustPolicy {
            switch self {
            case .system: .system
            case .systemAndPinned(let fingerprint): .systemAndPinned(CertificateFingerprint(sha256Hex: fingerprint))
            case .pinnedOnly(let fingerprint): .pinnedOnly(CertificateFingerprint(sha256Hex: fingerprint))
            }
        }

        var pinnedFingerprint: CertificateFingerprint? {
            switch self {
            case .system: nil
            case .systemAndPinned(let value), .pinnedOnly(let value): CertificateFingerprint(sha256Hex: value)
            }
        }
    }

    var id: String
    var baseURL: URL
    var authMethod: AuthMethod
    var trust: Trust
    var createdAt: Date
    /// Cuenta elegida para el plan gratuito (ausente en perfiles antiguos → nil).
    var freeAccountID: String?

    var displayName: String { baseURL.host() ?? baseURL.absoluteString }
    var usesUnencryptedHTTP: Bool { baseURL.scheme == "http" }
    var server: FireflyServer { FireflyServer(baseURL: baseURL, trustPolicy: trust.policy) }
}

/// Persistencia de perfiles en el Llavero.
struct ServerProfileStore: Sendable {
    private let keychain: KeychainStore
    private let profilesKey = "profiles"
    private let activeKey = "profiles.active"

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    func profiles() -> [ServerProfile] {
        (try? keychain.value([ServerProfile].self, for: profilesKey)) ?? []
    }

    func activeProfile() -> ServerProfile? {
        let all = profiles()
        guard let data = try? keychain.data(for: activeKey), let id = String(data: data, encoding: .utf8) else {
            return all.first
        }
        return all.first { $0.id == id } ?? all.first
    }

    func save(_ profile: ServerProfile, makeActive: Bool = true) throws {
        var all = profiles().filter { $0.id != profile.id }
        all.append(profile)
        try keychain.setValue(all, for: profilesKey)
        if makeActive { try keychain.set(Data(profile.id.utf8), for: activeKey) }
    }

    func remove(_ profileID: String) throws {
        let remaining = profiles().filter { $0.id != profileID }
        try keychain.setValue(remaining, for: profilesKey)
        if let next = remaining.first {
            try keychain.set(Data(next.id.utf8), for: activeKey)
        } else {
            try keychain.remove(activeKey)
        }
    }
}
