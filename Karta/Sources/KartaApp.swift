import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// The app stays portrait; only the full-screen clip may rotate to
/// landscape (`ClipOrientationLock` unlocks it while it is up).
final class KartaAppDelegate: NSObject, UIApplicationDelegate {
    @MainActor
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        ClipOrientationLock.mask
    }
}

@main
struct KartaApp: App {
    @UIApplicationDelegateAdaptor(KartaAppDelegate.self)
    private var delegate
    @State private var store = DebugSeeds.store()

    var body: some Scene {
        WindowGroup {
            FeedScreen(store: store)
                .task { ClipOrientationLock.lockPortrait() }
        }
    }
}
