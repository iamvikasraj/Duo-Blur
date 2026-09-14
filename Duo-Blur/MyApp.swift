import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // iPad keeps the landscape Duo fold; iPhone runs the current
            // portrait experiment (door fold: PortraitFoldView, center-hinge
            // pano: HomeScreenPanoView).
            if UIDevice.current.userInterfaceIdiom == .pad {
                ContentView()
            } else {
                HomeScreenPanoView()
            }
        }
    }
}
