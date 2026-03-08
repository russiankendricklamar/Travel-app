import Foundation
import CryptoKit

enum CryptoError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Ошибка шифрования"
        case .decryptionFailed: return "Ошибка расшифровки"
        case .keyGenerationFailed: return "Ошибка генерации ключа"
        }
    }
}

enum CryptoService {
    private static let keyTag = "com.travelapp.vault.key"

    // MARK: - Key Management

    static func getOrCreateKey() -> SymmetricKey {
        if let existingKeyData = KeychainHelper.read(key: keyTag) {
            return SymmetricKey(data: existingKeyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        _ = KeychainHelper.save(key: keyTag, data: keyData)
        return newKey
    }

    // MARK: - Encrypt

    static func encrypt(_ data: Data) throws -> Data {
        let key = getOrCreateKey()
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch is CryptoError {
            throw CryptoError.encryptionFailed
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    // MARK: - Decrypt

    static func decrypt(_ data: Data) throws -> Data {
        let key = getOrCreateKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}
