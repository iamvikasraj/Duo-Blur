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
/// motion data is available. When it isn't, the view falls back to a drag
/// gesture plus a gentle idle sway.
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

    /// How much tilt reaches full deflection. 0.5g ≈ a 30° tilt maps to 1.0,
    /// so a comfortable hand-tilt covers the whole range.
    private let sensitivity = 0.5

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

            let tx = (gravity.x / self.sensitivity).clamped()
            let ty = (gravity.y / self.sensitivity).clamped()

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
