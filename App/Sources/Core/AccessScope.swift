import LuzzyCore

/// Qué parte de los datos puede usar el usuario según su plan.
///
/// Se aplica en la capa de app, por encima de `FinanceDataSource`, así que
/// rige igual para Firefly III que para el futuro backend de iCloud.
enum AccessScope: Equatable {
    /// Premium: todas las cuentas y funciones.
    case full
    /// Gratis: una sola cuenta de activo. `nil` mientras el usuario no la elija.
    case singleAccount(EntityID?)

    /// Cuenta a la que se limitan las consultas, o `nil` si no hay límite.
    var limitedAccountID: EntityID? {
        if case .singleAccount(let id) = self { return id }
        return nil
    }

    var isLimited: Bool { self != .full }

    var needsAccountSelection: Bool { self == .singleAccount(nil) }
}
