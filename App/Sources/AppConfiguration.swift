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

    // TODO: publicar ambas páginas antes del envío a revisión.
    static let privacyPolicyURL = URL(string: "https://example.com/luzzy/privacy")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
