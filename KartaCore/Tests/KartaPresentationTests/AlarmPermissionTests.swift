import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Alarm permission")
struct AlarmPermissionTests {
    @Test("Denial explains alarms once and never prevents the Temporizador from running")
    @MainActor
    func deniedOnce() {
        let recipe = Recipe(
            id: "sauce", name: "Tomato sauce", heroPhoto: .local("sauce"),
            totalMinutes: 15, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [], steps: [CookingStep(detail: "Simmer", timerSeconds: 600)],
            allergenReview: .reviewed([])
        )
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        #expect(!store.state.showsAlarmPermissionSheet)
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        #expect(!store.state.showsAlarmPermissionSheet)
        store.send(.alarmPermissionDenied)
        #expect(store.state.showsAlarmPermissionSheet)
        #expect(store.state.hasShownAlarmPermissionSheet)
        #expect(store.state.timerAlarms(now: 200).map(\.state) == [.running(endsAt: 700)])
        store.send(.dismissAlarmPermissionSheet)
        #expect(!store.state.showsAlarmPermissionSheet)
        store.send(.alarmPermissionDenied)
        #expect(!store.state.showsAlarmPermissionSheet)
        store.send(.exitCooking)
        store.send(.startCooking(recipe, startedAt: 1000))
        store.send(.startTimer(now: 1000))
        store.send(.alarmPermissionDenied)
        #expect(!store.state.showsAlarmPermissionSheet)
    }
    @Test("An explanation already shown stays dismissed after restoring a snapshot")
    @MainActor
    func permissionRoundTrip() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.alarmPermissionDenied)
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            hasShownAlarmPermissionSheet: store.state.hasShownAlarmPermissionSheet
        )
        // Persist while the sheet is open: visibility itself must not restore.
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot)
        #expect(restored.hasShownAlarmPermissionSheet)
        let relaunched = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: []),
            hasShownAlarmPermissionSheet: restored.hasShownAlarmPermissionSheet
        ))
        #expect(!relaunched.state.showsAlarmPermissionSheet)
        relaunched.send(.alarmPermissionDenied)
        #expect(!relaunched.state.showsAlarmPermissionSheet)
        store.send(.dismissAlarmPermissionSheet)
        let dismissed = UserSnapshot(
            profile: snapshot.profile,
            hasShownAlarmPermissionSheet: store.state.hasShownAlarmPermissionSheet
        )
        #expect(try #require(UserSnapshot.restore(from: dismissed.encoded()).snapshot)
            .hasShownAlarmPermissionSheet)
    }

    @Test("An old snapshot without the permission fact allows the explanation once")
    @MainActor
    func legacyPermissionSnapshot() throws {
        let data = Data(#"""
        {"version":1,"profile":{"intolerances":[],"householdSize":2}}
        """#.utf8)
        let snapshot = try #require(UserSnapshot.restore(from: data).snapshot)
        #expect(!snapshot.hasShownAlarmPermissionSheet)
        let store = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: []),
            hasShownAlarmPermissionSheet: snapshot.hasShownAlarmPermissionSheet
        ))
        store.send(.alarmPermissionDenied)
        #expect(store.state.showsAlarmPermissionSheet)
        store.send(.dismissAlarmPermissionSheet)
        store.send(.alarmPermissionDenied)
        #expect(!store.state.showsAlarmPermissionSheet)
    }

}
