#if canImport(SwiftData) && canImport(CryptoKit)
import Foundation
import LuzzyCore
import LuzzySecurity
import SwiftData

/// Entrada de la caché. `payload` siempre va cifrado con AES-GCM.
@Model
final class CachedSnapshot {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date

    init(key: String, payload: Data, updatedAt: Date) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

/// Caché local cifrada para un perfil de servidor.
///
/// Capas de protección:
/// 1. Fichero con `FileProtectionType.complete` (ilegible con el iPhone bloqueado).
/// 2. Excluido de las copias de seguridad de iCloud/Finder.
/// 3. Cada entrada cifrada con AES-256-GCM con una clave del Llavero ligada al dispositivo.
/// 4. Borrado total al desconectar el servidor o desde Ajustes › Privacidad.
@ModelActor
public actor EncryptedSnapshotCache: SnapshotCache {
    private var cipher: DataCipher?

    public static func open(profileID: String, keychain: KeychainStore) async throws -> EncryptedSnapshotCache {
        let directory = try ProtectedLocation.directory(for: profileID)
        let configuration = ModelConfiguration(
            "LuzzyCache",
            schema: Schema([CachedSnapshot.self]),
            url: directory.appending(path: "cache.store"),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: CachedSnapshot.self, configurations: configuration)
        let cache = EncryptedSnapshotCache(modelContainer: container)
        let cipher = try DataCipher.deviceBound(keychain: keychain, account: "cache-key.\(profileID)")
        await cache.setCipher(cipher)
        return cache
    }

    private func setCipher(_ cipher: DataCipher) {
        self.cipher = cipher
    }

    public func load<Value: Codable & Sendable>(_ type: Value.Type, key: String) async -> CachedValue<Value>? {
        guard let cipher else { return nil }
        var descriptor = FetchDescriptor<CachedSnapshot>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        guard let entry = try? modelContext.fetch(descriptor).first,
              let plaintext = try? cipher.open(entry.payload),
              let value = try? JSONDecoder().decode(Value.self, from: plaintext)
        else { return nil }
        return CachedValue(value: value, updatedAt: entry.updatedAt)
    }

    public func store<Value: Codable & Sendable>(_ value: Value, key: String) async {
        guard let cipher,
              let plaintext = try? JSONEncoder().encode(value),
              let payload = try? cipher.seal(plaintext)
        else { return }
        var descriptor = FetchDescriptor<CachedSnapshot>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.payload = payload
            existing.updatedAt = .now
        } else {
            modelContext.insert(CachedSnapshot(key: key, payload: payload, updatedAt: .now))
        }
        try? modelContext.save()
    }

    public func removeAll() async {
        try? modelContext.delete(model: CachedSnapshot.self)
        try? modelContext.save()
    }
}

/// Ubicación de la caché con protección de datos completa y fuera de las copias.
public enum ProtectedLocation {
    static func root() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appending(path: "LuzzyCache", directoryHint: .isDirectory)
    }

    static func directory(for profileID: String) throws -> URL {
        let safeID = profileID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        var url = try root().appending(path: safeID, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return url
    }

    /// Elimina físicamente la caché de un perfil (o de todos si `profileID` es nil).
    public static func wipe(profileID: String? = nil) {
        guard let root = try? root() else { return }
        let target = profileID.map { root.appending(path: $0.filter { $0.isLetter || $0.isNumber || $0 == "-" }) } ?? root
        try? FileManager.default.removeItem(at: target)
    }
}
#endif
