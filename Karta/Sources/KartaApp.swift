import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

@main
struct KartaApp: App {
    @State private var store = DebugSeeds.store()

    var body: some Scene {
        WindowGroup {
            FeedScreen(store: store)
                // The cooking session stays portrait; only the full-screen
                // clip may rotate to landscape (ClipOrientationLock).
                .task { ClipOrientationLock.lockPortrait() }
        }
    }
}
