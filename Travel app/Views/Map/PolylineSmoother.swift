import Foundation
import MapKit

/// Utility for smoothing GPS coordinate arrays using Douglas-Peucker simplification
/// followed by Catmull-Rom spline interpolation.
enum PolylineSmoother {

    // MARK: - Douglas-Peucker Simplification

    /// Reduces GPS noise by removing points that deviate less than `epsilon` degrees
    /// from the simplified line. Treats lat/lon as flat at city scale.
    /// - Parameters:
    ///   - coordinates: Raw GPS coordinate array.
    ///   - epsilon: Maximum deviation threshold in degrees (default ~5 meters).
    /// - Returns: Simplified coordinate array.
    static func simplify(
        coordinates: [CLLocationCoordinate2D],
        epsilon: Double = 0.00005
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 3 else { return coordinates }
        return douglasPeucker(coordinates: coordinates, epsilon: epsilon)
    }

    // MARK: - Catmull-Rom Smooth Pipeline

    /// Simplifies then applies Catmull-Rom spline interpolation to produce a smooth curve.
    /// - Parameters:
    ///   - coordinates: Raw GPS coordinate array.
    ///   - pointsPerSegment: Number of interpolated points between each simplified pair (default 8).
    ///   - epsilon: Douglas-Peucker epsilon in degrees (default ~5 meters).
    /// - Returns: Smooth coordinate array suitable for MapPolyline rendering.
    static func smooth(
        coordinates: [CLLocationCoordinate2D],
        pointsPerSegment: Int = 8,
        epsilon: Double = 0.00005
    ) -> [CLLocationCoordinate2D] {
        let simplified = simplify(coordinates: coordinates, epsilon: epsilon)
        guard simplified.count >= 2 else { return simplified }
        return catmullRom(points: simplified, pointsPerSegment: pointsPerSegment)
    }

    // MARK: - Private Helpers

    private static func douglasPeucker(
        coordinates: [CLLocationCoordinate2D],
        epsilon: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 3 else { return coordinates }

        let first = coordinates.first!
        let last = coordinates.last!

        // Find the point with the maximum perpendicular distance
        var maxDistance = 0.0
        var maxIndex = 0

        for i in 1..<(coordinates.count - 1) {
            let dist = perpendicularDistance(
                point: coordinates[i],
                lineStart: first,
                lineEnd: last
            )
            if dist > maxDistance {
                maxDistance = dist
                maxIndex = i
            }
        }

        // Recursively simplify if max distance exceeds epsilon
        if maxDistance > epsilon {
            let left = douglasPeucker(
                coordinates: Array(coordinates[0...maxIndex]),
                epsilon: epsilon
            )
            let right = douglasPeucker(
                coordinates: Array(coordinates[maxIndex...]),
                epsilon: epsilon
            )
            // Merge — drop duplicate point at junction
            return left.dropLast() + right
        } else {
            return [first, last]
        }
    }

    /// Perpendicular distance from a point to a line segment (flat lat/lon approximation).
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            // Line is a point — return distance from point to start
            let ex = point.longitude - lineStart.longitude
            let ey = point.latitude - lineStart.latitude
            return sqrt(ex * ex + ey * ey)
        }

        // Perpendicular distance formula
        let numerator = abs(
            dy * point.longitude
            - dx * point.latitude
            + lineEnd.longitude * lineStart.latitude
            - lineEnd.latitude * lineStart.longitude
        )
        return numerator / sqrt(lengthSquared)
    }

    /// Catmull-Rom spline interpolation over an array of control points.
    private static func catmullRom(
        points: [CLLocationCoordinate2D],
        pointsPerSegment: Int
    ) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []

        let n = points.count

        for i in 0..<(n - 1) {
            // Clamp control points for boundary segments
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(n - 1, i + 2)]

            let steps = pointsPerSegment
            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                let coord = catmullRomPoint(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                result.append(coord)
            }
        }

        // Append the final point
        if let last = points.last {
            result.append(last)
        }

        return result
    }

    /// Evaluates the Catmull-Rom formula at parameter t for one segment.
    /// Formula: 0.5 * ((2*p1) + (-p0+p2)*t + (2*p0-5*p1+4*p2-p3)*t² + (-p0+3*p1-3*p2+p3)*t³)
    private static func catmullRomPoint(
        p0: CLLocationCoordinate2D,
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D,
        t: Double
    ) -> CLLocationCoordinate2D {
        let t2 = t * t
        let t3 = t2 * t

        let lat = 0.5 * (
            (2 * p1.latitude)
            + (-p0.latitude + p2.latitude) * t
            + (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t2
            + (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t3
        )

        let lon = 0.5 * (
            (2 * p1.longitude)
            + (-p0.longitude + p2.longitude) * t
            + (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t2
            + (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t3
        )

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
