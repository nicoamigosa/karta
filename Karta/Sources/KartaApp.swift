import SwiftUI
import KartaCore
import KartaPresentation

@main
struct KartaApp: App {
    @State private var store = DebugSeeds.store()

    var body: some Scene {
        WindowGroup {
            FeedScreen(store: store)
        }
    }
}
