import Foundation
#if canImport(Security)
import Security
#endif

public enum SecureRandom {
    /// Bytes aleatorios criptográficamente seguros.
    public static func bytes(_ count: Int) -> Data {
        var data = Data(count: count)
        #if canImport(Security)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        precondition(status == errSecSuccess, "SecRandomCopyBytes falló")
        #else
        var generator = SystemRandomNumberGenerator()
        for index in 0..<count { data[index] = UInt8.random(in: .min ... .max, using: &generator) }
        #endif
        return data
    }
}

public extension Data {
    /// Base64 URL-safe sin relleno (RFC 4648 §5), usado por PKCE.
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
