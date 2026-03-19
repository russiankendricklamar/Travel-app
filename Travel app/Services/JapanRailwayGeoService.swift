import Foundation
import CoreLocation

/// Loads bundled MLIT (国土交通省) railway GeoJSON data and provides
/// real track geometry for rendering train routes on the map.
///
/// Data source: National Land Numerical Information (国土数値情報) N02 鉄道データ
/// Processed by scripts/process_mlit_railways.py
@MainActor
final class JapanRailwayGeoService {
    static let shared = JapanRailwayGeoService()
    private init() {}

    // MARK: - Types

    struct RailwaySegment {
        let lineName: String
        let operator_: String
        let coordinates: [CLLocationCoordinate2D]
        let isShinkansen: Bool
    }

    // MARK: - State

    private var segments: [RailwaySegment] = []
    private var isLoaded = false

    /// Spatial index: grid cells mapping to segment indices
    private var spatialIndex: [String: [Int]] = [:]
    private let gridSize: Double = 0.1  // ~11km grid cells

    // MARK: - Loading

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        // Load full JR dataset (Shinkansen + conventional lines, ~2.2MB)
        // Falls back to Shinkansen-only if full dataset not in bundle
        let fileName: String
        if Bundle.main.url(forResource: "japan_railways", withExtension: "geojson") != nil {
            fileName = "japan_railways"
        } else {
            fileName = "japan_shinkansen"
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            print("[RailwayGeo] ❌ Failed to load \(fileName).geojson from bundle")
            return
        }

        for feature in features {
            guard let props = feature["properties"] as? [String: Any],
                  let geom = feature["geometry"] as? [String: Any],
                  let geomType = geom["type"] as? String else { continue }

            // Skip station points — we only need track segments
            let type = props["t"] as? String ?? ""
            guard type != "st" else { continue }

            let lineName = props["n"] as? String ?? ""
            let operator_ = props["o"] as? String ?? ""
            let isShinkansen = type == "s"

            let coords = parseCoordinates(geom: geom, geomType: geomType)
            guard coords.count >= 2 else { continue }

            let idx = segments.count
            segments.append(RailwaySegment(
                lineName: lineName,
                operator_: operator_,
                coordinates: coords,
                isShinkansen: isShinkansen
            ))

            // Build spatial index
            for coord in coords {
                let key = gridKey(coord)
                spatialIndex[key, default: []].append(idx)
            }
        }

