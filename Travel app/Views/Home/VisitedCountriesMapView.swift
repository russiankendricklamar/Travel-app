import SwiftUI
import UIKit
import MapKit

// MARK: - Country Name Mapping (Russian → ISO Alpha-2)

private enum CountryNameMapping {
    static func isoCode(for russian: String) -> String? {
        let key = russian.lowercased().trimmingCharacters(in: .whitespaces)
        return mapping[key]
    }

    private static let mapping: [String: String] = [
        // CIS & Former Soviet
        "россия": "RU", "украина": "UA", "беларусь": "BY",
        "казахстан": "KZ", "грузия": "GE", "армения": "AM",
        "азербайджан": "AZ", "узбекистан": "UZ", "кыргызстан": "KG",
        "таджикистан": "TJ", "туркменистан": "TM", "молдова": "MD",
        "эстония": "EE", "латвия": "LV", "литва": "LT",
        "абхазия": "GE", "южная осетия": "GE",

        // Europe — Western
        "франция": "FR", "германия": "DE", "италия": "IT",
        "испания": "ES", "португалия": "PT", "великобритания": "GB",
        "нидерланды": "NL", "голландия": "NL", "бельгия": "BE",
        "швейцария": "CH", "австрия": "AT", "люксембург": "LU",
        "монако": "MC", "лихтенштейн": "LI", "андорра": "AD",
        "сан-марино": "SM", "ирландия": "IE", "англия": "GB",
        "шотландия": "GB", "уэльс": "GB",

        // Europe — Nordic
        "швеция": "SE", "норвегия": "NO", "финляндия": "FI",
        "дания": "DK", "исландия": "IS",

        // Europe — Central & Eastern
        "чехия": "CZ", "польша": "PL", "венгрия": "HU",
        "словакия": "SK", "словения": "SI", "румыния": "RO",
        "болгария": "BG", "хорватия": "HR", "сербия": "RS",
        "черногория": "ME", "босния и герцеговина": "BA",
        "северная македония": "MK", "македония": "MK",
        "албания": "AL", "косово": "XK",

        // Europe — Mediterranean
        "греция": "GR", "кипр": "CY", "мальта": "MT",
        "турция": "TR",

        // Middle East
        "оаэ": "AE", "эмираты": "AE",
        "объединённые арабские эмираты": "AE",
        "объединенные арабские эмираты": "AE",
        "израиль": "IL", "иордания": "JO", "ливан": "LB",
        "саудовская аравия": "SA", "катар": "QA",
        "бахрейн": "BH", "оман": "OM", "кувейт": "KW",
        "иран": "IR", "ирак": "IQ", "сирия": "SY",
        "палестина": "PS", "йемен": "YE",

        // Asia — East
        "япония": "JP", "китай": "CN",
        "южная корея": "KR", "корея": "KR",
        "северная корея": "KP", "тайвань": "TW",
        "монголия": "MN", "гонконг": "HK", "макао": "MO",

        // Asia — Southeast
        "таиланд": "TH", "тайланд": "TH",
        "вьетнам": "VN", "индонезия": "ID", "малайзия": "MY",
        "сингапур": "SG", "филиппины": "PH", "камбоджа": "KH",
        "лаос": "LA", "мьянма": "MM", "бирма": "MM",
        "бруней": "BN", "восточный тимор": "TL",

        // Asia — South
        "индия": "IN", "шри-ланка": "LK", "цейлон": "LK",
        "непал": "NP", "бангладеш": "BD", "пакистан": "PK",
        "афганистан": "AF", "мальдивы": "MV", "бутан": "BT",

        // Africa — North
        "египет": "EG", "марокко": "MA", "тунис": "TN",
        "алжир": "DZ", "ливия": "LY",

        // Africa — Sub-Saharan
        "юар": "ZA", "южная африка": "ZA",
        "кения": "KE", "танзания": "TZ", "эфиопия": "ET",
        "нигерия": "NG", "гана": "GH", "мадагаскар": "MG",
        "маврикий": "MU", "сейшелы": "SC", "мозамбик": "MZ",
        "намибия": "NA", "ботсвана": "BW", "зимбабве": "ZW",
        "уганда": "UG", "руанда": "RW", "камерун": "CM",
        "сенегал": "SN", "кот-д'ивуар": "CI",
        "демократическая республика конго": "CD", "конго": "CG",

        // Americas — North
        "сша": "US", "америка": "US", "штаты": "US",
        "канада": "CA", "мексика": "MX",

        // Americas — Central & Caribbean
        "куба": "CU", "доминиканская республика": "DO",
        "панама": "PA", "коста-рика": "CR", "ямайка": "JM",
        "гватемала": "GT", "гондурас": "HN",
        "сальвадор": "SV", "никарагуа": "NI",
        "пуэрто-рико": "PR", "багамы": "BS",
        "тринидад и тобаго": "TT", "барбадос": "BB",

        // Americas — South
        "бразилия": "BR", "аргентина": "AR", "чили": "CL",
        "колумбия": "CO", "перу": "PE", "венесуэла": "VE",
        "эквадор": "EC", "боливия": "BO", "уругвай": "UY",
        "парагвай": "PY", "суринам": "SR", "гайана": "GY",

        // Oceania
        "австралия": "AU", "новая зеландия": "NZ",
        "фиджи": "FJ", "папуа — новая гвинея": "PG",
        "папуа-новая гвинея": "PG",
    ]
}

