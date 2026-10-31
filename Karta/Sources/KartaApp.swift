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
    @State private var premium: PremiumController?

    var body: some Scene {
        WindowGroup {
            if let premium {
                FeedScreen(store: store, premium: premium)
                    .task { ClipOrientationLock.lockPortrait() }
            } else {
                // Reported entitlements arrive through the controller.
                ProgressView()
                    .tint(KartaDesign.ColorToken.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        let controller = PremiumController(store: store)
                        premium = controller
                        // Under a test host the app's own StoreKit calls would
                        // race the test's SKTestSession (a sign-in dialog even
                        // disableDialogs cannot dismiss blocks everything).
                        let isTestHost = NSClassFromString("XCTestCase") != nil
                            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                        if !isTestHost {
                            await controller.start()
                        }
                    }
            }
        }
    }
}
