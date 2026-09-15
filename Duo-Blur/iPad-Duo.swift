import SwiftUI
import UIKit

/// iPad "Duo" — the home screen as the inner display of a book-fold device.
/// The home screen stays FLAT and intact; the fold is told on the screen
/// SURFACE. A screen-space variable blur (iOS's own `CAFilter("variableBlur")`)
/// plus a dark scrim frosts the left of the display, and its coverage SWEEPS
/// from the left edge inward as the device folds — the frost front leads the
/// fold so the receding edge never reads as empty, reaching the centre crease
/// at ~45° and then just deepening. On the Simulator (no gyro) drag
/// horizontally to fold; the slider glyph tunes blur / dark / reach.
///
/// The home itself is a faithful rebuild of the Figma reference (node 61:10):
/// a color-blocked skeleton — solid-color app tiles with labels (no glyphs),
/// image widget cards, a Liquid Glass dock, and the dune wallpaper.
///
/// The wallpaper here is an ORIGINAL gradient approximation, not the copyrighted
/// dune photo — drop a licensed asset into `Wallpaper` to match exactly.
struct iPadDuoView: View {
    private let design = CGSize(width: 1194, height: 834)

    // Grid geometry measured from the Figma render.
    private let colX: [CGFloat] = [590, 700, 811, 921]   // icon left edges
    private let rowY: [CGFloat] = [309, 430, 551, 672]    // icon top edges
    private let icon: CGFloat = 75

    // Rows of (label, hex) — solid tile colours sampled from the render.
    private let grid: [[(String, String)]] = [
        [("FaceTime", "62DE76"), ("Calendar", "C5C0B9"), ("App Store", "0088E5"), ("Camera", "D2CDCE")],
        [("Mail", "009DE7"),     ("Notes", "EACD2B"),    ("Clock", "EEECED"),     ("Maps", "00D458")],
        [("News", "F90058"),     ("Tv", "2C2E35"),       ("Games", "FC263B"),     ("Photos", "EFEEEC")],
        [("Health", "FC0068"),   ("Wallet", "292A30"),   ("Siri", "91898A"),      ("Settings", "A29DA1")]
    ]

    // MARK: Fold state

    @State private var motion = MotionManager()

    // Simulator fallback (no gyro): drag horizontally to fold; springs back to 0.
    @State private var isDragging = false
    @State private var dragFold = 0.0
    @State private var releaseAt: Date?     // when the drag was released (drives spring-back)
    @State private var releaseFold = 0.0    // the fold value at release

    // Live tuners (tap the slider glyph, bottom-right).
    @State private var showTuner = false
    @State private var manualFold = 0.0            // the single Fold slider (0…1); overrides drag/gyro when > 0

    // Baked-in tuning (blur/dark shared with iPhone-Duo).
    private let maxBlur: Double = 55        // max variable-blur radius (pt) at full fold
    private let darkStrength: Double = 0.60 // max scrim opacity at the outer edge
    private let sweepAt: Double = 0.5       // fold fraction at which the frost front reaches centre (~45°)
    private let gridSlide: Double = 24      // how far the icon grid nudges right at full fold, pt
    private let leftFoldAngle: Double = 35  // left panel's half-fold about the crease, degrees
    private let gyroGain: Double = 1.6      // gyro sensitivity + direction (signed): tilt → fold