// MARK: - GeoJSON Cache

private actor GeoJSONCache {
    static let shared = GeoJSONCache()

    private var cachedData: Data?

    private var cacheFileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ne_110m_countries.geojson")
    }

    private let sourceURL = URL(
        string: "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
    )!

    func loadData() async -> Data? {
        if let data = cachedData { return data }

        if let data = try? Data(contentsOf: cacheFileURL) {
            cachedData = data
            return data
        }

        guard let (data, response) = try? await URLSession.shared.data(from: sourceURL),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }

        try? data.write(to: cacheFileURL)
        cachedData = data
        return data
    }
}

// MARK: - Country Color Palette

private enum CountryColors {
    static let palette: [UIColor] = [
        UIColor(red: 0.09, green: 0.64, blue: 0.29, alpha: 1), // bambooGreen
        UIColor(red: 0.85, green: 0.12, blue: 0.30, alpha: 1), // rose
        UIColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 1), // templeGold
        UIColor(red: 0.71, green: 0.18, blue: 0.02, alpha: 1), // amber
        UIColor(red: 0.74, green: 0.23, blue: 0.37, alpha: 1), // roseMuseum
        UIColor(red: 0.93, green: 0.29, blue: 0.60, alpha: 1), // pinkGallery
        UIColor(red: 0.40, green: 0.64, blue: 0.05, alpha: 1), // limeGarden
        UIColor(red: 0.92, green: 0.35, blue: 0.05, alpha: 1), // orangeStadium
        UIColor(red: 0.30, green: 0.49, blue: 0.05, alpha: 1), // olive
        UIColor(red: 0.60, green: 0.35, blue: 0.14, alpha: 1), // copper
        UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1), // redSport
        UIColor(red: 0.88, green: 0.11, blue: 0.28, alpha: 1), // toriiRed
    ]
}

// MARK: - Route Colors

private enum RouteColors {
    static let flight = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 0.8)
    static let train = UIColor(red: 0.93, green: 0.29, blue: 0.60, alpha: 0.8)
    static let bus = UIColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 0.8)
    static let airport = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1.0)
}

// MARK: - Airport Annotation

final class AirportPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let iata: String

    init(iata: String, coordinate: CLLocationCoordinate2D) {
        self.iata = iata
        self.coordinate = coordinate
        self.title = iata
    }
}

// MARK: - City Annotation

final class CityPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.title = name
        self.coordinate = coordinate
    }
}

// MARK: - Route Filter

enum StatsRouteFilter: String, CaseIterable {
    case all = "Все"
    case flights = "Перелёты"
    case trains = "Поезда"
    case buses = "Автобусы"
}

// MARK: - Combined Stats Map View

struct VisitedCountriesMapView: View {
    let trips: [Trip]
    let visitedCountries: [String]

    @State private var countryPolygons: [MKPolygon] = []
    @State private var colorMap: [String: UIColor] = [:]
    @State private var isLoading = true
    @State private var showFullMap = false

