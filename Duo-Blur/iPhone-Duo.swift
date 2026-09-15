import SwiftUI

/// The "home screen pano" experiment: a wallpaper hinged like a door on the
/// edge you tilt TOWARD. Tilt one way and the whole panel swings on the right
/// edge; tilt the other way and the hinge jumps to the left.
///
/// Over the top sits a FIXED progressive blur (a Figma-style variable layer
/// blur): a left→right Gaussian ramp from sharp (start blur 0) to full (end
/// blur) that stays put regardless of the tilt — it does not follow the fold.
/// Figma reference: X 0% → 104%, Y 50%, start blur 0, end blur 24.
struct iPhoneDuoView: View {
    @State private var motion = MotionManager()

    // Simulator fallback state.
    @State private var isDragging = false
    @State private var dragFold = 0.0

    // Swing-angle tuner. Pushed steep so the free edge folds down hard toward
    // the surface — the panel reads like a page laying onto a table rather
    // than a gentle sway. Short of 90° on purpose: a true right angle vacates
    // the screen and over-rotates for an off-center eye.
    @State private var showTuner = false
    @State private var maxRotation: Double = 78

    /// The wallpaper mockup.
    private let panoImage = "wall"

    // MAX progressive-blur strength — the Gaussian radius at the right edge
    // when the phone is fully tilted. Scaled by |tilt|, so it's 0 when level.
    @State private var endBlur: Double = 24

    // MAX black-scrim opacity on the blurry (right) side at full tilt. Also
    // scaled by |tilt|, so the photo is clean and undimmed when level.
    @State private var darkStrength: Double = 0.75

