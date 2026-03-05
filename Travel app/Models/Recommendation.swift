import Foundation

struct PlaceRecommendation: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let estimatedTime: String
    let latitude: Double
    let longitude: Double

    private enum CodingKeys: String, CodingKey {
        case name, description, category, estimatedTime, latitude, longitude
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: String,
        estimatedTime: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.estimatedTime = estimatedTime
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.category = try container.decode(String.self, forKey: .category)
        self.estimatedTime = try container.decodeIfPresent(String.self, forKey: .estimatedTime) ?? ""
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
    }

    var categoryIcon: String {
        switch category.lowercased() {
        case "еда", "ресторан", "кафе":
            return "fork.knife"
        case "культура", "музей", "галерея":
            return "theatermasks"
        case "природа", "парк", "сад":
            return "leaf"
        case "шопинг", "магазин", "рынок":
            return "bag"
        case "храм", "церковь", "мечеть":
            return "building.columns"
        case "святилище":
            return "sparkles"
        case "развлечения", "бар", "клуб":
            return "music.note"
        case "архитектура", "памятник":
            return "building.2"
        default:
            return "mappin"
        }
    }

    var placeCategory: PlaceCategory {
        switch category.lowercased() {
        case "еда", "ресторан", "кафе":
            return .food
        case "культура", "музей", "галерея":
            return .culture
        case "природа", "парк", "сад":
            return .nature
        case "шопинг", "магазин", "рынок":
            return .shopping
        case "храм", "церковь", "мечеть":
            return .temple
        case "святилище":
            return .shrine
        default:
            return .culture
        }
    }
}
