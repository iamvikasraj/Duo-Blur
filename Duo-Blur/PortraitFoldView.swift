import SwiftUI

/// The iPhone (portrait) experiment: the whole screen is one panel showing
/// the left half of the dune panorama (`wall-left`, shared with the iPad
/// fold). Tilting the phone left/right swings the entire panel like a door —
/// anchored on the middle of the edge you tilt toward — revealing the other
/// half of the panorama (`wall-right`) blurred in the room behind it.
///
/// The panel renders sharp; the progressive blur is a top-most screen-space
/// layer that ramps from the free (fast-moving) edge toward the hinge edge.
struct PortraitFoldView: View {
    @State private var motion = MotionManager()

    // Simulator fallback state.
    @State private var isDragging = false
    @State private var dragFold = 0.0

    // Swing-angle tuner. The door reads best well short of 90°: a full-screen
    // panel at steep angles vacates most of the display.
    @State private var showTuner = false
    @State private var maxRotation: Double = 40

    // Reaches are staggered across the full door width so each stop hands
    // off to the next: no shared cutoff line, just a continuous focus ramp.
    private let steps: [BlurStep] = [
        BlurStep(radius: 16,  reach: 1.00),   // lightest, reaches the hinge
        BlurStep(radius: 34,  reach: 0.85),
        BlurStep(radius: 66,  reach: 0.70),
        BlurStep(radius: 120, reach: 0.55),
        BlurStep(radius: 190, reach: 0.40),
        BlurStep(radius: 260, reach: 0.28)    // heaviest, hugs the free edge
    ]

    /// Sorted lightest→heaviest so the heavier stops layer on top near the edge.
    private var sortedSteps: [BlurStep] { steps.sorted { $0.radius < $1.radius } }

    // Door face and the room behind it — the panorama's other half waits
    // behind the door. (The day-time twins were removed from the catalog,
    // so both layers are night now.) Left images crop from their left edge,
    // right images from their right, preserving each half's outer side.
    #if targetEnvironment(simulator)
    private let doorImage = "wall-left"
    private let backdropImage = "wall-right"
    private let cropAlignment = Alignment.leading
    #else
    private let doorImage = "wall-right"
    private let backdropImage = "wall-left"
    private let cropAlignment = Alignment.trailing
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let fold = currentFold(at: timeline.date)

                    ZStack {
                        // Backdrop: the same wallpaper, heavily blurred and
                        // dimmed, so the door visibly recedes into a room
                        // instead of a black void.
                        backdrop(size: geo.size)

                        // Sharp door panel, swinging on the hinge.
                        door(fold: fold, size: geo.size)

                        // Top-most progressive blur: frosted glass over the
                        // SCREEN. Blurred copies of the rotated scene, masked
                        // from the free edge toward the hinge, so the door
                        // moves behind the glass rather than carrying blur
                        // painted on its surface.
                        ForEach(sortedSteps) { step in
                            door(fold: fold, size: geo.size)
                                .blur(radius: step.radius * CGFloat(abs(fold)))
                                .mask(blurMask(reach: step.reach, fold: fold))
                                .allowsHitTesting(false)
                        }
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

    /// The full-screen wall image, hinged like a door on the middle of the
    /// edge the phone is tilted toward. `fold` > 0 anchors the right edge
    /// (free left edge swings back), `fold` < 0 mirrors it.
    /// The sharp door: the wallpaper swinging on the hinge, with its free
    /// edge shaded. Renders crisp — the blur lives in the screen-space glass
    /// layer above, not on the panel.
    private func door(fold: Double, size: CGSize) -> some View {
        let anchor: UnitPoint = fold >= 0 ? UnitPoint(x: 1, y: 0.5) : UnitPoint(x: 0, y: 0.5)

        return doorFace(size: size)
            .overlay { fadeToBlack(fold: fold) }
            .rotation3DEffect(.degrees(-fold * maxRotation), axis: (x: 0, y: 1, z: 0),
                              anchor: anchor, perspective: 0.5)
            .frame(width: size.width, height: size.height)
            .accessibilityHidden(true)
    }

    private func doorFace(size: CGSize) -> some View {
        Image(doorImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height, alignment: cropAlignment)
            .clipped()
    }

    /// Static room behind the door: the panorama's other half, blurred far
    /// out of focus and dimmed. Fully covered while the door is flat;
    /// revealed as it swings.
    private func backdrop(size: CGSize) -> some View {
        Image(backdropImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height, alignment: cropAlignment)
            .clipped()
            .blur(radius: 60, opaque: true)
            .overlay(Color.black.opacity(0.65))
            .accessibilityHidden(true)
    }

    /// Gently shades the free edge as it swings away — much softer and
    /// shorter than the landscape panels' fade, since it spans a full-width
    /// door rather than half a screen.
    private func fadeToBlack(fold: Double) -> some View {
        let strength = min(abs(fold), 0.85)
        return LinearGradient(
            stops: [
                .init(color: .black.opacity(strength), location: 0),
                .init(color: .black.opacity(strength * 0.3), location: 0.18),
                .init(color: .clear, location: 0.4)
            ],
            startPoint: fold >= 0 ? .leading : .trailing,
            endPoint: fold >= 0 ? .trailing : .leading
        )
        .allowsHitTesting(false)
    }

    /// Screen-space mask for a blur stop, shaped like depth of field. White
    /// (blur) sits at the free edge — farthest from the focal plane — and
    /// ramps to clear toward the hinge side, which stays in focus. Applied
    /// over the rotated scene, so it reads as frosted glass on the display.
    private func blurMask(reach: CGFloat, fold: Double) -> LinearGradient {
        let e = min(max(reach, 0), 1)
        let rightHinged = fold >= 0   // hinge right → free edge on the left
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .clear, location: e),
                .init(color: .clear, location: 1)
            ],
            startPoint: rightHinged ? .leading : .trailing,
            endPoint: rightHinged ? .trailing : .leading
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

    /// Left/right tilt (roll). In portrait `gx` is 0 held level and ±1 at a
    /// 90° sideways tilt, so the door hinges on whichever edge dips down.
    private func currentFold(at date: Date) -> Double {
        if motion.isUsingGyro { return motion.gx }
        if isDragging { return dragFold }
        return 0   // No gyro (Simulator): stay flat unless dragged.
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

#Preview {
    PortraitFoldView()
}