    var body: some View {
        GeometryReader { geo in
            // Fill the screen (cover), not fit — otherwise the 1194-wide canvas
            // letterboxes inside the 1210-wide 11" display, leaving a sharp gutter
            // beside the frosted edge. Cover trims a few px of bleed instead.
            let scale = max(geo.size.width / design.width, geo.size.height / design.height)
            ZStack {
                TimelineView(.animation) { timeline in
                    let fold = currentFold(at: timeline.date)
                    foldedCanvas(fold: fold)
                        .frame(width: design.width, height: design.height)
                        .scaleEffect(scale)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)   // visuals don't capture touches

                // Fold-drag layer — a stable clear layer that sits BELOW the
                // tuner, so the tuner's sliders receive their own touches instead
                // of the drag folding the screen.
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

    // MARK: Fold assembly

    /// The home screen stays flat and intact; the fold is told on the SCREEN
    /// SURFACE. The screen splits at the centre crease: the LEFT panel half-folds
    /// away while the RIGHT stays flat. A screen-space variable blur + dark scrim
    /// (clipped to the left half) frosts the folding panel and sweeps toward the
    /// crease; the right-hand group (widgets + grid) nudges right. `fold` is 0
    /// (open, sharp) … 1 (fully folded).
    private func foldedCanvas(fold: Double) -> some View {
        let f = min(max(fold, 0), 1)
        let bite = pow(f, 0.4)
        let front = CGFloat(min(f / max(sweepAt, 0.05), 1) * 0.44)
        let radius = CGFloat(maxBlur * bite)
        let dark = CGFloat(darkStrength * bite)
        let slide = CGFloat(gridSlide) * CGFloat(f)   // the icon grid nudges right with the fold
        let angle = leftFoldAngle * f                 // the left panel's half-fold
        return ZStack(alignment: .topLeading) {
            // Dim, out-of-focus backdrop so the area the left panel vacates as it
            // folds never reads as pure black.
            Wallpaper()
                .frame(width: design.width, height: design.height)
                .blur(radius: 60, opaque: true)
                .overlay(Color.black.opacity(0.45))

            // Split at the centre crease: the LEFT panel half-folds away about
            // the crease; the RIGHT panel stays flat, facing the viewer.
            HStack(spacing: 0) {
                leaf(.left, gridShiftX: slide)
                    .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0),
                                      anchor: .trailing, perspective: 0.55)
                leaf(.right, gridShiftX: slide)
            }
            .frame(width: design.width, height: design.height)

            // Screen-surface frost over the folded (left) panel — clipped to the
            // left half so the right (flat) panel is never under the effect
            // layer. Omitted at rest. `front` is a full-width fraction, so it
            // doubles to the half-width view's space.
            if radius > 0.5 {
                VariableBlur(maxBlurRadius: radius, front: min(front * 2, 1))
                    .frame(width: design.width / 2, height: design.height)
                    .allowsHitTesting(false)
            }

            // Dark scrim over the frosted band, heaviest at the outer (left) edge.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(dark), location: 0),
                    .init(color: .black.opacity(dark * 0.55), location: front * 0.55),
                    .init(color: .clear, location: max(front, 0.001))
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .allowsHitTesting(false)
        }
        .frame(width: design.width, height: design.height, alignment: .topLeading)
    }

    private enum Leaf { case left, right }

    /// Half of the home screen, clipped at the centre crease. Rendered from the
    /// full canvas so the halves line up seamlessly when the fold is flat.
    private func leaf(_ side: Leaf, gridShiftX: CGFloat) -> some View {
        canvas(gridShiftX: gridShiftX)
            .frame(width: design.width / 2, height: design.height,
                   alignment: side == .left ? .leading : .trailing)
            .clipped()
    }

    // MARK: Fold source

    /// Fold amount 0…1. Gyro roll when a device is present; otherwise the drag,
    /// which springs back to 0 (the default, unfolded state) once released — so
    /// the resting state is always the clean home screen. Only folds one way.
    private func currentFold(at date: Date) -> Double {
        if isDragging { return dragFold }          // an active drag always wins (and lets the Simulator drive it)
        if manualFold > 0.001 { return manualFold }// the single Fold slider (set it to 0 to hand control to the gyro)
        if motion.isUsingGyro { return gyroFold() }
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

    /// Gyro-driven fold for the LANDSCAPE iPad. Screen-space roll maps to the
    /// device's LONG axis (`gy`), not `gx` (that's the portrait iPhone's roll).
    /// The two landscape orientations are mirror images, so `landscapeLeft` flips
    /// the sign; `gyroGain` (signed) sets overall sensitivity and direction. A
    /// small deadzone keeps a level iPad at the clean, unfolded default.
    private func gyroFold() -> Double {
        let roll = (interfaceOrientation == .landscapeLeft) ? -motion.gy : motion.gy
        return min(max(roll * gyroGain - 0.03, 0), 1)
    }

    private var interfaceOrientation: UIInterfaceOrientation {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
    }

    /// Simulator fold control: drag horizontally to fold; on release it springs
    /// back to the default unfolded state (a stand-in for the gyro settling flat).
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

    // MARK: Tuner overlay

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

    /// The home screen. `gridShiftX` nudges the RIGHT-hand group — the Weather
    /// and Find My widgets plus the app icon grid — to the right together; the
    /// left widgets (Music, Calendar) and everything else stay put.
    private func canvas(gridShiftX: CGFloat = 0) -> some View {
        ZStack(alignment: .topLeading) {
            Wallpaper().frame(width: design.width, height: design.height)

            // Left-panel widgets — hold (they fold with the left panel).
            imageWidget("music",    x: 90,  y: 66,  w: 420, h: 198, radius: 30, label: "Music")
            imageWidget("Calendar", x: 90,  y: 308, w: 420, h: 444, radius: 34, label: "Calendar")

            // Right-hand group — the two top widgets + the app icon grid —
            // nudges right together with the fold.
            ZStack(alignment: .topLeading) {
                imageWidget("weather", x: 584, y: 66, w: 200, h: 198, radius: 30, label: "Weather")
                imageWidget("find my", x: 804, y: 66, w: 200, h: 198, radius: 30, label: "Find My")
                ForEach(0..<grid.count, id: \.self) { r in
                    ForEach(0..<grid[r].count, id: \.self) { c in
                        appTile(grid[r][c].0, hex: grid[r][c].1, x: colX[c], y: rowY[r])
                    }
                }
            }
            .frame(width: design.width, height: design.height, alignment: .topLeading)
            .offset(x: gridShiftX)   // springs with the fold (the fold itself springs back on release)

            // Dock + chrome ------------------------------------------------
            statusGlyph
            dock
            searchButton
        }
        .frame(width: design.width, height: design.height, alignment: .topLeading)
    }

    // MARK: Widgets

    /// A widget rendered from a user-provided image, clipped to a rounded card
    /// with a caption underneath.
    private func imageWidget(_ name: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                             radius: CGFloat, label: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .position(x: x + w / 2, y: y + h / 2)
            .overlay(caption(label, cx: x + w / 2, cy: y + h + 14))
    }

    private func caption(_ text: String, cx: CGFloat, cy: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 2)
            .position(x: cx, y: cy)
    }

    // MARK: App tile

    private func appTile(_ label: String, hex: String, x: CGFloat, y: CGFloat) -> some View {
        Group {
            RoundedRectangle(cornerRadius: icon * 0.2237, style: .continuous)
                .fill(Color(hex: hex))
                .frame(width: icon, height: icon)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                .position(x: x + icon / 2, y: y + icon / 2)
            caption(label, cx: x + icon / 2, cy: y + icon + 15)
        }
    }

    // MARK: Dock

    private var dock: some View {
        let tile: CGFloat = 60
        let hexes = ["39DB61", "EFEDEE", "64DE76", "FC0058"]
        // Content INSIDE the glass (idiomatic Liquid Glass), positioned by centre.
        return VStack(spacing: 19) {
            ForEach(0..<hexes.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: hexes[i]))
                    .frame(width: tile, height: tile)
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            }
        }
        .padding(14)
        .liquidGlass(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .position(x: 1132, y: 429.5)
    }

