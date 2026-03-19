import Foundation
import MapKit

struct PlaceRecommendation: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let estimatedTime: String
    let address: String
    var latitude: Double
    var longitude: Double
    var localName: String

    private enum CodingKeys: String, CodingKey {
        case name, description, category, address, latitude, longitude
        case estimatedTime = "estimated_time"
        case localName = "local_name"
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: String,
        estimatedTime: String,
        address: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        localName: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.estimatedTime = estimatedTime
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.localName = localName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.category = try container.decode(String.self, forKey: .category)
        self.estimatedTime = try container.decodeIfPresent(String.self, forKey: .estimatedTime) ?? ""
        self.address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        // Handle lat/lon as Double or String (Gemini sometimes returns strings)
        if let lat = try? container.decode(Double.self, forKey: .latitude) {
            self.latitude = lat
        } else if let latStr = try? container.decode(String.self, forKey: .latitude), let lat = Double(latStr) {
            self.latitude = lat
        } else {
            self.latitude = 0
        }
        if let lon = try? container.decode(Double.self, forKey: .longitude) {
            self.longitude = lon
        } else if let lonStr = try? container.decode(String.self, forKey: .longitude), let lon = Double(lonStr) {
            self.longitude = lon
        } else {
            self.longitude = 0
        }
        self.localName = try container.decodeIfPresent(String.self, forKey: .localName) ?? ""
    }

    var isLocationResolved: Bool { latitude != 0 || longitude != 0 }

    var categoryIcon: String {
        switch category.lowercased() {
        case "еда", "ресторан", "кафе":
            return "fork.knife"
        case "культура":
            return "theatermasks"
        case "музей":
            return "building.columns.fill"
        case "галерея":
            return "photo.artframe"
        case "природа":
            return "leaf"
        case "парк":
            return "tree.fill"
        case "сад":
            return "camera.macro"
        case "озеро":
            return "water.waves"
        case "горы":
            return "mountain.2.fill"
        case "шопинг", "магазин", "рынок":
            return "bag"
        case "храм", "церковь", "мечеть":
            return "building.columns"
        case "святилище":
            return "sparkles"
        case "развлечения", "бар", "клуб":
            return "music.note"
        case "дворец":
            return "crown.fill"
        case "архитектура", "памятник", "достопримечательность":
            return "building.2"
        case "мост", "смотровая":
            return "binoculars.fill"
        case "жильё", "отель":
            return "bed.double"
        case "аэропорт":
            return "airplane"
        case "вокзал":
            return "train.side.front.car"
        case "метро":
            return "tram.fill.tunnel"
        case "транспорт":
            return "tram"
        case "спорт":
            return "figure.run"
        case "стадион":
            return "sportscourt.fill"
        default:
            return "mappin"
        }
    }

    /// Convert MKMapItem to PlaceRecommendation for DayPickerSheet
    static func from(mapItem item: MKMapItem) -> PlaceRecommendation {
        let coord = item.placemark.coordinate
        let addr = [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality]
            .compactMap { $0 }
            .joined(separator: ", ")

        let category: String
        if let cats = item.pointOfInterestCategory {
            switch cats {
            case .restaurant, .cafe, .bakery, .brewery, .foodMarket:
                category = "еда"
            case .museum:
                category = "музей"
            case .park, .nationalPark:
                category = "парк"
            case .store:
                category = "шопинг"
            case .hotel:
                category = "жильё"
            case .airport:
                category = "аэропорт"
            case .publicTransport:
                category = "транспорт"
            case .beach:
                category = "природа"
            case .theater:
                category = "культура"
            case .stadium:
                category = "стадион"
            default:
                category = "достопримечательность"
            }
        } else {
            category = "достопримечательность"
        }

        return PlaceRecommendation(
            name: item.name ?? "Без названия",
            description: "",
            category: category,
            estimatedTime: "1ч",
            address: addr,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }

    var placeCategory: PlaceCategory {
        switch category.lowercased() {
        case "еда", "ресторан", "кафе":
            return .food
        case "культура":
            return .culture
        case "музей":
            return .museum
        case "галерея":
            return .gallery
        case "природа":
            return .nature
        case "парк":
            return .park
        case "сад":
            return .garden
        case "озеро":
            return .lake
        case "горы":
            return .mountains
        case "шопинг", "магазин", "рынок":
            return .shopping
        case "храм", "церковь", "мечеть":
            return .temple
        case "святилище":
            return .shrine
        case "жильё", "отель":
            return .accommodation
        case "аэропорт":
            return .airport
        case "вокзал":
            return .station
        case "метро":
            return .metro
        case "транспорт":
            return .transport
        case "дворец":
            return .palace
        case "достопримечательность", "мост", "смотровая":
            return .viewpoint
        case "спорт":
            return .sport
        case "стадион":
            return .stadium
        case "архитектура", "памятник":
            return .culture
        default:
            return .culture
        }
    }
}
