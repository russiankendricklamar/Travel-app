import Foundation
import SwiftData

@Model
final class PackingItem: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var isPacked: Bool
    var quantity: Int
    var isAISuggested: Bool
    var sortOrder: Int
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        category: String = PackingCategory.other.rawValue,
        isPacked: Bool = false,
        quantity: Int = 1,
        isAISuggested: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isPacked = isPacked
        self.quantity = quantity
        self.isAISuggested = isAISuggested
        self.sortOrder = sortOrder
    }
}

enum PackingCategory: String, CaseIterable, Codable, Identifiable {
    case documents = "documents"
    case clothing = "clothing"
    case electronics = "electronics"
    case toiletries = "toiletries"
    case medicine = "medicine"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .documents: return String(localized: "Документы")
        case .clothing: return String(localized: "Одежда")
        case .electronics: return String(localized: "Электроника")
        case .toiletries: return String(localized: "Гигиена")
        case .medicine: return String(localized: "Лекарства")
        case .other: return String(localized: "Прочее")
        }
    }

    var systemImage: String {
        switch self {
        case .documents: return "doc.text.fill"
        case .clothing: return "tshirt.fill"
        case .electronics: return "bolt.fill"
        case .toiletries: return "drop.fill"
        case .medicine: return "cross.case.fill"
        case .other: return "archivebox.fill"
        }
    }
}
