import SwiftUI

// MARK: - Blur configuration

/// One stop of the progressive blur: a base radius (scaled by fold), how far
/// across the swinging half — from the outer screen edge toward the hinge — it
/// reaches (0…1), and a stable color for the visualizer.
struct BlurStep: Identifiable {
    let id = UUID()
    var radius: CGFloat
    var reach: CGFloat
    var hue: Double

    var color: Color { Color(hue: hue, saturation: 0.85, brightness: 1) }
}

// MARK: - Content

/// Two-panel "iPhone Duo" fold, driven by the gyroscope. Whichever way you tilt,
/// that side's panel swings on the center hinge while the other stays flat.
///
/// The panels themselves render **sharp**. The progressive blur is a **top-most,
/// screen-space layer**: blurred copies of the whole scene, masked to the
/// swinging half, so the blur behaves like glass over the screen rather than
/// being painted onto the rotating image.
struct ContentView: View {
    @State private var motion = MotionManager()

    // Simulator fallback state.
    @State private var isDragging = false
    @State private var dragFold = 0.0

    // Tuning visualizer.
    @State private var showTuner = false
    @State private var manualFold = 0.5
    @State private var steps: [BlurStep] = [
        BlurStep(radius: 16,  reach: 1.00, hue: 0.62),   // reaches the hinge
        BlurStep(radius: 34,  reach: 1.00, hue: 0.02),
        BlurStep(radius: 66,  reach: 0.98, hue: 0.12),
        BlurStep(radius: 120, reach: 0.94, hue: 0.33),
        BlurStep(radius: 190, reach: 0.88, hue: 0.50),
        BlurStep(radius: 260, reach: 0.80, hue: 0.80)    // heaviest, stays strong nearly to the middle
    ]

    @State private var maxRotation: Double = 35

    /// Sorted lightest→heaviest so the heavier stops layer on top near the edge.
    private var sortedSteps: [BlurStep] { steps.sorted { $0.radius < $1.radius } }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let isLandscape = geo.size.width >= geo.size.height
                    let fold = showTuner ? manualFold : currentFold(isLandscape: isLandscape, at: timeline.date)
                    let panel = CGSize(width: geo.size.width / 2, height: geo.size.height)
                    let ordered = sortedSteps

                    ZStack {
                        // Sharp scene.
                        scene(fold: fold, panel: panel, size: geo.size)

                        // Top-most progressive blur: blurred copies of the whole
                        // scene, masked to the swinging half in screen space.
                        ForEach(ordered) { step in
                            scene(fold: fold, panel: panel, size: geo.size)
                                .blur(radius: step.radius * CGFloat(abs(fold)), opaque: true)
                                .mask(blurMask(reach: step.reach, fold: fold))
                                .allowsHitTesting(false)
                        }

                        // Lock screen: flat, full-display UI on top, always sharp.
                        LockScreen()

                        if showTuner { BlurStopOverlay(steps: ordered) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geo.size))
                }

                tuner
            }
        }
        .background(.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    // MARK: Sharp scene

    private func scene(fold: Double, panel: CGSize, size: CGSize) -> some View {
        ZStack {
            Color.black
            HStack(spacing: 0) {
                SharpPanel(imageName: "wall-left", outerLeading: true,
                           magnitude: max(-fold, 0), size: panel, maxRotation: maxRotation)
                SharpPanel(imageName: "wall-right", outerLeading: false,
                           magnitude: max(fold, 0), size: panel, maxRotation: maxRotation)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// Screen-space mask for a blur stop. White (blur) sits at the swinging
    /// side's outer screen edge and ramps to clear by `reach` of the half-width
    /// toward the hinge. The side follows the fold sign.
    private func blurMask(reach: CGFloat, fold: Double) -> LinearGradient {
        let e = min(max(reach, 0), 1) * 0.5   // half the screen = the swinging panel
        let rightSide = fold >= 0
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .clear, location: e),
                .init(color: .clear, location: 1)
            ],
            startPoint: rightSide ? .trailing : .leading,
            endPoint: rightSide ? .leading : .trailing
        )
    }

    // MARK: Tuner overlay

    private var tuner: some View {
        VStack(spacing: 0) {
            Spacer()
            if showTuner {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Blur stops").font(.system(size: 13, weight: .bold))
                        Spacer()
                        Button {
                            steps.append(BlurStep(radius: 30, reach: 0.5, hue: Double.random(in: 0...1)))
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                        }
                    }
                    ForEach($steps) { $step in stepRow($step) }
                    Divider().overlay(Color.white.opacity(0.2))
                    HStack(spacing: 10) {
                        Text("Fold").font(.system(size: 12, weight: .semibold)).frame(width: 48, alignment: .leading)
                        Slider(value: $manualFold, in: -1...1)
                        Text(String(format: "%+.2f  %d°", manualFold, Int(manualFold * maxRotation)))
                            .font(.system(size: 12, design: .monospaced)).frame(width: 78, alignment: .trailing)
                    }
                    HStack(spacing: 10) {
                        Text("Swing").font(.system(size: 12, weight: .semibold)).frame(width: 48, alignment: .leading)
                        Slider(value: $maxRotation, in: 0...90)
                        Text("\(Int(maxRotation))° max")
                            .font(.system(size: 12, design: .monospaced)).frame(width: 78, alignment: .trailing)
                    }
                    Text("Blur is a top layer over the screen, on the swinging half. r = base radius, % = reach toward the hinge.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
            HStack {
                Spacer()
                Button { showTuner.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(16)
            }
        }
    }

    private func stepRow(_ step: Binding<BlurStep>) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(step.wrappedValue.color).frame(width: 16, height: 10)
            Text("r").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            Slider(value: step.radius, in: 2...350)
            Text("\(Int(step.wrappedValue.radius))")
                .font(.system(size: 11, design: .monospaced)).frame(width: 34, alignment: .trailing)
            Text("reach").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            Slider(value: step.reach, in: 0...1)
            Text("\(Int(step.wrappedValue.reach * 100))%")
                .font(.system(size: 11, design: .monospaced)).frame(width: 38, alignment: .trailing)
            Button {
                steps.removeAll { $0.id == step.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 15))
                    .foregroundStyle(steps.count > 1 ? .red : .gray)
            }
            .disabled(steps.count <= 1)
        }
    }

    // MARK: Fold source

    private func currentFold(isLandscape: Bool, at date: Date) -> Double {
        if motion.isUsingGyro { return isLandscape ? motion.gy : motion.gx }
        if isDragging { return dragFold }
        return sin(date.timeIntervalSinceReferenceDate * 0.5) * 0.7
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                dragFold = (value.translation.width / (size.width * 0.35)).clamped()
            }
            .onEnded { _ in isDragging = false }
    }
}

