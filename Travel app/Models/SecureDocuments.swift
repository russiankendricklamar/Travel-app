import Foundation

// MARK: - Document Type

enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case passport
    case visa
    case driverLicense
    case insurance
    case corporateCard
    case employeeID
    case powerOfAttorney
    case medicalPolicy
    case tripOrder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .passport:        return String(localized: "Паспорт")
        case .visa:            return String(localized: "Виза")
        case .driverLicense:   return String(localized: "Вод. права")
        case .insurance:       return String(localized: "Страховка")
        case .corporateCard:   return String(localized: "Корп. карта")
        case .employeeID:      return String(localized: "Удостоверение")
        case .powerOfAttorney: return String(localized: "Доверенность")
        case .medicalPolicy:   return String(localized: "Полис ДМС")
        case .tripOrder:       return String(localized: "Приказ")
        }
    }

    var icon: String {
        switch self {
        case .passport:        return "passport"
        case .visa:            return "doc.text"
        case .driverLicense:   return "car.fill"
        case .insurance:       return "cross.case.fill"
        case .corporateCard:   return "creditcard.fill"
        case .employeeID:      return "person.badge.fill"
        case .powerOfAttorney: return "signature"
        case .medicalPolicy:   return "heart.text.clipboard.fill"
        case .tripOrder:       return "doc.badge.gearshape.fill"
        }
    }

    var isCorporate: Bool {
        switch self {
        case .corporateCard, .employeeID, .powerOfAttorney, .medicalPolicy, .tripOrder:
            return true
        default:
            return false
        }
    }

    static var personalCases: [DocumentType] {
        allCases.filter { !$0.isCorporate }
    }

    static var corporateCases: [DocumentType] {
        allCases.filter { $0.isCorporate }
    }
}

// MARK: - Travel Document

struct TravelDocument: Codable, Identifiable {
    var id: UUID
    var type: DocumentType
    var number: String
    var country: String
    var issueDate: Date?
    var expiryDate: Date?
    var notes: String

    init(id: UUID = UUID(), type: DocumentType, number: String, country: String = "", issueDate: Date? = nil, expiryDate: Date? = nil, notes: String = "") {
        self.id = id
        self.type = type
        self.number = number
        self.country = country
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.notes = notes
    }

    var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        return expiry < sixMonths && expiry > Date()
    }

    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }

    var maskedNumber: String {
        guard number.count > 4 else { return number }
        let suffix = String(number.suffix(4))
        let masked = String(repeating: "*", count: number.count - 4)
        return masked + suffix
    }
}

// MARK: - Loyalty Program

struct LoyaltyProgram: Codable, Identifiable {
    var id: UUID
    var company: String
    var programName: String
    var memberNumber: String
    var tier: String

    init(id: UUID = UUID(), company: String, programName: String = "", memberNumber: String, tier: String = "") {
        self.id = id
        self.company = company
        self.programName = programName
        self.memberNumber = memberNumber
        self.tier = tier
    }
}

// MARK: - Secure Vault

struct SecureVault: Codable {
    var documents: [TravelDocument]
    var loyaltyPrograms: [LoyaltyProgram]
    var corporateProfile: CorporateProfile?

    init(documents: [TravelDocument] = [], loyaltyPrograms: [LoyaltyProgram] = [], corporateProfile: CorporateProfile? = nil) {
        self.documents = documents
        self.loyaltyPrograms = loyaltyPrograms
        self.corporateProfile = corporateProfile
    }
}
