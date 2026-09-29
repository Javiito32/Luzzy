import FireflyAPI
import Foundation
import LuzzyCore
import LuzzyPersistence
import LuzzySecurity
import LuzzyStore
import Observation
import SwiftUI

/// Sesión activa: un origen de datos + su caché.
struct Session {
    let profile: ServerProfile?
    let dataSource: any FinanceDataSource
    let cache: (any SnapshotCache)?

    var fetcher: CachedFetcher { CachedFetcher(cache: cache) }
    var isDemo: Bool { dataSource.kind == .demo }
}

/// Raíz de composición: crea los servicios y gestiona sesión, bloqueo y privacidad.
@MainActor
@Observable
final class AppModel {
    enum Phase {
        case launching
        case onboarding
        case ready(Session)
    }

    private(set) var phase: Phase = .launching
    private(set) var isLocked = false
    /// Cubre la interfaz cuando la app no está activa (captura del selector de apps).
    private(set) var isShielded = false

    let settings = AppSettings()
    let purchases = PurchaseManager(configuration: AppConfiguration.store)

    @ObservationIgnored let keychain: KeychainStore
    @ObservationIgnored private let profiles: ServerProfileStore
    @ObservationIgnored private let credentials: FireflyCredentialStore
    @ObservationIgnored private let authenticator = AppLockAuthenticator()
    @ObservationIgnored private var backgroundedAt: Date?

    init() {
        let keychain = KeychainStore(service: AppConfiguration.keychainService)
        self.keychain = keychain
        profiles = ServerProfileStore(keychain: keychain)
        credentials = FireflyCredentialStore(keychain: keychain)
    }

    var session: Session? {
        if case .ready(let session) = phase { return session }
        return nil
    }

    // MARK: Ciclo de vida

    func bootstrap() async {
        guard case .launching = phase else { return }
        purchases.start()
        isLocked = settings.appLockEnabled
        if let profile = profiles.activeProfile(), (try? credentials.credential(for: profile.id)) != nil {
            phase = .ready(await makeSession(for: profile))
        } else {
            phase = .onboarding
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            isShielded = false
            if settings.appLockEnabled, let backgroundedAt,
               Date.now.timeIntervalSince(backgroundedAt) >= TimeInterval(settings.lockTimeout.rawValue) {
                isLocked = true
            }
            backgroundedAt = nil
        case .inactive:
            isShielded = true
        case .background:
            isShielded = true
            backgroundedAt = backgroundedAt ?? .now
            if settings.appLockEnabled, settings.lockTimeout == .immediately { isLocked = true }
        @unknown default:
            isShielded = true
        }
    }

    func unlock() async {
        let reason = String(localized: "Desbloquea Luzzy para ver tus finanzas")
        if await authenticator.authenticate(reason: reason) {
            isLocked = false
        }
    }

    var canUseAppLock: Bool { authenticator.isAvailable }
    var biometryKind: BiometryKind { authenticator.biometryKind }

    // MARK: Conexión

    /// Guarda un perfil ya validado y abre la sesión.
    func activate(profile: ServerProfile, credential: FireflyCredential) async throws {
        try credentials.save(credential, for: profile.id)
        try profiles.save(profile)
        phase = .ready(await makeSession(for: profile))
    }

    func startDemo() {
        phase = .ready(Session(profile: nil, dataSource: DemoDataSource(), cache: nil))
    }

    /// Desconecta el servidor y borra TODO lo local asociado: credenciales, perfil y caché.
    func disconnect() async {
        if let profile = session?.profile {
            await session?.cache?.removeAll()
            ProtectedLocation.wipe(profileID: profile.id)
            try? credentials.remove(for: profile.id)
            try? keychain.remove("cache-key.\(profile.id)")
            try? profiles.remove(profile.id)
        }
        if let next = profiles.activeProfile(), (try? credentials.credential(for: next.id)) != nil {
            phase = .ready(await makeSession(for: next))
        } else {
            phase = .onboarding
        }
    }

    /// Borra la caché local del perfil activo (los datos siguen en el servidor).
    func clearCache() async {
        await session?.cache?.removeAll()
    }

    /// Borrado total: todo lo que Luzzy guarda en este dispositivo.
    func eraseEverything() async {
        await session?.cache?.removeAll()
        ProtectedLocation.wipe()
        try? keychain.removeAll()
        settings.reset()
        isLocked = false
        phase = .onboarding
    }

    private func makeSession(for profile: ServerProfile) async -> Session {
        let server = profile.server
        let transport = URLSessionTransport(server: server)
        let authorizer = KeychainFireflyAuthorizer(store: credentials, profileID: profile.id, server: server, transport: transport)
        let client = FireflyClient(server: server, transport: transport, authorizer: authorizer)
        let cache = try? await EncryptedSnapshotCache.open(profileID: profile.id, keychain: keychain)
        return Session(profile: profile, dataSource: FireflyDataSource(client: client), cache: cache)
    }
}
