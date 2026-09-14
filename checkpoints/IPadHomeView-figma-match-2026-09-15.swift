import SwiftUI

/// iPad "Duo Home" — a faithful rebuild of the Figma reference (node 61:10).
/// The design is a color-blocked skeleton: solid-color app tiles with labels
/// (no glyphs), placeholder widget cards, a solid-tile dock, and the dune
/// wallpaper. Laid out on a fixed 1194×834 design canvas and scaled to the
/// device so positions stay pixel-accurate to Figma.
///
/// The wallpaper here is an ORIGINAL gradient approximation, not the copyrighted
/// dune photo — drop a licensed asset into `Wallpaper` to match exactly.
struct IPadHomeView: View {
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

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / design.width, geo.size.height / design.height)
            canvas
                .frame(width: design.width, height: design.height)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            Wallpaper().frame(width: design.width, height: design.height)

            // Widgets (user-provided images) -------------------------------
            imageWidget("music",    x: 90,  y: 66,  w: 420, h: 198, radius: 30, label: "Music")
            imageWidget("weather",  x: 584, y: 66,  w: 200, h: 198, radius: 30, label: "Weather")
            imageWidget("find my",  x: 804, y: 66,  w: 200, h: 198, radius: 30, label: "Find My")
            imageWidget("Calendar", x: 90,  y: 308, w: 420, h: 444, radius: 34, label: "Calendar")

            // App grid -----------------------------------------------------
            ForEach(0..<grid.count, id: \.self) { r in
                ForEach(0..<grid[r].count, id: \.self) { c in
                    appTile(grid[r][c].0, hex: grid[r][c].1, x: colX[c], y: rowY[r])
                }
            }

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
    IPadHomeView()
}
