import Foundation
import Testing
@testable import KartaCore

@Suite("User snapshot")
struct UserSnapshotTests {

    @Test("A snapshot round-trips the persisted user state")
    func roundTripsPersistedState() throws {
        let firstViewDate = Date(timeIntervalSince1970: 1_000)
        let openingDate = Date(timeIntervalSince1970: 2_000)
        let cookDate = Date(timeIntervalSince1970: 3_000)
        let profile = OnboardingProfile(intolerances: [.dairy, .nuts], householdSize: 3)
        let cookbook = Cookbook(savedIDs: ["recipe-1", "recipe-2"], saveCap: 11)
        let history = ViewHistory(
            entries: [ViewEntry(recipeID: "recipe-1", date: firstViewDate)],
            openings: [OpenEntry(recipeID: "recipe-2", date: openingDate)]
        )
        let cookHistory = [CookEntry(recipeID: "recipe-1", date: cookDate, wasInferred: true)]
        let calibration = TasteCalibration(likedIDs: ["recipe-2", "recipe-1"])
        let snapshot = UserSnapshot(
            profile: profile,
            cookbook: cookbook,
            viewHistory: history,
            cookHistory: cookHistory,
            tasteCalibration: calibration
        )

        let restored = try #require(UserSnapshot.restore(from: try snapshot.encoded()).snapshot)

        #expect(restored == snapshot)
    }

    @Test("An older snapshot restores known fields and defaults missing sections")
    func restoresOlderVersionWithExplicitDefaults() throws {
        let olderData = Data(
            #"{"version":0,"profile":{"intolerances":["gluten"],"householdSize":2},"cookbook":{"savedIDs":["recipe-1"]}}"#.utf8
        )

        let result = UserSnapshot.restore(from: olderData)
        let snapshot = try #require(result.snapshot)

        #expect(result.wasRestored)
        #expect(result.preservedData == nil)
        #expect(snapshot.profile == OnboardingProfile(intolerances: [.gluten], householdSize: 2))
        #expect(snapshot.cookbook.savedIDs == ["recipe-1"])
        #expect(snapshot.cookbook.saveCap == Cookbook.freeSaveCap)
        #expect(snapshot.viewHistory == ViewHistory())
        #expect(snapshot.cookHistory.isEmpty)
        #expect(snapshot.tasteCalibration == TasteCalibration())
    }

    @Test("Unreadable snapshot data is preserved while restoration starts safely")
    func preservesUnreadableData() {
        let corruptData = Data("not-json".utf8)

        let result = UserSnapshot.restore(from: corruptData)

        #expect(result.wasRestored == false)
        #expect(result.snapshot == nil)
        #expect(result.preservedData == corruptData)
    }

    @Test("An unreadable snapshot does not present an empty-intolerance profile as completed onboarding")
    func requiresOnboardingAfterFailure() {
        let result = UserSnapshot.restore(from: Data("not-json".utf8))

        #expect(result.snapshot == nil)
    }

    @Test("A snapshot version that this app cannot understand is preserved")
    func preservesUnsupportedVersion() {
        let futureData = Data(#"{"version":2,"newField":{"meaning":"unknown"}}"#.utf8)

        let result = UserSnapshot.restore(from: futureData)

        #expect(result.wasRestored == false)
        #expect(result.snapshot == nil)
        #expect(result.preservedData == futureData)
    }

    @Test("Malformed session timer data is treated as unreadable")
    func preservesMalformedSessionData() {
        let malformedData = Data(
            #"{"version":1,"cookingSession":{"recipeID":"recipe-1","steps":[{"text":"Wait"}],"timers":[{"stepIndex":0,"startedAt":1,"duration":2},{"stepIndex":0,"startedAt":3,"duration":4}]}}"#.utf8
        )

        let result = UserSnapshot.restore(from: malformedData)

        #expect(result.wasRestored == false)
        #expect(result.snapshot == nil)
        #expect(result.preservedData == malformedData)
    }

    @Test("Restoring a cookbook deduplicates IDs without dropping orphaned saves")
    func preservesValidAndOrphanedSaves() throws {
        let data = Data(
            #"{"version":1,"profile":{"intolerances":[],"householdSize":1},"cookbook":{"savedIDs":["valid-1","missing-from-catalog","valid-1","valid-2"],"saveCap":4}}"#.utf8
        )

        let result = UserSnapshot.restore(from: data)
        let restored = try #require(result.snapshot)

        #expect(restored.cookbook.savedIDs == [
            "valid-1", "missing-from-catalog", "valid-2",
        ])
        #expect(restored.cookbook.saveCap == 4)
        #expect(result.preservedData == nil)
    }

    @Test("The snapshot does not persist session feed position or frontier")
    func excludesSessionFeedState() throws {
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 1)
        )

        let encoded = String(decoding: try snapshot.encoded(), as: UTF8.self)

        #expect(encoded.contains("feed") == false)
        #expect(encoded.contains("frontier") == false)
        #expect(encoded.contains("anchor") == false)
        #expect(encoded.contains("navigation") == false)
    }

    @Test("A half-finished cooking session round-trips its step and timers")
    func roundTripsCookingSession() throws {
        let steps = [
            CookingStep(text: "Chop", timerSeconds: 30),
            CookingStep(text: "Simmer", timerSeconds: 90),
        ]
        var session = CookingSession(recipeID: "recipe-1", steps: steps)
        session.startTimer(now: 100)
        session.next()
        session.startTimer(now: 110)
        session.inferProbablyCooked(dwellSeconds: 30)

        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookingSession: session
        )

        let restored = try #require(UserSnapshot.restore(from: try snapshot.encoded()).snapshot)

        #expect(restored.cookingSession == session)
    }
}