    /// The physical display's corner radius, so the page matches the iPhone's
    /// rounded screen. `_displayCornerRadius` is private API (fine for an
    /// experiment; swap for a constant if you ship to the App Store); the
    /// fallback covers the Simulator and older devices where it's unavailable.
    private var screenCornerRadius: CGFloat {
        (UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 55
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let fold = currentFold(at: timeline.date)
                    let tilt = abs(fold)   // 0 held level, → 1 at full tilt

                    ZStack {
                        // Backdrop: the same wallpaper far out of focus, so
                        // the corners vacated by the fold never go black.
                        backdrop(size: geo.size)

                        // The folding page under the fixed left→right progressive
                        // blur. Blur + dark scrim are DRIVEN BY THE GYRO: dead
                        // sharp when the phone is level, ramping to the Blur/Dark
                        // maxima as the tilt grows.
                        ProgressiveBlur(startBlur: 0, endBlur: CGFloat(endBlur * tilt),
                                        tint: .black, tintStrength: CGFloat(darkStrength * tilt)) {
                            panel(fold: fold, size: geo.size)
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

    // MARK: Panel

    /// The wallpaper as a page shaped like the iPhone's own screen, hinged like
    /// a door on the edge you tilt toward. `fold` >= 0 anchors the right edge
    /// (free left edge swings out); `fold` < 0 anchors the left edge, mirroring
    /// it. The image is clipped to a rounded-rectangle the size of the display
    /// before it rotates, so it's a fixed slab with the phone's own rounded
    /// corners — swinging it reveals the room behind rather than sliding fresh
    /// wallpaper into the frame.
    private func panel(fold: Double, size: CGSize) -> some View {
        let rightHinged = fold >= 0
        let anchor: UnitPoint = rightHinged ? UnitPoint(x: 1, y: 0.5) : UnitPoint(x: 0, y: 0.5)

        // Rounded like the physical screen ONLY as the page folds. Level, it's a
        // plain full-bleed rectangle (radius 0) so it fills edge-to-edge with no
        // dark corner; the corners round in as it lifts, reading as a display.
        let cornerRadius = screenCornerRadius * min(abs(fold) * 3, 1)

        return Image(panoImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay { fadeToBlack(rightHinged: rightHinged, magnitude: abs(fold)) }
            .rotation3DEffect(.degrees(-fold * maxRotation), axis: (x: 0, y: 1, z: 0),
                              anchor: anchor, perspective: 0.8)
            .accessibilityHidden(true)
    }

    /// Static out-of-focus room behind the spinning panel.
    private func backdrop(size: CGSize) -> some View {
        Image(panoImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 60, opaque: true)
            .overlay(Color.black.opacity(0.65))
            .accessibilityHidden(true)
    }

    /// Gently shades the free edge as it swings away from the viewer. The free
    /// edge is opposite the hinge; `magnitude` (0…1) scales the shading with
    /// how far the page is rotated.
    private func fadeToBlack(rightHinged: Bool, magnitude: Double) -> some View {
        let strength = min(magnitude, 0.85)
        return LinearGradient(
            stops: [
                .init(color: .black.opacity(strength), location: 0),
                .init(color: .black.opacity(strength * 0.3), location: 0.18),
                .init(color: .clear, location: 0.4)
            ],
            startPoint: rightHinged ? .leading : .trailing,
            endPoint: rightHinged ? .trailing : .leading
        )
        .allowsHitTesting(false)
    }

    // MARK: Tuner overlay

    private var tuner: some View {
        VStack(spacing: 0) {
            Spacer()
            if showTuner {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text("Swing").font(.system(size: 12, weight: .semibold)).frame(width: 48, alignment: .leading)
                        Slider(value: $maxRotation, in: 0...90)
                        Text("\(Int(maxRotation))° max")
                            .font(.system(size: 12, design: .monospaced)).frame(width: 78, alignment: .trailing)
                    }
                    HStack(spacing: 10) {
                        Text("Blur").font(.system(size: 12, weight: .semibold)).frame(width: 48, alignment: .leading)
                        Slider(value: $endBlur, in: 0...48)
                        Text("\(Int(endBlur)) pt")
                            .font(.system(size: 12, design: .monospaced)).frame(width: 78, alignment: .trailing)
                    }
                    HStack(spacing: 10) {
                        Text("Dark").font(.system(size: 12, weight: .semibold)).frame(width: 48, alignment: .leading)
                        Slider(value: $darkStrength, in: 0...1)
                        Text("\(Int(darkStrength * 100))%")
                            .font(.system(size: 12, design: .monospaced)).frame(width: 78, alignment: .trailing)
                    }
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

    /// Left/right tilt (roll), exactly like the door experiment.
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

// MARK: - Progressive blur

/// Figma-style progressive (variable) layer blur: a Gaussian blur that ramps
/// linearly along an axis from `startBlur` at one end to `endBlur` at the
/// other. Built by stacking blurred copies of the content, each confined by a
/// gradient mask so heavier radii only surface toward the strong end — so it
/// reads as one smooth frosted ramp fixed over the content, not per-layer bands.
///
/// Figma reference: X 0% → 104%, Y 50% (horizontal), start blur 0, end blur 24.
struct ProgressiveBlur<Content: View>: View {
    /// The 0% end of the ramp — stays at `startBlur`.
    var axisStart: UnitPoint = .leading
    /// The 100% end of the ramp — reaches `endBlur`.
    var axisEnd: UnitPoint = .trailing
    var startBlur: CGFloat = 0
    var endBlur: CGFloat = 24
    /// Black scrim ramped along the SAME axis as the blur — clear at the sharp
    /// end, `tintStrength` opacity at the blurry end. 0 disables it.
    var tint: Color = .black
    var tintStrength: CGFloat = 0
    /// Where the scrim begins ramping up from clear (0 = sharp end, 1 = blurry
    /// end). Lower spreads the dark toward the sharp end. Default keeps the
    /// sharp third clean.
    var tintStart: CGFloat = 0.3
    /// How many blurred copies build the ramp. More = smoother, costlier.
    var layers: Int = 6
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content   // sharp base
            ForEach(1...max(layers, 1), id: \.self) { i in
                let t = CGFloat(i) / CGFloat(max(layers, 1))
                content
                    .blur(radius: startBlur + (endBlur - startBlur) * t)
                    .mask(rampMask(upTo: t))
                    .allowsHitTesting(false)
            }
            if tintStrength > 0 {
                LinearGradient(
                    stops: [
                        .init(color: tint.opacity(0), location: 0),
                        .init(color: tint.opacity(0), location: tintStart),
                        .init(color: tint.opacity(tintStrength), location: 1)
                    ],
                    startPoint: axisStart, endPoint: axisEnd
                )
                .allowsHitTesting(false)
            }
        }
    }

    /// This layer shows from `t` onward toward the strong end, fading in over
    /// the preceding `1/layers` so adjacent radii blend instead of banding.
    private func rampMask(upTo t: CGFloat) -> LinearGradient {
        let lower = max(0, t - 1.0 / CGFloat(max(layers, 1)))
        return LinearGradient(
            stops: [
                .init(color: .clear, location: lower),
                .init(color: .white, location: min(t, 1))
            ],
            startPoint: axisStart, endPoint: axisEnd
        )
    }
}

#Preview {
    iPhoneDuoView()
}
