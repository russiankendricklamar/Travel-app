#if !targetEnvironment(simulator)
import RealityKit
import ARKit
import CoreLocation

final class ARCoordinator: NSObject, ARSessionDelegate {
    var targetCoordinate: CLLocationCoordinate2D
    weak var arView: ARView?
    var arrowEntity: ModelEntity?

    private var textEntity: ModelEntity?

    init(targetCoordinate: CLLocationCoordinate2D) {
        self.targetCoordinate = targetCoordinate
        super.init()
    }

    // MARK: - Arrow Entity

    func createArrowEntity() -> ModelEntity {
        // Cone shape as directional arrow
        let coneMesh = MeshResource.generateCone(height: 0.3, radius: 0.08)
        var material = SimpleMaterial()
        material.color = .init(
            tint: UIColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 0.9),
            texture: nil
        )
        material.metallic = .float(0.3)
        material.roughness = .float(0.5)

        let arrow = ModelEntity(mesh: coneMesh, materials: [material])
        arrow.position = SIMD3<Float>(0, 0, -3) // 3m in front
        return arrow
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let arrow = arrowEntity else { return }

        let manager = ARNavigationManager.shared
        let bearingRadians = Float(manager.bearing * .pi / 180)

        // Rotate arrow to point toward target bearing
        let rotation = simd_quatf(angle: -bearingRadians, axis: SIMD3<Float>(0, 1, 0))
        arrow.transform.rotation = rotation

        // Position arrow 3m ahead at eye level
        let cameraTransform = frame.camera.transform
        let forward = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            0,
            -cameraTransform.columns.2.z
        )
        let normalizedForward = simd_normalize(forward)
        let arrowPosition = SIMD3<Float>(
            cameraTransform.columns.3.x + normalizedForward.x * 3,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z + normalizedForward.z * 3
        )
        arrow.position = arrowPosition

        // Gentle floating animation
        let floatOffset = sin(Float(Date().timeIntervalSince1970 * 2)) * 0.05
        arrow.position.y += floatOffset
    }
}
#endif
