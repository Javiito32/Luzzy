import Foundation
import Observation

/// Preferencias locales no sensibles (UserDefaults). Nunca contienen datos financieros ni del servidor.
@MainActor
@Observable
final class AppSettings {
    enum LockTimeout: Int, CaseIterable, Identifiable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900

        var id: Int { rawValue }
    }

    private let defaults: UserDefaults

    var appLockEnabled: Bool {
        didSet { defaults.set(appLockEnabled, forKey: Keys.appLock) }
    }

    var lockTimeout: LockTimeout {
        didSet { defaults.set(lockTimeout.rawValue, forKey: Keys.lockTimeout) }
    }

    /// Modo discreto: oculta importes en toda la app.
    var amountsHidden: Bool {
        didSet { defaults.set(amountsHidden, forKey: Keys.amountsHidden) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appLockEnabled = defaults.bool(forKey: Keys.appLock)
        lockTimeout = LockTimeout(rawValue: defaults.integer(forKey: Keys.lockTimeout)) ?? .immediately
        amountsHidden = defaults.bool(forKey: Keys.amountsHidden)
    }

    func reset() {
        for key in [Keys.appLock, Keys.lockTimeout, Keys.amountsHidden] {
            defaults.removeObject(forKey: key)
        }
        appLockEnabled = false
        lockTimeout = .immediately
        amountsHidden = false
    }

    private enum Keys {
        static let appLock = "settings.appLock"
        static let lockTimeout = "settings.lockTimeout"
        static let amountsHidden = "settings.amountsHidden"
    }
}
