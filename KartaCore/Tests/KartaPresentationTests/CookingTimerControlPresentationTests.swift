import Testing
import KartaCore
import KartaPresentation

@Suite("Cooking Temporizador control presentation")
struct CookingTimerControlPresentationTests {
    @Test("Actions project frozen pause, resumed progress, Reset and Stop on both Pasos")
    @MainActor
    func timerControls() throws {
        let recipe = Recipe(
            id: "sauce", name: "Tomato sauce", heroPhoto: .local("sauce"),
            totalMinutes: 15, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [], steps: [
                CookingStep(detail: "Simmer", timerSeconds: 720), "Serve",
            ], allergenReview: .reviewed([])
        )
        let clips = try TechniqueClipLibrary(clips: [])
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.pauseTimer(now: 280))

        let paused = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 1000))
        #expect(paused.timer?.state == .paused(remainingLabel: "9:00", fractionElapsed: 0.25))
        #expect(paused.timer?.endsAt == nil)
        #expect(paused.timerLabel == "9:00")
        store.send(.nextStep(now: 1000))
        let away = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 1200))
        #expect(away.progress[0].timer == .paused(remainingLabel: "9:00"))
        store.send(.previousStep)
        store.send(.resumeTimer(now: 1200))
        let resumed = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 1470))
        #expect(resumed.timer?.state == .running(remainingLabel: "4:30", fractionElapsed: 0.625))
        #expect(resumed.timer?.endsAt == 1740)
        store.send(.pauseTimer(now: 1470))
        store.send(.resetTimer)
        let ready = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 1500))
        #expect(ready.timer?.state == .ready(label: "12:00"))
        #expect(ready.timer?.endsAt == nil)
        store.send(.startTimer(now: 1500))
        let finished = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 2300))
        #expect(finished.timer?.state == .finished)
        store.send(.stopTimer(now: 2300))
        let stopped = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 2300))
        #expect(stopped.timer?.state == .ready(label: "12:00"))
        store.send(.nextStep(now: 2300))
        #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: 2300)?.progress[0].timer == nil)
    }
}
