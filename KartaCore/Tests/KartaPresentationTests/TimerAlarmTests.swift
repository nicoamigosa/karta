import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Temporizador alarm contract")
struct TimerAlarmTests {
    private let recipe = Recipe(
        id: "sauce", name: "Tomato sauce", heroPhoto: .local("sauce"),
        totalMinutes: 15, difficulty: .easy, servings: 2, primaryCourse: .dinner,
        ingredients: [], steps: [
            CookingStep(detail: "Simmer gently", summary: "Simmer", timerSeconds: 600),
            CookingStep(detail: "Rest off heat", summary: "Rest", timerSeconds: 120),
            CookingStep(detail: "Warm the bowls", summary: "Warm", timerSeconds: 60),
            CookingStep(detail: "Wait before serving", summary: "Wait", timerSeconds: 600),
        ], allergenReview: .reviewed([])
    )

    @Test("An indexed pause from another Paso updates its pill, alarm and snapshot at the press time")
    @MainActor
    func indexedPause() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        let clips = try TechniqueClipLibrary(clips: [])
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 200))
        store.send(.startTimer(now: 200))
        store.send(.nextStep(now: 210))
        #expect(store.state.timerAlarms(now: 400).map(\.state) == [.running(endsAt: 700), .finished])

        store.send(.pauseTimer(stepIndex: 1, now: 230))

        #expect(store.session?.currentIndex == 2)
        #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: 400)?
            .progress[1].timer == .paused(remainingLabel: "1:30"))
        #expect(store.state.timerAlarms(now: 400).map(\.state) == [.running(endsAt: 700), .paused(remaining: 90)])
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2), cookingSession: store.session
        )
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot?.cookingSession)
        #expect(restored == store.session)
        #expect(KartaState(session: restored, safetyProfile: SafetyProfile(intolerances: []))
            .timerAlarms(now: 400) == store.state.timerAlarms(now: 400))
    }

    @Test("Indexed resume and Stop from Cierre update only the named alarm and survive restoration")
    @MainActor
    func indexedResumeAndStop() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 200))
        store.send(.startTimer(now: 200))
        store.send(.pauseTimer(now: 230))
        store.send(.nextStep(now: 300))
        store.send(.nextStep(now: 400))
        store.send(.nextStep(now: 500))

        store.send(.resumeTimer(stepIndex: 1, now: 1000))
        #expect(store.session?.isOnFinish == true)
        #expect(store.session?.currentIndex == 3)
        #expect(store.cookingFinishPresentation(for: recipe, now: 1000)?
            .progress[1].timer == .running(remainingLabel: "1:30"))
        #expect(store.state.timerAlarms(now: 1000).map(\.state) == [.finished, .running(endsAt: 1090)])
        try expectSnapshotRoundTrip(store, now: 1000)

        store.send(.stopTimer(stepIndex: 1, now: 1090))
        #expect(store.session?.isOnFinish == true)
        #expect(store.session?.currentIndex == 3)
        #expect(store.cookingFinishPresentation(for: recipe, now: 1090)?.progress[1].timer == nil)
        #expect(store.state.timerAlarms(now: 1090).map(\.stepIndex) == [0])
        #expect(store.state.timerAlarms(now: 1090).map(\.state) == [.finished])
        #expect(store.session?.startedTimerSteps == [0, 1])
        #expect(store.state.cookHistory.count == 1)
        try expectSnapshotRoundTrip(store, now: 1090)

        store.send(.previousStep)
        store.send(.previousStep)
        store.send(.previousStep)
        let clips = try TechniqueClipLibrary(clips: [])
        #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: 1090)?
            .timer?.state == .ready(label: "2:00"))
    }

    @MainActor
    private func expectSnapshotRoundTrip(_ store: KartaStore, now: TimeInterval) throws {
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2), cookingSession: store.session
        )
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot?.cookingSession)
        #expect(restored == store.session)
        #expect(KartaState(session: restored, safetyProfile: SafetyProfile(intolerances: []))
            .timerAlarms(now: now) == store.state.timerAlarms(now: now))
    }

    @Test("The alarm list includes every active Paso in order, even away from the current Paso")
    @MainActor
    func allTimerStates() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        #expect(store.state.timerAlarms(now: 100).isEmpty)
        store.send(.startCooking(recipe, startedAt: 100))
        #expect(store.state.timerAlarms(now: 100).isEmpty)
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 200))
        store.send(.startTimer(now: 200))
        store.send(.pauseTimer(now: 230))
        store.send(.nextStep(now: 300))
        store.send(.startTimer(now: 300))
        store.send(.nextStep(now: 400))

        let alarms = store.state.timerAlarms(now: 400)
        #expect(alarms.map(\.recipeID) == ["sauce", "sauce", "sauce"])
        #expect(alarms.map(\.stepIndex) == [0, 1, 2])
        #expect(alarms.map(\.summary) == ["Simmer", "Rest", "Warm"])
        #expect(alarms.map(\.recipeName) == ["Tomato sauce", "Tomato sauce", "Tomato sauce"])
        #expect(alarms.map(\.state) == [.running(endsAt: 700), .paused(remaining: 90), .finished])

        store.send(.previousStep)
        store.send(.stopTimer(now: 400))
        #expect(store.state.timerAlarms(now: 400).map(\.stepIndex) == [0, 1])
        store.send(.previousStep)
        store.send(.resetTimer)
        #expect(store.state.timerAlarms(now: 400).map(\.stepIndex) == [0])
        #expect(store.state.timerAlarms(now: 400).map(\.state) == [.running(endsAt: 700)])
    }

    @Test("Pause and resume update one alarm; Reset, Stop and leaving remove alarms")
    @MainActor
    func alarmReconciliation() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.pauseTimer(now: 200))
        #expect(store.state.timerAlarms(now: 1000).map(\.state) == [.paused(remaining: 500)])
        store.send(.resumeTimer(now: 1000))
        #expect(store.state.timerAlarms(now: 1000).map(\.state) == [.running(endsAt: 1500)])
        store.send(.pauseTimer(now: 1100))
        store.send(.resetTimer)
        #expect(store.state.timerAlarms(now: 1100).isEmpty)
        store.send(.startTimer(now: 1200))
        #expect(store.state.timerAlarms(now: 1800).map(\.state) == [.finished])
        store.send(.stopTimer(now: 1800))
        #expect(store.state.timerAlarms(now: 1800).isEmpty)

        store.send(.startTimer(now: 2000))
        store.send(.nextStep(now: 2000))
        store.send(.startTimer(now: 2000))
        store.send(.pauseTimer(now: 2030))
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookingSession: store.session
        )
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot)
        let restoredState = KartaState(session: restored.cookingSession, safetyProfile: SafetyProfile(intolerances: []))
        #expect(restoredState.timerAlarms(now: 2100) == store.state.timerAlarms(now: 2100))
        store.send(.exitCooking)
        #expect(store.session?.timers.isEmpty == true)
        #expect(store.session?.startedTimerSteps == [0, 1])
        #expect(store.state.timerAlarms(now: 2100).isEmpty)
        let exited = UserSnapshot(profile: snapshot.profile, cookingSession: store.session)
        let restoredExit = try #require(UserSnapshot.restore(from: exited.encoded()).snapshot)
        #expect(restoredExit.cookingSession?.timers.isEmpty == true)
        #expect(KartaState(session: restoredExit.cookingSession, safetyProfile: SafetyProfile(intolerances: []))
            .timerAlarms(now: 2100).isEmpty)
    }

}
