import SwiftUI

// MARK: - Blur configuration

/// One stop of the progressive blur: a base radius (scaled by fold) and how far
/// across the swinging half — from the outer screen edge toward the hinge — it
/// reaches (0…1).
struct BlurStep: Identifiable {
    let id = UUID()
    var radius: CGFloat
    var reach: CGFloat
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

    // Depth effect: subject cutouts lifted from the wallpapers by Vision
    // (nil until segmentation finishes, or when no subject is found).
    @State private var leftCutout: UIImage?
    @State private var rightCutout: UIImage?

    // Swing-angle tuner.
    @State private var showTuner = false

    private let steps: [BlurStep] = [
        BlurStep(radius: 16,  reach: 1.00),   // reaches the hinge
        BlurStep(radius: 34,  reach: 1.00),
        BlurStep(radius: 66,  reach: 0.98),
        BlurStep(radius: 120, reach: 0.94),
        BlurStep(radius: 190, reach: 0.88),
        BlurStep(radius: 260, reach: 0.80)    // heaviest, stays strong nearly to the middle
    ]

    // Rendered swing at full (90°) physical tilt. Deliberately less than 90:
    // the screen's perspective projection assumes an eye dead-center in front,
    // so a true 90° panel reads as over-rotated from any real viewing angle
    // and breaks the flat-on-the-table illusion.
    @State private var maxRotation: Double = 70

    /// Sorted lightest→heaviest so the heavier stops layer on top near the edge.
    private var sortedSteps: [BlurStep] { steps.sorted { $0.radius < $1.radius } }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let isLandscape = geo.size.width >= geo.size.height
                    let fold = currentFold(isLandscape: isLandscape, at: timeline.date)
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

                        // Depth effect: the lifted subject drawn above the lock
                        // screen so it overlaps the clock, with the same layout
                        // and hinge transform as the sharp panels so it stays
                        // registered with the wallpaper.
                        cutoutScene(fold: fold, panel: panel, size: geo.size)
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
        .task {
            leftCutout = await SubjectLift.cutout(fromImageNamed: "wall-left")
            rightCutout = await SubjectLift.cutout(fromImageNamed: "wall-right")
        }
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

    /// The lifted-subject layer: same two-panel layout as `scene`, but drawing
    /// the transparent-background cutouts and no edge fade.
    private func cutoutScene(fold: Double, panel: CGSize, size: CGSize) -> some View {
        HStack(spacing: 0) {
            CutoutPanel(image: leftCutout, outerLeading: true,
                        magnitude: max(-fold, 0), size: panel, maxRotation: maxRotation)
            CutoutPanel(image: rightCutout, outerLeading: false,
                        magnitude: max(fold, 0), size: panel, maxRotation: maxRotation)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .allowsHitTesting(false)
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
                HStack(spacing: 10) {
                    Text("Swing").font(.system(size: 12, weight: .semibold)).frame(width: 48, alignment: .leading)
                    Slider(value: $maxRotation, in: 0...90)
                    Text("\(Int(maxRotation))° max")
                        .font(.system(size: 12, design: .monospaced)).frame(width: 78, alignment: .trailing)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
            HStack {
                Spacer()
                Button { showTuner.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(12)   // keeps a comfortable tap target
                }
                .padding(16)
            }
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

// MARK: - Cutout panel (depth effect)

/// The lifted-subject counterpart of `SharpPanel`: identical layout and hinge
/// transform, but drawing the subject cutout with no edge fade, so the subject
/// lands pixel-perfect over its wallpaper twin.
private struct CutoutPanel: View {
    let image: UIImage?
    let outerLeading: Bool
    let magnitude: Double
    let size: CGSize
    let maxRotation: Double

    var body: some View {
        let anchor: UnitPoint = outerLeading ? UnitPoint(x: 1, y: 0.5) : UnitPoint(x: 0, y: 0.5)
        let angle = (outerLeading ? -1.0 : 1.0) * magnitude * maxRotation

        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height,
                           alignment: outerLeading ? .trailing : .leading)
                    .clipped()
            } else {
                Color.clear.frame(width: size.width, height: size.height)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                          anchor: anchor, perspective: 0.5)
        .accessibilityHidden(true)
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
