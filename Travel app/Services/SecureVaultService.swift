import Foundation
import LocalAuthentication

@Observable
final class SecureVaultService {
    static let shared = SecureVaultService()

    private(set) var vault: SecureVault?
    private(set) var isUnlocked = false

    private static let storageKey = "encryptedDocuments"

    private init() {}

    // MARK: - Unlock (Face ID + Decrypt)

    func unlock() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return await unlockWithoutBiometrics()
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Разблокировать хранилище документов"
            )
            guard success else { return false }
            return await MainActor.run { loadVault() }
        } catch {
            return false
        }
    }

    private func unlockWithoutBiometrics() async -> Bool {
        await MainActor.run { loadVault() }
    }

    private func loadVault() -> Bool {
        guard let encryptedData = UserDefaults.standard.data(forKey: Self.storageKey) else {
            vault = SecureVault()
            isUnlocked = true
            return true
        }

        do {
            let decrypted = try CryptoService.decrypt(encryptedData)
            vault = try JSONDecoder().decode(SecureVault.self, from: decrypted)
            isUnlocked = true
            return true
        } catch {
            vault = SecureVault()
            isUnlocked = true
            return true
        }
    }

    // MARK: - Save (Encrypt + Store)

    func save() throws {
        guard let vault else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(vault)
        let encrypted = try CryptoService.encrypt(data)
        UserDefaults.standard.set(encrypted, forKey: Self.storageKey)
    }

    // MARK: - Lock

    func lock() {
        vault = nil
        isUnlocked = false
    }

    // MARK: - Document CRUD

    func addDocument(_ doc: TravelDocument) throws {
        vault?.documents.append(doc)
        try save()
    }

    func removeDocument(id: UUID) throws {
        vault?.documents.removeAll { $0.id == id }
        try save()
    }

    func updateDocument(_ doc: TravelDocument) throws {
        guard let index = vault?.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        vault?.documents[index] = doc
        try save()
    }

    // MARK: - Loyalty CRUD

    func addLoyalty(_ program: LoyaltyProgram) throws {
        vault?.loyaltyPrograms.append(program)
        try save()
    }

    func removeLoyalty(id: UUID) throws {
        vault?.loyaltyPrograms.removeAll { $0.id == id }
        try save()
    }

    // MARK: - Corporate Profile CRUD

    var corporateProfile: CorporateProfile? {
        vault?.corporateProfile
    }

    func saveCorporateProfile(_ profile: CorporateProfile) throws {
        vault?.corporateProfile = profile
        try save()
    }

    // MARK: - Stats

    var documentCount: Int { vault?.documents.count ?? 0 }
    var loyaltyCount: Int { vault?.loyaltyPrograms.count ?? 0 }
}