    // MARK: Chrome (status glyph + search circle)

    private var statusGlyph: some View {
        VStack(spacing: 2) {
            Text("9:41")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Image("wifi-glyph")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
        }
        .shadow(color: .black.opacity(0.2), radius: 2)
        .position(x: 1137, y: 86)
    }

    private var searchButton: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 56, height: 56)
            .liquidGlass(Circle())
            .position(x: 1133, y: 774)
    }

}

// MARK: - Wallpaper

private struct Wallpaper: View {
    var body: some View {
        Image("iPhone-Duo-wallpaper-Apple")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }
}

// MARK: - Screen-space variable blur

/// A SwiftUI wrapper over UIKit's variable (progressive) blur — the same
/// private `CAFilter("variableBlur")` iOS uses for its own gradient blurs (the
/// frost behind the status bar, nav bars, the keyboard). It frosts its BACKDROP
/// (whatever sits behind it in the ZStack). The blur is full `maxBlurRadius` at
/// the LEFT edge and tapers to sharp by `front` (0 … 1 across the width), so
/// moving `front` sweeps the frost horizontally across the screen.
struct VariableBlur: UIViewRepresentable {
    var maxBlurRadius: CGFloat
    var front: CGFloat
    var fromRight: Bool = false   // mirror the ramp so the frost is heaviest on the RIGHT edge

