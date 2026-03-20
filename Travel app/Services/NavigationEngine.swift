import Foundation
import CoreLocation

@Observable
final class NavigationEngine {
    // MARK: - Public State
    private(set) var currentStepIndex: Int = 0
    private(set) var distanceToNextStep: CLLocationDistance = 0
    private(set) var isRerouting: Bool = false
    private(set) var isFinished: Bool = false

    // MARK: - Configuration
    private let offRouteThreshold: CLLocationDistance = 30   // NAV-03: meters
    private let rerouteDebounce: TimeInterval = 8            // NAV-04: seconds
    private let stepArrivalThreshold: CLLocationDistance = 15 // meters to step endpoint

    // MARK: - Dependencies
    private var route: RouteResult
    private var steps: [NavigationStep]
    private let voiceService: NavigationVoiceService

    // MARK: - Internal State
    private var lastRerouteTime: Date?

    // MARK: - Callbacks (to MapViewModel)
    var onStepAdvanced: ((Int, CLLocationDistance) -> Void)?
    var onRerouteNeeded: ((CLLocationCoordinate2D) -> Void)?
    var onNavigationFinished: (() -> Void)?

    // MARK: - Init

    init(route: RouteResult, steps: [NavigationStep], voiceService: NavigationVoiceService) {
        self.route = route
        self.steps = steps
        self.voiceService = voiceService
    }

    // MARK: - Current Step

    var currentStep: NavigationStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var remainingSteps: [NavigationStep] {
        guard currentStepIndex < steps.count else { return [] }
        return Array(steps[currentStepIndex...])
    }

    // MARK: - Reroute Control

    /// Cancel an in-progress reroute (e.g., on failure). Keeps private(set) intact.
    func cancelReroute() {
        isRerouting = false
    }

    // MARK: - Process Location (called on every GPS tick)

    func processLocation(_ location: CLLocation) {
        guard !isFinished, !steps.isEmpty else { return }

        let coord = location.coordinate

        // 1. Compute perpendicular distance from route polyline (off-route check)
        let perpendicularDist = perpendicularDistanceFromPolyline(coord)

        // 2. Compute distance to current step endpoint
        let stepEndCoord = stepEndCoordinate(for: currentStepIndex)
        let distToStepEnd = location.distance(from: CLLocation(
            latitude: stepEndCoord.latitude,
            longitude: stepEndCoord.longitude
        ))
        distanceToNextStep = distToStepEnd

        // 3. Step advancement — NAV-01
        if distToStepEnd < stepArrivalThreshold {
            advanceStep()
        }

        // 4. Voice distance triggers — NAV-02
        if let step = currentStep {
            voiceService.checkDistanceTrigger(distToStepEnd, stepInstruction: step.instruction)
        }

        // 5. Off-route detection — NAV-03
        if perpendicularDist > offRouteThreshold {
            triggerRerouteIfReady(from: coord)
        }

        // 6. Notify observer of current state
        onStepAdvanced?(currentStepIndex, distToStepEnd)
    }

    // MARK: - Step Advancement

    private func advanceStep() {
        let nextIndex = currentStepIndex + 1

        if nextIndex >= steps.count {
            // Navigation complete
            isFinished = true
            voiceService.resetAll()
            onNavigationFinished?()
            return
        }

        // Reset voice announcements for old step
        if let oldStep = currentStep {
            voiceService.resetForStep(oldStep.instruction)
        }

        currentStepIndex = nextIndex

        // Announce new step
        if let newStep = currentStep {
            voiceService.announceStep(
                instruction: newStep.instruction,
                distanceRemaining: newStep.distance
            )
        }
    }

    // MARK: - Off-Route Rerouting

    /// NAV-03 + NAV-04: trigger reroute with 8s debounce
    private func triggerRerouteIfReady(from coordinate: CLLocationCoordinate2D) {
        guard !isRerouting else { return }
        if let last = lastRerouteTime, Date().timeIntervalSince(last) < rerouteDebounce {
            return  // NAV-04: within debounce window
        }
        isRerouting = true
        lastRerouteTime = Date()
        onRerouteNeeded?(coordinate)
    }

    /// Called by MapViewModel after RoutingService returns a new route
    func didReceiveNewRoute(_ newRoute: RouteResult, steps newSteps: [NavigationStep]) {
        route = newRoute
        steps = newSteps
        currentStepIndex = 0
        distanceToNextStep = 0
        isRerouting = false

        voiceService.resetAll()
        if let firstStep = currentStep {
            voiceService.announceStep(
                instruction: firstStep.instruction,
                distanceRemaining: firstStep.distance
            )
        }
    }

    // MARK: - Polyline Snapping (perpendicular segment projection)

    /// Compute minimum perpendicular distance from point to entire route polyline.
    /// Uses segment-level projection — NOT nearest-vertex (avoids Pitfall 5/6).
    func perpendicularDistanceFromPolyline(_ point: CLLocationCoordinate2D) -> CLLocationDistance {
        let polyline = route.polyline
        guard polyline.count >= 2 else { return CLLocationDistanceMax }

        var minDistance = CLLocationDistanceMax

        for i in 0..<(polyline.count - 1) {
            let dist = perpendicularDistanceToSegment(
                point,
                from: polyline[i],
                to: polyline[i + 1]
            )
            minDistance = min(minDistance, dist)
        }

        return minDistance
    }

    /// Perpendicular distance from point to line segment [a, b].
    /// Uses approximate Cartesian projection (valid for <50km segments).
    private func perpendicularDistanceToSegment(
        _ point: CLLocationCoordinate2D,
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let lat2m = 111_320.0
        let lon2m = 111_320.0 * cos(a.latitude * .pi / 180)

        let px = (point.longitude - a.longitude) * lon2m
        let py = (point.latitude - a.latitude) * lat2m
        let bx = (b.longitude - a.longitude) * lon2m
        let by = (b.latitude - a.latitude) * lat2m

        let segLen2 = bx * bx + by * by
        guard segLen2 > 0 else {
            return sqrt(px * px + py * py)  // Degenerate segment
        }

        let t = max(0, min(1, (px * bx + py * by) / segLen2))
        let nearX = t * bx
        let nearY = t * by
        let dx = px - nearX
        let dy = py - nearY
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Helpers

    /// Get the endpoint coordinate for a step
    private func stepEndCoordinate(for stepIndex: Int) -> CLLocationCoordinate2D {
        guard stepIndex < steps.count else {
            return route.polyline.last ?? CLLocationCoordinate2D()
        }
        let step = steps[stepIndex]
        // Step endpoint is the last coordinate of its polyline
        if let last = step.polyline.last {
            return last
        }
        // Fallback: use next step's first coordinate, or route end
        if stepIndex + 1 < steps.count, let next = steps[stepIndex + 1].polyline.first {
            return next
        }
        return route.polyline.last ?? CLLocationCoordinate2D()
    }
}
