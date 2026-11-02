import Foundation
import Testing
import CoreGraphics
import KartaCore
import KartaPresentation
@testable import Karta

/// The shell's half of #172: the store drives the tour and the panel; the
/// views only send the actions pinned here — cold launch once, delay, taps,
/// Set mine, the two first-run answers and Show my cards.
@Suite("First open and onboarding")
struct OnboardingFlowTests {
    @MainActor
    private func freshStore() -> KartaStore {
        // Unanswered: the Baraja segura profile stands at all five.
        KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: Set(Allergen.allCases))
        ))
    }

    // MARK: - The tour

    @MainActor
    @Test("Cold launch starts the full tour; each 1.2 s delay advances it")
    func tourDelaysAdvance() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        #expect(store.state.onboarding.tourStop == .cookbook)
        #expect(store.state.onboarding.tourSkipLine != nil)

        store.send(.onboarding(.tourDelayElapsed))
        #expect(store.state.onboarding.tourStop == .world)
        store.send(.onboarding(.tourDelayElapsed))
        #expect(store.state.onboarding.tourStop == .filters)
        #expect(store.state.onboarding.tourSkipLine == nil)
        #expect(store.state.onboarding.pulsesFilter)
    }

    @MainActor
    @Test("A tap during stops 1–2 skips to the filter; a tap at stop 3 ends")
    func tourTapSkipsAndEnds() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))

        store.send(.onboarding(.tourTap))
        #expect(store.state.onboarding.tourStop == .filters)

        store.send(.onboarding(.tourTap))
        #expect(store.state.onboarding.tourStop == nil)
        #expect(store.state.onboarding.banner != nil)
    }

    @MainActor
    @Test("The scrim's tap routing: outside the button ends, on it opens")
    func tourTapRouting() {
        let hole = CGRect(x: 100, y: 100, width: 52, height: 52)
        func isTap(_ action: OnboardingAction) -> Bool {
            if case .tourTap = action { return true } else { return false }
        }
        func isFilter(_ action: OnboardingAction) -> Bool {
            if case .filterButtonTapped = action { return true } else { return false }
        }
        #expect(isTap(TourInput.action(
            stop: .cookbook, at: CGPoint(x: 10, y: 10), filterHole: hole
        )))
        #expect(isTap(TourInput.action(
            stop: .filters, at: CGPoint(x: 10, y: 10), filterHole: hole
        )))
        #expect(isFilter(TourInput.action(
            stop: .filters, at: CGPoint(x: 126, y: 126), filterHole: hole
        )))
    }

    @MainActor
    @Test("Stop 3 stays: the filter button opens the first-run panel")
    func stopThreeOpensPanel() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.onboarding(.tourTap))
        store.send(.onboarding(.filterButtonTapped))
        #expect(store.state.onboarding.tourStop == nil)
        #expect(store.state.onboarding.panel == .firstRun)
    }

    @MainActor
    @Test("A later cold launch while unanswered shows stop 3 alone")
    func laterLaunchShowsStopThree() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        #expect(store.state.onboarding.hasShownFullTour)
        // Simulate the relaunch on a fresh store built from the snapshot.
        let snapshot = store.state.userSnapshot
        let relaunched = KartaStore(state: KartaState(snapshot: snapshot))
        relaunched.send(.onboarding(.coldLaunch(reduceMotion: false)))
        #expect(relaunched.state.onboarding.tourStop == .filters)
    }

    @MainActor
    @Test("Reduce Motion shows stop 3 alone, with no pulse")
    func reduceMotionTour() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: true)))
        #expect(store.state.onboarding.tourStop == .filters)
        #expect(!store.state.onboarding.pulsesFilter)
        #expect(store.state.onboarding.tourSkipLine == nil)
    }

    @MainActor
    @Test("Once answered, the tour never shows again")
    func answeredSkipsTour() {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]), householdSize: 2,
                hasShownFullTour: true
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        #expect(store.state.onboarding.tourStop == nil)
    }

    // MARK: - Banner

    @MainActor
    @Test("Set mine opens the first-run panel and keeps the banner")
    func bannerSetMine() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.onboarding(.tourTap))
        store.send(.onboarding(.tourTap))
        store.send(.onboarding(.setMine))
        #expect(store.state.onboarding.panel == .firstRun)
        #expect(store.state.onboarding.banner != nil)
    }

    // MARK: - First-run panel

    @MainActor
    @Test("Show my cards stays off until a Hogar is chosen, then commits")
    func showMyCardsFlow() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.onboarding(.setMine))
        let panel = store.state.onboarding.firstRunPanel
        #expect(!panel.canShowCards)
        // The disabled look: tapping Show my cards does nothing yet.
        store.send(.onboarding(.showMyCards))
        #expect(store.state.onboarding.panel == .firstRun)
        #expect(store.state.onboarding.banner != nil)

        store.send(.onboarding(.toggleFirstRunAllergen(.dairy)))
        #expect(store.state.onboarding.firstRunPanel.intolerances == [.dairy])
        #expect(store.state.onboarding.firstRunPanel.intoleranceLine
            == "Dairy will never show up. Change it anytime here.")

        store.send(.onboarding(.chooseFirstRunHousehold(4)))
        #expect(store.state.onboarding.firstRunPanel.canShowCards)

        store.send(.onboarding(.showMyCards))
        #expect(store.state.onboarding.panel == nil)
        #expect(store.state.onboarding.banner == nil)
        #expect(store.state.safetyProfile.intolerances == [.dairy])
        #expect(store.state.onboarding.householdSize == 4)
        #expect(store.state.onboarding.intoleranceAnswer == .answered([.dairy]))
    }

    @MainActor
    @Test("An empty set is the answer 'none'")
    func noneAnswered() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.onboarding(.setMine))
        store.send(.onboarding(.chooseFirstRunHousehold(2)))
        #expect(store.state.onboarding.firstRunPanel.intoleranceLine
            == "Nothing hidden: you eat all five. Change it anytime here.")
        store.send(.onboarding(.showMyCards))
        #expect(store.state.onboarding.intoleranceAnswer == .answered([]))
        #expect(store.state.safetyProfile.intolerances.isEmpty)
    }

    @MainActor
    @Test("Closing without answering keeps the taps until the app quits")
    func closeKeepsTaps() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.onboarding(.setMine))
        store.send(.onboarding(.toggleFirstRunAllergen(.dairy)))
        store.send(.onboarding(.chooseFirstRunHousehold(3)))
        store.send(.onboarding(.closePanel))
        #expect(store.state.onboarding.panel == nil)
        #expect(store.state.onboarding.banner != nil)
        #expect(store.state.onboarding.intoleranceAnswer == .unanswered)
        // Reopening shows the same session edits, still unsaved.
        store.send(.onboarding(.filterButtonTapped))
        #expect(store.state.onboarding.panel == .firstRun)
        #expect(store.state.onboarding.firstRunPanel.intolerances == [.dairy])
        #expect(store.state.onboarding.firstRunPanel.householdSize == 3)
        #expect(store.state.onboarding.intoleranceAnswer == .unanswered)
    }

    @MainActor
    @Test("Show my cards restarts the feed at the top")
    func showMyCardsResetsAnchors() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        // A real anchor down the deck: the answer has to discard it.
        store.send(.setFeedAnchor(
            ScrollAnchor(recipeID: "pesto-pasta", relativeOffset: 0.5),
            world: .forYou
        ))
        #expect(store.state.navigation.anchor(for: .forYou) != nil)

        store.send(.onboarding(.setMine))
        store.send(.onboarding(.chooseFirstRunHousehold(1)))
        store.send(.onboarding(.showMyCards))
        // Anchors discarded in the same action that saves the answers.
        #expect(store.state.navigation.anchor(for: .forYou) == nil)
    }

    // MARK: - Persistence

    @MainActor
    @Test("The snapshot round-trips the tour flag and the answers")
    func snapshotRoundTrip() {
        let store = freshStore()
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.onboarding(.setMine))
        store.send(.onboarding(.toggleFirstRunAllergen(.egg)))
        store.send(.onboarding(.chooseFirstRunHousehold(5)))
        store.send(.onboarding(.showMyCards))

        guard let data = try? store.state.userSnapshot.encoded() else {
            Issue.record("userSnapshot failed to encode")
            return
        }
        let result = UserSnapshot.restore(
            from: data, now: Date().timeIntervalSince1970, catalog: [])
        #expect(result.wasRestored)
        let restored = KartaStore(state: KartaState(snapshot: result.snapshot!))
        #expect(restored.state.onboarding.hasShownFullTour)
        #expect(restored.state.onboarding.intoleranceAnswer == .answered([.egg]))
        #expect(restored.state.onboarding.householdSize == 5)
        // And the tour stays silent on relaunch once answered.
        restored.send(.onboarding(.coldLaunch(reduceMotion: false)))
        #expect(restored.state.onboarding.tourStop == nil)
    }

    @MainActor
    @Test("Unreadable bytes are preserved, never replaced")
    func preservedBytes() throws {
        let files = FileManager.default
        let dir = files.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try files.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: dir) }

        let previous = UserSnapshotStorage.directoryURL
        UserSnapshotStorage.directoryURL = dir
        defer { UserSnapshotStorage.directoryURL = previous }

        let garbage = Data([0xFF, 0x00, 0x42])
        try garbage.write(to: UserSnapshotStorage.fileURL)

        // First unreadable restore: the file moves aside, never deleted.
        #expect(UserSnapshotStorage.restoreState(catalog: []) == nil)
        #expect(try Data(contentsOf: UserSnapshotStorage.preservedURL) == garbage)
        #expect(!files.fileExists(atPath: UserSnapshotStorage.fileURL.path))

        // A second unreadable file gets its own name — an existing
        // `*.preserved` never makes a copy fail (ADR 0010).
        let garbage2 = Data([0xDE, 0xAD])
        try garbage2.write(to: UserSnapshotStorage.fileURL)
        #expect(UserSnapshotStorage.restoreState(catalog: []) == nil)
        let second = dir.appending(path: "user-snapshot-2.preserved")
        #expect(try Data(contentsOf: second) == garbage2)
        #expect(try Data(contentsOf: UserSnapshotStorage.preservedURL) == garbage)
    }
}
