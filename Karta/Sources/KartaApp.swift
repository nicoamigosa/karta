import SwiftUI
import KartaCore
import KartaPresentation

@main
struct KartaApp: App {
    @State private var store = KartaStore(state: KartaState(
        safetyProfile: SafetyProfile(intolerances: [])
    ))

    var body: some Scene {
        WindowGroup {
            FeedScreen(store: store)
        }
    }
}
