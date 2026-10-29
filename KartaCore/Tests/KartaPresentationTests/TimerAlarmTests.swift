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
