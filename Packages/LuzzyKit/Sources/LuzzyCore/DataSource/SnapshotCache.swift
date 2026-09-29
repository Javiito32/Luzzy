import Foundation

/// Valor recuperado de la caché junto a su antigüedad.
public struct CachedValue<Value: Sendable>: Sendable {
    public var value: Value
    public var updatedAt: Date

    public init(value: Value, updatedAt: Date) {
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// Caché local de instantáneas (una por perfil de servidor).
///
/// La implementación real (LuzzyPersistence) cifra cada entrada con AES-GCM y
/// guarda la base con protección de datos completa.
public protocol SnapshotCache: Sendable {
    func load<Value: Codable & Sendable>(_ type: Value.Type, key: String) async -> CachedValue<Value>?
    func store<Value: Codable & Sendable>(_ value: Value, key: String) async
    func removeAll() async
}

/// Claves de caché estables. Nunca incluyen datos personales.
public enum CacheKey {
    public static func accounts(_ kind: AccountKind?) -> String { "accounts.\(kind?.rawValue ?? "all")" }
    public static func summary(_ period: DateInterval) -> String { "summary.\(stamp(period))" }
    public static func budgets(_ period: DateInterval) -> String { "budgets.\(stamp(period))" }
    public static func bills(_ period: DateInterval) -> String { "bills.\(stamp(period))" }
    public static func transactions(_ query: TransactionQuery) -> String {
        let period = query.period.map(stamp) ?? "any"
        return "transactions.\(query.filter.rawValue).\(query.accountID ?? "all").\(period).p\(query.page)"
    }
    public static let piggyBanks = "piggyBanks"
    public static let categories = "categories"
    public static let tags = "tags"

    private static func stamp(_ period: DateInterval) -> String {
        "\(Int(period.start.timeIntervalSince1970))-\(Int(period.end.timeIntervalSince1970))"
    }
}

/// Estrategia "muestra lo guardado y actualiza": emite primero la caché
/// (si existe) y después el valor fresco del origen, guardándolo.
public struct CachedFetcher: Sendable {
    public let cache: (any SnapshotCache)?

    public init(cache: (any SnapshotCache)?) {
        self.cache = cache
    }

    public func fetch<Value: Codable & Sendable>(
        key: String,
        cached: @Sendable (CachedValue<Value>) async -> Void,
        remote: @Sendable () async throws -> Value
    ) async throws -> Value {
        if let cache, let hit = await cache.load(Value.self, key: key) {
            await cached(hit)
        }
        let fresh = try await remote()
        await cache?.store(fresh, key: key)
        return fresh
    }
}
