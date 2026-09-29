#if canImport(CryptoKit) && canImport(Security)
import CryptoKit
import Foundation

/// Cifrado autenticado (AES-256-GCM) para los datos guardados en disco.
///
/// Es una capa adicional a la protección de datos de iOS: aunque alguien
/// extrajera la base de datos de la caché, sin la clave del Llavero
/// (ligada a este dispositivo) el contenido es ilegible.
public struct DataCipher: Sendable {
    private let key: SymmetricKey

    public init(key: SymmetricKey) {
        self.key = key
    }

    /// Carga la clave del Llavero o crea una nueva la primera vez.
    public static func deviceBound(keychain: KeychainStore, account: String = "cache-key") throws -> DataCipher {
        if let data = try keychain.data(for: account), data.count == 32 {
            return DataCipher(key: SymmetricKey(data: data))
        }
        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        try keychain.set(raw, for: account)
        return DataCipher(key: key)
    }

    public func seal(_ plaintext: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else { throw CryptoKitError.incorrectParameterSize }
        return combined
    }

    public func open(_ ciphertext: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }
}
#endif
