import SwiftUI

/// iPhone "Duo" — the SAME fold as iPad-Duo, on the phone's wallpaper. The
/// screen splits at the centre crease: the LEFT half folds away about the crease
/// while the RIGHT stays flat, and a screen-surface variable blur (iOS's own
/// `CAFilter("variableBlur")`, clipped to the left half) frosts the folding side
/// and sweeps toward the crease, with a dark scrim. Exact same blur radius, dark
/// and fold angle as the iPad.
///
/// A single Fold slider drives it on the Simulator (0 … 100 %); the gyro drives
/// it on device. The drag springs back to the flat default on release.
struct iPhoneDuoView: View {
    @State private var motion = MotionManager()

    // Simulator fallback: drag horizontally to fold; springs back to 0.
    @State private var isDragging = false
    @State private var dragFold = 0.0
    @State private var releaseAt: Date?
    @State private var releaseFold = 0.0
    @State private var showTuner = false
    @State private var manualFold = 0.0   // the single Fold slider (0…1)

    /// The wallpaper mockup.
    private let panoImage = "wall"

    // Baked-in tuning.
    private let maxBlur: Double = 55        // max variable-blur radius (pt) at the free edge, full fold
    private let darkStrength: Double = 0.60 // max scrim opacity at the free edge
    private let leftFoldAngle: Double = 35  // door swing at full fold, degrees

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let fold = currentFold(at: timeline.date)
                    foldStack(fold: fold, size: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .allowsHitTesting(false)   // visuals don't capture touches

                // Fold-drag layer below the tuner, so the slider gets its own touches.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geo.size))

                tuner
            }
        }
        .background(.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { motion.start(); UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { motion.stop(); UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Fold assembly (same model as iPad-Duo)

    /// The WHOLE screen is a page hinged like a door on the LEFT edge, so the
    /// RIGHT edge swings away as it folds (no centre split). A screen-surface
    /// variable blur frosts the RIGHT (free) edge and sweeps EDGE TO EDGE, with a
    /// dark scrim. `fold` is 0 (open, sharp) … 1 (fully folded).
    private func foldStack(fold: Double, size: CGSize) -> some View {
        let f = min(max(fold, 0), 1)
        let bite = pow(f, 0.4)
        let front = CGFloat(min(pow(f, 0.5), 1))   // frost sweeps EDGE TO EDGE at full fold
        let radius = CGFloat(maxBlur * bite)
        let dark = CGFloat(darkStrength * bite)
        let angle = leftFoldAngle * f
        return ZStack {
            // Out-of-focus backdrop so the area the door vacates never goes black.
            canvas(size: size)
                .blur(radius: 60, opaque: true)
                .overlay(Color.black.opacity(0.45))

            // The whole screen as a door, hinged on the LEFT edge so the RIGHT
            // edge swings back (away from the viewer).
            canvas(size: size)
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.6)

            // Screen-surface frost, EDGE TO EDGE — heaviest at the free (RIGHT)
            // edge, sweeping left as the fold deepens. Omitted at rest.
            if radius > 0.5 {
                VariableBlur(maxBlurRadius: radius, front: front, fromRight: true)
                    .allowsHitTesting(false)
            }

            // Dark scrim along the free (RIGHT) edge, matching the sweep.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(dark), location: 0),
                    .init(color: .black.opacity(dark * 0.55), location: front * 0.55),
                    .init(color: .clear, location: max(front, 0.001))
                ],
                startPoint: .trailing, endPoint: .leading
            )
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The full-bleed wallpaper page.
    private func canvas(size: CGSize) -> some View {
        Image(panoImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: Tuner overlay (single Fold slider)

    private var tuner: some View {
        VStack(spacing: 0) {
            Spacer()
            if showTuner {
                HStack(spacing: 12) {
                    Text("Fold").font(.system(size: 14, weight: .semibold)).frame(width: 44, alignment: .leading)
                    Slider(value: $manualFold, in: 0...1)
                    Text("\(Int(manualFold * 100))%")
                        .font(.system(size: 14, design: .monospaced)).frame(width: 54, alignment: .trailing)
                }
                .foregroundStyle(.white)
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
            }
            HStack {
                Spacer()
                Button { showTuner.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(12)
                }
                .padding(16)
            }
        }
    }

    // MARK: Fold source

    /// Fold amount 0…1. An active drag wins; else the single Fold slider; else
    /// the gyro roll (`gx`, portrait); else it springs back to the flat default.
    private func currentFold(at date: Date) -> Double {
        if isDragging { return dragFold }
        if manualFold > 0.001 { return manualFold }
        if motion.isUsingGyro { return min(max(motion.gx, 0), 1) }
        guard let releaseAt else { return 0 }
        let t = date.timeIntervalSince(releaseAt)
        if t >= 1.6 { return 0 }
        // Underdamped spring easing the released fold back to 0.
        let omega = 9.0, zeta = 0.7
        let wd = omega * (1 - zeta * zeta).squareRoot()
        let decay = exp(-zeta * omega * t)
        let value = releaseFold * decay * (cos(wd * t) + (zeta * omega / wd) * sin(wd * t))
        return min(max(value, 0), 1)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                releaseAt = nil
                dragFold = min(max(value.translation.width / (size.width * 0.4), 0), 1)
            }
            .onEnded { _ in
                isDragging = false
                releaseFold = dragFold
                releaseAt = Date()
            }
    }
}

#Preview {
    iPhoneDuoView()
}
