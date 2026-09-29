import Foundation

/// Funciones de Luzzy Premium. Lo que no aparece aquí es gratuito.
///
/// Gratis: conexión al servidor, inicio, cuentas, movimientos (consultar,
/// buscar, crear y editar movimientos simples), bloqueo con Face ID, modo
/// discreto y toda la protección de privacidad. La privacidad nunca es de pago.
public enum PremiumFeature: String, Sendable, CaseIterable, Identifiable {
    case budgets
    case billsAndPiggyBanks
    case splitTransactions
    case categoriesAndTags
    case rules
    case reports
    case widgets
    case multipleServers
    case iCloudSync

    public var id: String { rawValue }
}