    var body: some View {
        ZStack {
            CombinedMapRepresentable(
                countryPolygons: countryPolygons,
                flightOverlays: flightOverlays,
                trainOverlays: trainOverlays,
                busOverlays: busOverlays,
                airports: airportPins,
                cities: cityPins,
                colorMap: colorMap,
                showFlights: true,
                showTrains: true,
                showBuses: true,
                isInteractive: false
            )

            if isLoading {
                ProgressView()
                    .tint(AppTheme.bambooGreen)
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .onTapGesture { showFullMap = true }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(8)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .fullScreenCover(isPresented: $showFullMap) {
            FullStatsMapView(
                countryPolygons: countryPolygons,
                flightOverlays: flightOverlays,
                trainOverlays: trainOverlays,
                busOverlays: busOverlays,
                airports: airportPins,
                cities: cityPins,
                colorMap: colorMap
            )
        }
        .task {
            await loadGeoData()
        }
    }

    // MARK: - Route Computation

    private var flightOverlays: [MKPolyline] {
        var lines: [MKPolyline] = []
        var seen = Set<String>()
        for trip in trips {
            for flight in trip.flights {
                let dep = flight.departureIata ?? ""
                let arr = flight.arrivalIata ?? ""
                guard let depCoord = FlightData.coordinate(forIata: dep),
                      let arrCoord = FlightData.coordinate(forIata: arr) else { continue }
                let key = [dep, arr].sorted().joined(separator: "-")
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                let arc = flightArcPoints(from: depCoord, to: arrCoord)
                let line = MKPolyline(coordinates: arc, count: arc.count)
                line.title = "flight"
                lines.append(line)
            }
        }
        return lines
    }

    private var trainOverlays: [MKPolyline] {
        transportOverlays(for: .train, title: "train") + transportOverlays(for: .shinkansen, title: "train")
    }

    private var busOverlays: [MKPolyline] {
        transportOverlays(for: .bus, title: "bus")
    }

    private func transportOverlays(for category: EventCategory, title: String) -> [MKPolyline] {
        var lines: [MKPolyline] = []
        for trip in trips {
            for day in trip.days {
                for event in day.events where event.category == category {
                    guard let start = event.primaryCoordinate,
                          let end = event.arrivalCoordinate else { continue }
                    var coords = [start, end]
                    let line = MKPolyline(coordinates: &coords, count: 2)
                    line.title = title
                    lines.append(line)
                }
            }
        }
        return lines
    }

    private var airportPins: [AirportPin] {
        var seen = Set<String>()
        var pins: [AirportPin] = []
        for trip in trips {
            for flight in trip.flights {
                for iata in [flight.departureIata, flight.arrivalIata].compactMap({ $0 }) where !iata.isEmpty {
                    guard !seen.contains(iata),
                          let coord = FlightData.coordinate(forIata: iata) else { continue }
                    seen.insert(iata)
                    pins.append(AirportPin(iata: iata, coordinate: coord))
                }
            }
        }
        return pins
    }

    // MARK: - City Computation

    private var cityPins: [CityPin] {
        var cityCoords: [String: [CLLocationCoordinate2D]] = [:]

        // Cities from trips
        for trip in trips {
            for day in trip.days {
                let city = day.cityName
                guard !city.isEmpty else { continue }
                for place in day.places where !place.isDeleted {
                    cityCoords[city, default: []].append(place.coordinate)
                }
            }
        }

        var pins = cityCoords.compactMap { city, coords -> CityPin? in
            guard !coords.isEmpty else { return nil }
            let avgLat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
            let avgLon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
            return CityPin(name: city, coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon))
        }

        // Cities from profile
        let existingNames = Set(pins.map { ($0.title ?? "").lowercased() })
        let profileCities = ProfileService.shared.profile?.visitedCities ?? []
        for city in profileCities {
            guard !existingNames.contains(city.name.lowercased()) else { continue }
            pins.append(CityPin(name: city.name, coordinate: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)))
        }

        return pins
    }

    // MARK: - Flight Arc

