# Duo‑Blur

A SwiftUI concept: an iPad home screen reimagined as the **inner display of a book‑fold device**. The screen stays flat — the "fold" is faked entirely on the screen *surface* with a progressive blur that sweeps in from the edge as you tilt the iPad, so the folding half frosts and recedes without ever showing an empty gap.

> Inspired by the foldable‑iPhone concept videos going around. This is a rendering/interaction study, not a real folding UI.

![Duo-Blur home screen](docs/duo-home.png)
<!-- Add your own screenshot/GIF at docs/duo-home.png -->

## How it works

- **The home screen never moves.** It's a static layout (`iPadDuoView`): widget cards, a 4×4 app‑icon grid, a Liquid Glass sidebar, and a wallpaper.
- **The fold is a screen‑surface effect.** `foldedCanvas` splits the screen at the centre crease. The left half is given a subtle 3D `rotation3DEffect`, and a **variable (progressive) blur + dark scrim** is layered over it. As the fold deepens, the frost sweeps from the outer edge toward the crease — leading the fold so the receding edge reads as frosted glass, not a void. The effect caps at `maxFold` (85%) and holds.
- **Motion drives it.** `MotionManager` reads the device's gravity vector via CoreMotion; `gyroFold()` maps the landscape roll (the device's long axis) to the fold amount. Tuning lives in a handful of named constants at the top of `iPadDuoView` (`maxBlur`, `darkStrength`, `leftFoldAngle`, `maxFold`, `gyroGain`, …).

### The variable blur

`VariableBlur` is a small `UIViewRepresentable` that reproduces iOS's own gradient blur — the frost you see behind the status bar, nav bars, and the keyboard — by attaching Core Animation's **`variableBlur` `CAFilter`** to a `UIVisualEffectView`'s backdrop layer, masked by an alpha ramp. It's a self‑contained component you can reuse in either direction (`fromRight`).

> ⚠️ **`CAFilter("variableBlur")` is a private API.** It's reached via `NSClassFromString` / `setValue(_:forKey:)`. It produces the authentic Apple look, but an app that ships it **will be rejected from the App Store.** This project is a concept/demo — swap in a public progressive‑blur implementation if you need to ship.

## Requirements

- **Xcode 26+**, Swift 5.9+
- **iOS 26+** target — the sidebar/dock and search button use **Liquid Glass** (`glassEffect`), with a material fallback on older systems.
- Built and tuned against **iPad Pro 11″ (M5), iOS 27** (the layout is measured for the 1194×834 landscape canvas).
- **A real device to feel the fold.** The fold is gyro‑driven; the **Simulator has no gyroscope, so it just shows the flat home screen.**

## Running it

1. Open `Duo-Blur.xcodeproj`.
2. Select the **Duo-Blur** scheme and an **iPad** destination (a physical iPad to see the fold react to tilt).
3. Run. Tilt the iPad and the left half frosts and folds away.

## Project layout

| File | What it does |
|------|--------------|
| `iPad-Duo.swift` | The whole experience — `iPadDuoView` (layout + fold), `VariableBlur` (the progressive‑blur component), and small `Color(hex:)` / Liquid Glass helpers. |
| `MotionManager.swift` | CoreMotion wrapper exposing a smoothed, normalized tilt (`gx`, `gy`). |
| `MyApp.swift` | App entry point. |

## Assets & trademarks

This is a **concept / fan project and is not affiliated with, endorsed by, or sponsored by Apple Inc.** The bundled app icons, widget mockups, and wallpaper resemble Apple artwork and are included **for demonstration only**; **Apple**, **iPadOS**, the app icons, and all related names and logos are trademarks of Apple Inc. Replace the assets in `Assets.xcassets` with your own before using this beyond experimentation.

## License

The **source code** is released under the [MIT License](LICENSE). The license covers the code only — not the third‑party artwork described above.