// MARK: - Sharp panel

/// One half of the fold, rendered sharp: its (seam-aligned) image plus a
/// fade-to-black on its outer edge, hinged on its inner edge.
private struct SharpPanel: View {
    let imageName: String
    let outerLeading: Bool
    let magnitude: Double
    let size: CGSize
    let maxRotation: Double

    var body: some View {
        let anchor: UnitPoint = outerLeading ? UnitPoint(x: 1, y: 0.5) : UnitPoint(x: 0, y: 0.5)
        let angle = (outerLeading ? -1.0 : 1.0) * magnitude * maxRotation

        photo()
            .overlay { fadeToBlack }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                              anchor: anchor, perspective: 0.5)
    }

    private func photo() -> some View {
        // Align each half's INNER (seam) edge to the hinge so the two halves line
        // up into one continuous panorama; the outer edge is the one cropped.
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height,
                   alignment: outerLeading ? .trailing : .leading)
            .clipped()
            .accessibilityHidden(true)
    }

    private var fadeToBlack: some View {
        let strength = min(magnitude * 1.3, 0.98)
        return LinearGradient(
            colors: [.black.opacity(strength), .black.opacity(strength * 0.35), .clear],
            startPoint: outerLeading ? .leading : .trailing,
            endPoint: .center
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Blur-stop visualizer (screen space)

/// Vertical guide lines showing where each blur stop reaches, measured from each
/// screen edge toward the center hinge, plus edge and hinge markers.
private struct BlurStopOverlay: View {
    let steps: [BlurStep]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                edge(x: 0, lineWidth: 3, color: .white, h: h)
                edge(x: w, lineWidth: 3, color: .white, h: h)
                edge(x: w / 2, lineWidth: 1.5, color: .white.opacity(0.4), h: h)

                ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                    let dx = step.reach * 0.5 * w
                    edge(x: w - dx, lineWidth: 2, color: step.color, h: h, dashed: true)
                    edge(x: dx, lineWidth: 2, color: step.color, h: h, dashed: true)
                    Text("r\(Int(step.radius))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(step.color)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                        .position(x: w - dx, y: 26 + CGFloat(i) * 22)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func edge(x: CGFloat, lineWidth: CGFloat, color: Color, h: CGFloat, dashed: Bool = false) -> some View {
        Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)) }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dashed ? [7, 5] : []))
    }
}

// MARK: - Lock screen (primary leaf)

/// The iOS-style lock screen across the whole display — date + clock centered at
/// top, Wi-Fi in the top-right corner, flashlight/camera in the bottom corners,
/// and the home indicator bottom-center.
private struct LockScreen: View {
    var body: some View {
        ZStack {
            // Home indicator, bottom-center.
            VStack {
                Spacer()
                Capsule().fill(.white.opacity(0.85)).frame(width: 150, height: 5)
            }
            .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