    private func flightArcPoints(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        segments: Int = 60
    ) -> [CLLocationCoordinate2D] {
        let dLat = end.latitude - start.latitude
        let dLon = end.longitude - start.longitude
        let dist = sqrt(dLat * dLat + dLon * dLon)
        guard dist > 0 else { return [start, end] }

        let midLat = (start.latitude + end.latitude) / 2
        let midLon = (start.longitude + end.longitude) / 2
        let perpLat = -dLon / dist
        let perpLon = dLat / dist
        let sign: Double = perpLat >= 0 ? 1 : -1
        let height = dist * 0.15
        let ctrlLat = midLat + sign * perpLat * height
        let ctrlLon = midLon + sign * perpLon * height

        return (0...segments).map { i in
            let t = Double(i) / Double(segments)
            let lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * ctrlLat + t * t * end.latitude
            let lon = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * ctrlLon + t * t * end.longitude
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - GeoJSON Loading

    private func loadGeoData() async {
        let isoMap: [String: String] = {
            var map: [String: String] = [:]
            for name in visitedCountries {
                if let iso = CountryNameMapping.isoCode(for: name) {
                    map[iso] = name
                }
            }
            return map
        }()

        guard !isoMap.isEmpty else {
            isLoading = false
            return
        }

        guard let data = await GeoJSONCache.shared.loadData() else {
            isLoading = false
            return
        }

        let decoder = MKGeoJSONDecoder()
        guard let features = try? decoder.decode(data) as? [MKGeoJSONFeature] else {
            isLoading = false
            return
        }

        // Assign colors to ISOs in order
        let orderedISOs = isoMap.keys.sorted()
        var newColorMap: [String: UIColor] = [:]
        for (index, iso) in orderedISOs.enumerated() {
            let uiColor = CountryColors.palette[index % CountryColors.palette.count]
            newColorMap[iso] = uiColor
        }

        // Extract polygons for matched countries
        var polys: [MKPolygon] = []
        for feature in features {
            guard let propsData = feature.properties,
                  let props = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any] else { continue }

            let iso2 = props["ISO_A2"] as? String ?? ""
            guard isoMap[iso2] != nil else { continue }

            for geo in feature.geometry {
                if let polygon = geo as? MKPolygon {
                    polygon.title = iso2
                    polys.append(polygon)
                } else if let multi = geo as? MKMultiPolygon {
                    for p in multi.polygons {
                        p.title = iso2
                        polys.append(p)
                    }
                }
            }
        }

        await MainActor.run {
            countryPolygons = polys
            colorMap = newColorMap
            isLoading = false
        }
    }
}

// MARK: - Combined MKMapView Representable

private struct CombinedMapRepresentable: UIViewRepresentable {
    let countryPolygons: [MKPolygon]
    let flightOverlays: [MKPolyline]
    let trainOverlays: [MKPolyline]
    let busOverlays: [MKPolyline]
    let airports: [AirportPin]
    let cities: [CityPin]
    let colorMap: [String: UIColor]
    let showFlights: Bool
    let showTrains: Bool
    let showBuses: Bool
    let isInteractive: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .mutedStandard
        map.isScrollEnabled = isInteractive
        map.isZoomEnabled = isInteractive
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        applyOverlays(to: map, context: context)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.colorMap = colorMap
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { $0 is AirportPin || $0 is CityPin })
        applyOverlays(to: map, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(colorMap: colorMap)
    }

    private func applyOverlays(to map: MKMapView, context: Context) {
        // Countries below routes
        map.addOverlays(countryPolygons, level: .aboveRoads)

        // Routes above countries
        if showFlights {
            map.addOverlays(flightOverlays, level: .aboveLabels)
            map.addAnnotations(airports)
        }
        if showTrains {
            map.addOverlays(trainOverlays, level: .aboveLabels)
        }
        if showBuses {
            map.addOverlays(busOverlays, level: .aboveLabels)
        }

        // Cities
        map.addAnnotations(cities)

        // Fit region
        if !isInteractive {
            fitToAllOverlays(map)
        } else if !context.coordinator.didFitRegion && !map.overlays.isEmpty {
            fitToAllOverlays(map)
            context.coordinator.didFitRegion = true
        }
    }

    private func fitToAllOverlays(_ map: MKMapView) {
        var rect = MKMapRect.null
        for overlay in map.overlays {
            rect = rect.union(overlay.boundingMapRect)
        }
        for pin in airports {
            let point = MKMapPoint(pin.coordinate)
            let pinRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            rect = rect.union(pinRect)
        }
        for pin in cities {
            let point = MKMapPoint(pin.coordinate)
            let pinRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            rect = rect.union(pinRect)
        }
        guard !rect.isNull else { return }
        let insets = UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)
        map.setVisibleMapRect(rect, edgePadding: insets, animated: false)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var colorMap: [String: UIColor]
        var didFitRegion = false

