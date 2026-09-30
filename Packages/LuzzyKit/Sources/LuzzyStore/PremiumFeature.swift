import Foundation

/// Funciones de Luzzy Premium.
///
/// Plan gratuito (igual con Firefly III que con el futuro modo iCloud):
/// UNA cuenta de activo elegida por el usuario, con sus gastos e ingresos
/// (consultar, buscar, crear y borrar). Sin transferencias, sin
/// planificación y sin automatismos.
///
/// La privacidad nunca es de pago: bloqueo, modo discreto y cifrado local
/// están en ambos planes.
public enum PremiumFeature: String, Sendable, CaseIterable, Identifiable {
    case multipleAccounts
    case transfers
    case budgets
    case billsAndPiggyBanks
    case splitTransactions
    case categoriesAndTags
    case rules
    case recurringTransactions
    case reports
    case widgets
    case multipleServers

    public var id: String { rawValue }
}