    func makeUIView(context: Context) -> VariableBlurUIView { VariableBlurUIView() }

    func updateUIView(_ view: VariableBlurUIView, context: Context) {
        view.update(maxBlurRadius: maxBlurRadius, mask: Self.mask(front: front, fromRight: fromRight))
    }

    /// A white ramp whose ALPHA (what `variableBlur` reads) is opaque = full blur
    /// at the free edge and fades to transparent = sharp by `front`. Two rows,
    /// stretched over the layer → a purely horizontal sweep. `fromRight` mirrors
    /// it so the heavy edge is the right instead of the left.
    static func mask(front: CGFloat, fromRight: Bool = false, width: Int = 512) -> CGImage? {
        let f = Double(min(max(front, 0.004), 1))
        let height = 2
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for x in 0..<width {
            let t = Double(x) / Double(width - 1)
            let u = fromRight ? (1 - t) : t   // distance from the heavy (free) edge
            // Heavy at the free edge, easing to 0 at the front; powered for a soft tail.
            let a = u < f ? pow(1 - u / f, 1.6) : 0
            let v = UInt8(max(0, min(1, a)) * 255)   // premultiplied white → RGB == A
            for y in 0..<height {
                let i = (y * width + x) * 4
                bytes[i] = v; bytes[i + 1] = v; bytes[i + 2] = v; bytes[i + 3] = v
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: cs,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}

/// UIVisualEffectView whose backdrop layer carries the variable-blur filter.
final class VariableBlurUIView: UIVisualEffectView {
    private var lastRadius: CGFloat = 0
    private var lastMask: CGImage?

    init() {
        super.init(effect: UIBlurEffect(style: .regular))
        // Drop the tint/vibrancy the effect adds — we want only the blur.
        subviews.dropFirst().forEach { $0.alpha = 0 }
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(maxBlurRadius: CGFloat, mask: CGImage?) {
        lastRadius = maxBlurRadius
        lastMask = mask
        applyFilter()
    }

    // The system can drop `layer.filters` when the view changes windows — reassert.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFilter()
    }

    private func applyFilter() {
        guard let backdrop = subviews.first?.layer, let mask = lastMask else { return }
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let filter = filterClass
                .perform(NSSelectorFromString("filterWithType:"), with: "variableBlur")?
                .takeUnretainedValue() as? NSObject
        else { return }
        filter.setValue(NSNumber(value: Double(lastRadius)), forKey: "inputRadius")
        filter.setValue(mask, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        backdrop.filters = [filter]
    }
}

// MARK: - Liquid Glass helper

extension View {
    /// Applies iOS 26 Liquid Glass in the given shape, falling back to a
    /// material on older systems.
    @ViewBuilder
    func liquidGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Hex color helper

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

#Preview {
    iPadDuoView()
}