        print("[RailwayGeo] ✅ Loaded \(segments.count) railway segments from \(fileName)")
    }

    // MARK: - Route Finding

    /// Find the real railway track geometry between two coordinates.
    /// Returns connected segments that form a path from `from` to `to`.
    func findRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        lineName: String? = nil
    ) -> [CLLocationCoordinate2D]? {
        loadIfNeeded()
        guard !segments.isEmpty else { return nil }

        // Find segments near origin and destination
        let originSegments = findNearbySegments(coordinate: origin, radiusKm: 10)
        let destSegments = findNearbySegments(coordinate: destination, radiusKm: 10)

        guard !originSegments.isEmpty, !destSegments.isEmpty else { return nil }

        // If a specific line name is given, filter to that line
        let filteredOrigin: [Int]
        let filteredDest: [Int]

        if let lineName, !lineName.isEmpty {
            let nameNormalized = lineName.lowercased()
            filteredOrigin = originSegments.filter {
                segments[$0].lineName.lowercased().contains(nameNormalized) ||
                nameNormalized.contains(segments[$0].lineName.lowercased())
            }
            filteredDest = destSegments.filter {
                segments[$0].lineName.lowercased().contains(nameNormalized) ||
                nameNormalized.contains(segments[$0].lineName.lowercased())
            }
        } else {
            filteredOrigin = originSegments
            filteredDest = destSegments
        }

        let originCandidates = filteredOrigin.isEmpty ? originSegments : filteredOrigin
        let destCandidates = filteredDest.isEmpty ? destSegments : filteredDest

        // Try to find the best connected path
        // Strategy: find the line that has segments near both origin and destination,
        // then collect all segments of that line between the two points
        let bestLine = findBestLine(
            originCandidates: originCandidates,
            destCandidates: destCandidates
        )

        guard let bestLine else { return nil }

        // Collect all segments of this line
        let lineSegments = segments.enumerated()
            .filter { $0.element.lineName == bestLine }
            .map { $0.offset }

        // Build connected polyline from all segments of this line
        let allCoords = buildConnectedPolyline(
            segmentIndices: lineSegments,
            from: origin,
            to: destination
        )

        guard allCoords.count >= 2 else { return nil }
        return allCoords
    }

    /// Find route along any Shinkansen line between two points.
    /// Supports multi-line routes (e.g. Tokaido + Sanyo for Tokyo→Hiroshima).
    func findShinkansenRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> (lineName: String, coordinates: [CLLocationCoordinate2D])? {
        loadIfNeeded()
        guard !segments.isEmpty else { return nil }

        // Get all unique Shinkansen line names
        let shinkansenLines = Set(segments.filter(\.isShinkansen).map(\.lineName))

        // Build per-line polylines using geographic sort (not endpoint chaining)
        struct LineInfo {
            let name: String
            let polyline: [CLLocationCoordinate2D]
            let nearOrigin: Bool
            let nearDest: Bool
        }

        var lineInfos: [LineInfo] = []

        for lineName in shinkansenLines {
            let lineSegmentCoords = segments
                .filter { $0.lineName == lineName && $0.isShinkansen }
                .map(\.coordinates)

            let polyline = buildSortedPolyline(lineSegmentCoords)
            guard polyline.count >= 2 else { continue }

            let nearOrigin = polyline.contains { distance(from: origin, to: $0) < 20_000 }
            let nearDest = polyline.contains { distance(from: destination, to: $0) < 20_000 }

            lineInfos.append(LineInfo(
                name: lineName,
                polyline: polyline,
                nearOrigin: nearOrigin,
                nearDest: nearDest
            ))

            // Single-line match
            if nearOrigin && nearDest {
                let trimmed = trimPolyline(polyline, from: origin, to: destination)
                if trimmed.count >= 2 {
                    return (lineName, trimmed)
                }
            }
        }

        // No single line covers both endpoints — try chaining two lines
        // (e.g. Tokaido Shinkansen + Sanyo Shinkansen at Shin-Osaka)
        let originLines = lineInfos.filter(\.nearOrigin)
        let destLines = lineInfos.filter(\.nearDest)

        var bestResult: (String, [CLLocationCoordinate2D])?
        var bestDistance: Double = .infinity

        for line1 in originLines {
            for line2 in destLines where line2.name != line1.name {
                // Try connecting the two pre-built polylines
                guard let combined = joinPolylines(line1.polyline, line2.polyline, maxGap: 5_000) else {
                    continue
                }

                let trimmed = trimPolyline(combined, from: origin, to: destination)
                if trimmed.count >= 2 {
                    let routeLength = totalDistance(trimmed)
                    if routeLength < bestDistance {
                        bestDistance = routeLength
                        bestResult = ("\(line1.name)→\(line2.name)", trimmed)
                    }
                }
            }
        }

        return bestResult
    }

    /// Check if the best matching route for given parameters is a Shinkansen line.
    func isRouteShinkansen(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        lineName: String? = nil
    ) -> Bool {
        let originSegs = findNearbySegments(coordinate: origin, radiusKm: 10)
        let destSegs = findNearbySegments(coordinate: destination, radiusKm: 10)
        guard !originSegs.isEmpty, !destSegs.isEmpty else { return false }

        let filteredOrigin: [Int]
        let filteredDest: [Int]

        if let lineName, !lineName.isEmpty {
            let nameNormalized = lineName.lowercased()
            filteredOrigin = originSegs.filter {
                segments[$0].lineName.lowercased().contains(nameNormalized) ||
                nameNormalized.contains(segments[$0].lineName.lowercased())
            }
            filteredDest = destSegs.filter {
                segments[$0].lineName.lowercased().contains(nameNormalized) ||
                nameNormalized.contains(segments[$0].lineName.lowercased())
            }
        } else {
            filteredOrigin = originSegs
            filteredDest = destSegs
        }

        let originCandidates = filteredOrigin.isEmpty ? originSegs : filteredOrigin
        let destCandidates = filteredDest.isEmpty ? destSegs : filteredDest

        guard let bestLine = findBestLine(originCandidates: originCandidates, destCandidates: destCandidates) else {
            return false
        }

        return segments.first { $0.lineName == bestLine }?.isShinkansen ?? false
    }

    // MARK: - Spatial Queries

    private func findNearbySegments(coordinate: CLLocationCoordinate2D, radiusKm: Double) -> [Int] {
        let gridRadius = Int(ceil(radiusKm / 11.0))  // grid cells to check
        let centerLat = Int(floor(coordinate.latitude / gridSize))
        let centerLng = Int(floor(coordinate.longitude / gridSize))

        var result = Set<Int>()
        for dLat in -gridRadius...gridRadius {
            for dLng in -gridRadius...gridRadius {
                let key = "\(centerLat + dLat),\(centerLng + dLng)"
                if let indices = spatialIndex[key] {
                    result.formUnion(indices)
                }
            }
        }

        // Filter by actual distance
        let radiusMeters = radiusKm * 1000
        return result.filter { idx in
            segments[idx].coordinates.contains { coord in
                distance(from: coordinate, to: coord) < radiusMeters
            }
        }.sorted()
    }

    private func findBestLine(originCandidates: [Int], destCandidates: [Int]) -> String? {
        // Find lines that appear in both candidate sets
        let originLines = Set(originCandidates.map { segments[$0].lineName })
        let destLines = Set(destCandidates.map { segments[$0].lineName })
        let commonLines = originLines.intersection(destLines)

        if let line = commonLines.first {
            return line
        }

        // No common line — use the closest segment's line
        return originCandidates.first.map { segments[$0].lineName }
    }

    // MARK: - Polyline Building

    private func buildConnectedPolyline(
        segmentIndices: [Int],
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard !segmentIndices.isEmpty else { return [] }

        // Collect all coordinates from segments
        var allSegmentCoords: [[CLLocationCoordinate2D]] = []
        for idx in segmentIndices {
            allSegmentCoords.append(segments[idx].coordinates)
        }

        // Chain segments by connecting endpoints
        let chain = chainSegments(allSegmentCoords)

        // Trim to the portion between origin and destination
        return trimPolyline(chain, from: origin, to: destination)
    }

    /// Build a continuous polyline by sorting segments geographically along the line.
    /// Unlike endpoint-chaining, this handles MLIT data where segments have multi-km gaps
    /// between them (e.g. around stations).
    private func buildSortedPolyline(_ segmentCoords: [[CLLocationCoordinate2D]]) -> [CLLocationCoordinate2D] {
        guard !segmentCoords.isEmpty else { return [] }
        if segmentCoords.count == 1 { return segmentCoords[0] }

        // Compute centroid longitude for each segment
        struct SortableSeg {
            let coords: [CLLocationCoordinate2D]
            let centroidLng: Double
        }

        let sortable = segmentCoords.compactMap { coords -> SortableSeg? in
            guard !coords.isEmpty else { return nil }
            let avgLng = coords.reduce(0.0) { $0 + $1.longitude } / Double(coords.count)
            return SortableSeg(coords: coords, centroidLng: avgLng)
        }

        // Sort east-to-west (descending longitude)
        let sorted = sortable.sorted { $0.centroidLng > $1.centroidLng }

        // Concatenate, flipping each segment to best connect to the previous one
        var result = sorted[0].coords
        for i in 1..<sorted.count {
            let seg = sorted[i].coords
            guard let chainEnd = result.last, let segFirst = seg.first, let segLast = seg.last else {
                continue
            }

            let dNormal = distance(from: chainEnd, to: segFirst)
            let dFlipped = distance(from: chainEnd, to: segLast)

            if dFlipped < dNormal {
                result.append(contentsOf: seg.reversed())
            } else {
                result.append(contentsOf: seg)
            }
        }

        return result
    }

    /// Join two pre-built polylines at their closest endpoints.
    /// Returns nil if the gap exceeds `maxGap` meters.
    private func joinPolylines(
        _ a: [CLLocationCoordinate2D],
        _ b: [CLLocationCoordinate2D],
        maxGap: Double
    ) -> [CLLocationCoordinate2D]? {
        guard let aFirst = a.first, let aLast = a.last,
              let bFirst = b.first, let bLast = b.last else { return nil }

        // Find which pair of endpoints is closest
        let options: [(Double, () -> [CLLocationCoordinate2D])] = [
            (distance(from: aLast, to: bFirst), { a + b }),
            (distance(from: aLast, to: bLast), { a + b.reversed() }),
            (distance(from: aFirst, to: bFirst), { a.reversed() + b }),
            (distance(from: aFirst, to: bLast), { b + a }),
        ]

        guard let best = options.min(by: { $0.0 < $1.0 }), best.0 < maxGap else {
            return nil
        }

        return best.1()
    }

    /// Chain disconnected segments into a continuous polyline by matching endpoints.
    private func chainSegments(_ segmentCoords: [[CLLocationCoordinate2D]]) -> [CLLocationCoordinate2D] {
        guard !segmentCoords.isEmpty else { return [] }
        if segmentCoords.count == 1 { return segmentCoords[0] }

        var remaining = segmentCoords
        var chain: [CLLocationCoordinate2D] = remaining.removeFirst()

        var changed = true
        while changed && !remaining.isEmpty {
            changed = false
            for i in (0..<remaining.count).reversed() {
                let seg = remaining[i]
                guard let chainFirst = chain.first, let chainLast = chain.last,
                      let segFirst = seg.first, let segLast = seg.last else { continue }

                let threshold: Double = 500  // meters

                if distance(from: chainLast, to: segFirst) < threshold {
                    // Append segment at end
                    chain.append(contentsOf: seg.dropFirst())
                    remaining.remove(at: i)
                    changed = true
                } else if distance(from: chainLast, to: segLast) < threshold {
                    // Append reversed segment at end
                    chain.append(contentsOf: seg.reversed().dropFirst())
                    remaining.remove(at: i)
                    changed = true
                } else if distance(from: chainFirst, to: segLast) < threshold {
                    // Prepend segment at start
                    chain = seg + chain.dropFirst()
                    remaining.remove(at: i)
                    changed = true
                } else if distance(from: chainFirst, to: segFirst) < threshold {
                    // Prepend reversed segment at start
                    chain = seg.reversed() + chain.dropFirst()
                    remaining.remove(at: i)
                    changed = true
                }
            }
        }

        return chain
    }

    /// Trim polyline to the portion closest to origin and destination.
    private func trimPolyline(
        _ coords: [CLLocationCoordinate2D],
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard coords.count >= 2 else { return coords }

        // Find closest point indices to origin and destination
        var originIdx = 0
        var originDist = Double.infinity
        var destIdx = coords.count - 1
        var destDist = Double.infinity

        for (i, coord) in coords.enumerated() {
            let dOrigin = distance(from: origin, to: coord)
            if dOrigin < originDist {
                originDist = dOrigin
                originIdx = i
            }
            let dDest = distance(from: destination, to: coord)
            if dDest < destDist {
                destDist = dDest
                destIdx = i
            }
        }

        // Ensure correct order
        let startIdx = min(originIdx, destIdx)
        let endIdx = max(originIdx, destIdx)

        guard startIdx < endIdx else { return Array(coords) }

        return Array(coords[startIdx...endIdx])
    }

    // MARK: - Helpers

    private func gridKey(_ coord: CLLocationCoordinate2D) -> String {
        let latKey = Int(floor(coord.latitude / gridSize))
        let lngKey = Int(floor(coord.longitude / gridSize))
        return "\(latKey),\(lngKey)"
    }

    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }

    private func totalDistance(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<coords.count {
            total += distance(from: coords[i - 1], to: coords[i])
        }
        return total
    }

    private func parseCoordinates(geom: [String: Any], geomType: String) -> [CLLocationCoordinate2D] {
        switch geomType {
        case "LineString":
            guard let coords = geom["coordinates"] as? [[Double]] else { return [] }
            return coords.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }

        case "MultiLineString":
            guard let lines = geom["coordinates"] as? [[[Double]]] else { return [] }
            return lines.flatMap { line in
                line.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
            }

        default:
            return []
        }
    }
}
