import Testing
import KartaCore
import KartaPresentation

@Suite("Cooking step Temporizador presentation")
struct CookingStepTimerPresentationTests {
    private func recipe() -> Recipe {
        Recipe(
            id: "sauce", name: "Tomato sauce", heroPhoto: .local("sauce"),
            totalMinutes: 15, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [Ingredient(name: "Roma tomatoes", quantity: "2")],
            steps: [
                CookingStep(detail: "Use medium heat.", summary: "Simmer the sauce", timerSeconds: 720),
                CookingStep(detail: "Divide between bowls.", summary: "Serve"),
            ], allergenReview: .reviewed([])
        )
    }

    @Test("A running Temporizador exposes rounded remaining time, elapsed fraction and its end", arguments: [
        (100.0, "12:00", 0.0),
        (280.0, "9:00", 0.25),
        (460.0, "6:00", 0.5),
        (819.5, "0:01", 0.9993055555555556),
        (90.0, "12:10", 0.0),
    ])
    @MainActor
    func runningTimer(now: Double, label: String, fraction: Double) throws {
        let recipe = recipe()
        let clips = try TechniqueClipLibrary(clips: [])
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))

        let step = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: now))
        let timer = try #require(step.timer)
        #expect(timer.state == .running(remainingLabel: label, fractionElapsed: fraction))
        #expect(timer.endsAt == 820)
        #expect(step.timerLabel == label)
        #expect(step.progress[0].timer == nil)
    }

    @Test("A Temporizador is finished at zero and afterwards, retaining its end", arguments: [820.0, 900.0])
    @MainActor
    func finishedTimer(now: Double) throws {
        let recipe = recipe()
        let clips = try TechniqueClipLibrary(clips: [])
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))

        let step = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: now))
        let timer = try #require(step.timer)
        #expect(timer.state == .finished)
        #expect(timer.endsAt == 820)
        #expect(step.timerLabel == "0:00")
    }

    @Test("Returning to a Paso and repeating start keeps its original countdown")
    @MainActor
    func timerSurvivesNavigationAndRepeatedAction() throws {
        let recipe = recipe()
        let clips = try TechniqueClipLibrary(clips: [])
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 200))
        let away = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 460))
        #expect(away.timer == nil)
        #expect(away.progress[0].timer == .running(remainingLabel: "6:00"))

        store.send(.previousStep)
        store.send(.startTimer(now: 460))

        let back = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 460))
        #expect(back.timer?.state == .running(remainingLabel: "6:00", fractionElapsed: 0.5))
        #expect(back.timer?.endsAt == 820)
        #expect(back.progress[0].timer == nil)
    }

    @Test("A snapshot keeps the original Temporizador when returning from another Paso", arguments: [460.0, 820.0, 900.0])
    @MainActor
    func timerSurvivesSnapshot(now: Double) throws {
        let recipe = recipe()
        let clips = try TechniqueClipLibrary(clips: [])
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 200))
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookingSession: store.session
        )
        let restored = try #require(UserSnapshot.restore(
            from: snapshot.encoded(), now: now, catalog: [recipe]
        ).snapshot)
        let resumed = KartaStore(state: KartaState(
            session: restored.cookingSession, safetyProfile: SafetyProfile(intolerances: [])
        ))
        resumed.send(.previousStep)

        let step = try #require(resumed.cookingStepPresentation(for: recipe, clips: clips, now: now))
        let expected: CookingStepPresentation.Timer.State = now == 460
            ? .running(remainingLabel: "6:00", fractionElapsed: 0.5) : .finished
        #expect(step.timer?.state == expected)
        #expect(step.timer?.endsAt == 820)
        #expect(resumed.session?.timers[0]?.startedAt == 100)
    }

    @Test("Only a Paso declaring a Temporizador has a ready bottom zone")
    @MainActor
    func readyOrAbsent() throws {
        let recipe = recipe()
        let clips = try TechniqueClipLibrary(clips: [])
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))

        let first = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 200))
        let timer = try #require(first.timer)
        #expect(timer.state == .ready(label: "12:00"))
        #expect(timer.endsAt == nil)
        store.send(.nextStep(now: 200))
        let plain = try #require(store.cookingStepPresentation(for: recipe, clips: clips, now: 200))
        #expect(plain.timer == nil)
    }
}
