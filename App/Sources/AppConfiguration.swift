import Foundation
import LuzzyStore

/// Configuración estática de la app. Todo lo que hay que cambiar para publicar está aquí.
enum AppConfiguration {
    /// Servicio del Llavero, derivado del bundle ID para no colisionar con otras apps.
    static let keychainService = (Bundle.main.bundleIdentifier ?? "app.luzzy") + ".secure"

    /// Productos de App Store Connect. Deben coincidir con `Luzzy.storekit`.
    static let store = StoreConfiguration(
        subscriptionGroupID: "21000001",
        monthlyID: "luzzy.premium.monthly",
        yearlyID: "luzzy.premium.yearly",
        lifetimeID: "luzzy.premium.lifetime"
    )

    // TODO: publicar legal/privacy-policy.md (p. ej. con GitHub Pages) y poner aquí su URL.
    // Apple exige una URL de política de privacidad aunque la app no recoja datos.
    static let privacyPolicyURL = URL(string: "https://example.com/luzzy/privacy")!
    // Se usa el EULA estándar de Apple; no hace falta redactar términos propios.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
