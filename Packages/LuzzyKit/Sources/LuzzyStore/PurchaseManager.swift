#if canImport(StoreKit)
import Foundation
import Observation
import StoreKit

/// Identificadores de producto. Deben coincidir con App Store Connect y `Luzzy.storekit`.
public struct StoreConfiguration: Sendable {
    public var subscriptionGroupID: String
    public var monthlyID: String
    public var yearlyID: String
    public var lifetimeID: String

    public init(subscriptionGroupID: String, monthlyID: String, yearlyID: String, lifetimeID: String) {
        self.subscriptionGroupID = subscriptionGroupID
        self.monthlyID = monthlyID
        self.yearlyID = yearlyID
        self.lifetimeID = lifetimeID
    }

    public var subscriptionIDs: [String] { [monthlyID, yearlyID] }
    public var allIDs: [String] { [monthlyID, yearlyID, lifetimeID] }
}

/// Derecho de uso actual.
public enum Entitlement: Sendable, Equatable {
    case free
    case subscription(productID: String, expiresAt: Date?, willRenew: Bool)
    case lifetime

    public var isPremium: Bool { self != .free }
}

/// Gestión de compras con StoreKit 2, sin servidores propios ni terceros.
///
/// - La verificación de cada transacción se hace en el dispositivo con la
///   firma JWS de Apple (`VerificationResult`); las no verificadas se ignoran.
/// - `Transaction.currentEntitlements` funciona sin conexión: StoreKit lo guarda.
/// - No se envía ningún identificador del usuario a ningún sitio.
@MainActor
@Observable
public final class PurchaseManager {
    public private(set) var entitlement: Entitlement = .free
    public private(set) var products: [Product] = []
    public private(set) var isLoadingProducts = false
    public private(set) var lastError: String?

    public let configuration: StoreConfiguration
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    public init(configuration: StoreConfiguration) {
        self.configuration = configuration
    }

    public var isPremium: Bool { entitlement.isPremium }

    public func isUnlocked(_ feature: PremiumFeature) -> Bool {
        isPremium
    }

    public var lifetimeProduct: Product? {
        products.first { $0.id == configuration.lifetimeID }
    }

    /// Arranca la escucha de transacciones y calcula el derecho actual.
    public func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    public func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: configuration.allIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Compra un producto. Devuelve `true` si la compra se completó y verificó.
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlement()
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = String(describing: error)
            return false
        }
    }

    /// "Restaurar compras": fuerza la sincronización con el App Store.
    public func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = String(describing: error)
        }
        await refreshEntitlement()
    }

    public func refreshEntitlement() async {
        var best: Entitlement = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productID == configuration.lifetimeID {
                best = .lifetime
                break
            }
            if configuration.subscriptionIDs.contains(transaction.productID) {
                if let expiration = transaction.expirationDate, expiration < .now { continue }
                let willRenew = await Self.willRenew(productID: transaction.productID)
                best = .subscription(productID: transaction.productID, expiresAt: transaction.expirationDate, willRenew: willRenew)
            }
        }
        entitlement = best
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    private static func willRenew(productID: String) async -> Bool {
        guard let product = try? await Product.products(for: [productID]).first,
              let statuses = try? await product.subscription?.status
        else { return false }
        for status in statuses {
            if case .verified(let info) = status.renewalInfo, info.willAutoRenew { return true }
        }
        return false
    }
}
#endif
