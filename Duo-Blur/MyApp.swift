import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // iPad renders the home-screen interface; iPhone runs the
            // single-screen pano fold directly.
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadDuoView()
            } else {
                iPhoneDuoView()
            }
        }
    }
}
