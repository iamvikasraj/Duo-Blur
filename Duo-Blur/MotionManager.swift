import SwiftUI
import CoreMotion

/// Reads the device's tilt via CoreMotion and exposes it as two normalized
/// values, `roll` (left/right) and `pitch` (forward/back), each roughly in
/// the range -1...1.
///
/// We drive the effect from the **gravity vector** rather than raw attitude:
/// gravity's x/y components are already normalized (-1...1), stable, and free
/// of the gimbal-lock jumps you get from Euler angles — ideal for parallax.
///
/// The iOS Simulator has no gyroscope, so `isUsingGyro` reports whether real
/// motion data is available. When it isn't, the fold simply rests flat.
@Observable
final class MotionManager {

    /// Smoothed, normalized gravity components (~-1...1) in the device's fixed
    /// frame. `gx` is the device's short axis, `gy` its long axis. The view maps
    /// these to screen left/right depending on interface orientation.
    var gx: Double = 0
    var gy: Double = 0

    /// True once real device-motion updates are flowing.
    private(set) var isUsingGyro = false

    private let manager = CMMotionManager()

    /// Full deflection (1.0) corresponds to a 90° physical tilt. Combined with
    /// a 90° max panel rotation, the rendered angle tracks the device's real
    /// tilt 1:1 — like lifting one half of a notebook while the other half
    /// stays flat on the table.
    private let maxTiltAngle = Double.pi / 2

    /// Low-pass smoothing (0 = frozen, 1 = no smoothing). Keeps the scene from
    /// jittering with the raw sensor noise.
    private let smoothing = 0.12

    func start() {
        guard manager.isDeviceMotionAvailable else {
            isUsingGyro = false
            return
        }
        isUsingGyro = true
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }

            // asin recovers the true tilt angle from the gravity component
            // (gravity.x = sin(tilt)), so the mapping stays angle-accurate
            // instead of compressing near 90°.
            let tx = asin(gravity.x.clamped()) / self.maxTiltAngle
            let ty = asin(gravity.y.clamped()) / self.maxTiltAngle

            self.gx += (tx - self.gx) * self.smoothing
            self.gy += (ty - self.gy) * self.smoothing
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isUsingGyro = false
    }
}

extension Double {
    /// Clamp into a symmetric range (default -1...1).
    func clamped(to limit: Double = 1) -> Double {
        Swift.min(Swift.max(self, -limit), limit)
    }
}