        init(colorMap: [String: UIColor]) {
            self.colorMap = colorMap
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let iso = polygon.title ?? ""
                let baseColor = colorMap[iso] ?? .systemGray
                renderer.fillColor = baseColor.withAlphaComponent(0.3)
                renderer.strokeColor = baseColor.withAlphaComponent(0.8)
                renderer.lineWidth = 1.5
                return renderer
            }

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                switch polyline.title {
                case "flight":
                    renderer.strokeColor = RouteColors.flight
                    renderer.lineWidth = 2
                case "train":
                    renderer.strokeColor = RouteColors.train
                    renderer.lineWidth = 2
                case "bus":
                    renderer.strokeColor = RouteColors.bus
                    renderer.lineWidth = 2
                default:
                    renderer.strokeColor = .systemGray
                    renderer.lineWidth = 1
                }
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if let city = annotation as? CityPin {
                let id = "cityPin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: city, reuseIdentifier: id)
                view.annotation = city

                let name = city.title ?? ""
                let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = (name as NSString).size(withAttributes: attrs)
                let dotSize: CGFloat = 7
                let spacing: CGFloat = 4
                let padding: CGFloat = 6
                let totalWidth = dotSize + spacing + textSize.width + padding * 2
                let totalHeight = max(dotSize, textSize.height) + padding * 2

                let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight))
                view.image = renderer.image { ctx in
                    // Background pill
                    let bgRect = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
                    let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: totalHeight / 2)
                    UIColor.black.withAlphaComponent(0.55).setFill()
                    bgPath.fill()

                    // White dot
                    let dotY = (totalHeight - dotSize) / 2
                    let dotRect = CGRect(x: padding, y: dotY, width: dotSize, height: dotSize)
                    UIColor.white.setFill()
                    ctx.cgContext.fillEllipse(in: dotRect)

                    // City name
                    let textY = (totalHeight - textSize.height) / 2
                    let textPoint = CGPoint(x: padding + dotSize + spacing, y: textY)
                    (name as NSString).draw(at: textPoint, withAttributes: [
                        .font: font,
                        .foregroundColor: UIColor.white
                    ])
                }
                view.centerOffset = CGPoint(x: 0, y: -totalHeight / 2)
                view.displayPriority = .defaultHigh
                return view
            }

            if let airport = annotation as? AirportPin {
                let id = "airportPin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: airport, reuseIdentifier: id)
                view.annotation = airport

                let size: CGFloat = 8
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    ctx.cgContext.setFillColor(RouteColors.airport.cgColor)
                    ctx.cgContext.fillEllipse(in: rect)
                    ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                    ctx.cgContext.setLineWidth(1)
                    ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                }
                view.centerOffset = .zero
                view.displayPriority = .required
                return view
            }

            return nil
        }
    }
}

// MARK: - Full-Screen Stats Map

private struct FullStatsMapView: View {
    let countryPolygons: [MKPolygon]
    let flightOverlays: [MKPolyline]
    let trainOverlays: [MKPolyline]
    let busOverlays: [MKPolyline]
    let airports: [AirportPin]
    let cities: [CityPin]
    let colorMap: [String: UIColor]

    @Environment(\.dismiss) private var dismiss
    @State private var filter: StatsRouteFilter = .all

    var body: some View {
        ZStack {
            // Full-screen map
            CombinedMapRepresentable(
                countryPolygons: countryPolygons,
                flightOverlays: flightOverlays,
                trainOverlays: trainOverlays,
                busOverlays: busOverlays,
                airports: airports,
                cities: cities,
                colorMap: colorMap,
                showFlights: filter == .all || filter == .flights,
                showTrains: filter == .all || filter == .trains,
                showBuses: filter == .all || filter == .buses,
                isInteractive: true
            )
            .ignoresSafeArea()

            // Top controls
            VStack(spacing: 0) {
                HStack {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Title
                    Text("ГЕОГРАФИЯ")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Spacer()

                    // Invisible spacer for symmetry
                    Color.clear
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 8)

                // Filter picker
                Picker("", selection: $filter) {
                    ForEach(StatsRouteFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.sakuraPink)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

                Spacer()
            }
        }
    }

}
