import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Picks the interface for the running device: iPad renders the home-screen
/// interface; iPhone runs the single-screen pano fold directly.
///
/// The choice keys off `userInterfaceIdiom`, so the `#Preview` below follows
/// whatever device you select in Xcode's canvas — pick an iPad to see the iPad
/// design, an iPhone to see the iPhone one.
struct RootView: View {
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadDuoView()
        } else {
            iPhoneDuoView()
        }
    }
}

#Preview {
    RootView()
}
