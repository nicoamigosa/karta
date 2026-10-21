import Testing
import KartaCore
import KartaPresentation

@Suite("Cooking step presentation")
struct CookingStepPresentationTests {
    private func recipe(review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(
            id: "sauce", name: "Tomato sauce", heroPhoto: .local("sauce"),
            totalMinutes: 15, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [
                Ingredient(id: "tomato", name: "Roma tomatoes", quantity: "2"),
                Ingredient(id: "salt", name: "Kosher salt", quantity: "1 tsp"),
                Ingredient(id: "butter", name: "Unsalted butter", quantity: "1 tbsp",
                           isOptional: true, allergens: [.dairy]),
            ],
            steps: [
                CookingStep(detail: "Use medium heat.", summary: "Simmer the sauce", ingredients: [
                    StepIngredient(ingredientID: "salt", quantity: "1/2 tsp"),
                    StepIngredient(ingredientID: "tomato", quantity: "2"),
                ], timerSeconds: 720, clipID: "simmer", photo: .local("simmer")),
                CookingStep(detail: "Stir until melted.", summary: "Add butter", ingredients: [
                    StepIngredient(ingredientID: "butter", quantity: "1 tbsp"),
                ], timerSeconds: 60, isOptional: true, photo: .relative("steps/butter.jpg")),
                CookingStep(detail: "Divide between bowls.", summary: "Serve"),
            ], allergenReview: review
        )
    }

    private func clips() throws -> TechniqueClipLibrary {
        try TechniqueClipLibrary(clips: [
            TechniqueClip(id: "simmer", title: "A gentle simmer", seconds: 6, source: .local("simmer-clip")),
        ])
    }

    @Test("A saved recipe remains cookable after declaring an intolerance")
    @MainActor
    func savedRecipeRemainsCookable() throws {
        let recipe = recipe(review: .reviewed([.dairy]))
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.saveRecipe(recipe.id))
        store.send(.filter(.setSafetyProfile(SafetyProfile(intolerances: [.dairy]))))
        store.send(.startCooking(recipe, startedAt: 100))

        let step = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 100))
        #expect(step.summary == "Simmer the sauce")
        #expect(step.upNext?.summary == "Serve")
        #expect(store.session?.steps.map(\.summary) == ["Simmer the sauce", "Serve"])

        store.send(.unsaveRecipe(recipe.id))
        #expect(try store.cookingStepPresentation(for: recipe, clips: clips(), now: 100) == nil)
        store.send(.saveRecipe(recipe.id))
        #expect(try store.cookingStepPresentation(
            for: self.recipe(review: .unreviewed), clips: clips(), now: 100
        ) == nil)
    }

    @Test("The store projects the current Paso's content and quantities in step order")
    @MainActor
    func currentStepContent() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))

        let step = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 100))

        #expect(step.summary == "Simmer the sauce")
        #expect(step.detail == "Use medium heat.")
        #expect(step.photo == .local("simmer"))
        #expect(step.clip?.name == "A gentle simmer")
        #expect(step.clip?.lengthLabel == "6 s")
        #expect(step.clip?.source == .local("simmer-clip"))
        #expect(step.timerLabel == "12:00")
        #expect(step.ingredientRows.map(\.quantity) == ["1/2 tsp", "2"])
        #expect(step.ingredientRows.map(\.name) == ["Kosher salt", "Roma tomatoes"])
    }
    @Test("Up next follows the session's visible Pasos and disappears on the last Paso")
    @MainActor
    func upNextFollowsVisibleSteps() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        let first = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 100))
        #expect(first.upNext?.summary == "Add butter")
        #expect(first.upNext?.photo == .relative("steps/butter.jpg"))

        let safeStore = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [.dairy])))
        safeStore.send(.startCooking(recipe, startedAt: 100))
        let safeFirst = try #require(safeStore.cookingStepPresentation(for: recipe, clips: clips(), now: 100))
        #expect(safeFirst.upNext?.summary == "Serve")
        #expect(safeFirst.upNext?.photo == nil)
        safeStore.send(.nextStep(now: 110))
        let last = try #require(safeStore.cookingStepPresentation(for: recipe, clips: clips(), now: 110))
        #expect(last.upNext == nil)
        #expect(last.photo == nil)
        #expect(last.clip == nil)
        #expect(last.timerLabel == nil)
    }

    @Test("Progress has one segment per visible Paso and follows navigation in both directions")
    @MainActor
    func progressFollowsNavigation() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        let first = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 100))
        #expect(first.progress.map(\.state) == [.current, .upcoming, .upcoming])
        #expect(first.progress.map(\.stepIndex) == [0, 1, 2])
        #expect(first.progress.allSatisfy { $0.timer == nil })
        store.send(.nextStep(now: 110))
        let second = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 110))
        #expect(second.progress.map(\.state) == [.done, .current, .upcoming])
        store.send(.previousStep)
        let back = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 120))
        #expect(back.progress.map(\.state) == [.current, .upcoming, .upcoming])

        let safeStore = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [.dairy])))
        safeStore.send(.startCooking(recipe, startedAt: 100))
        let safe = try #require(safeStore.cookingStepPresentation(for: recipe, clips: clips(), now: 100))
        #expect(safe.progress.map(\.state) == [.current, .upcoming])
    }

    @Test("A started Temporizador follows the injected clock on its Paso and in other segments")
    @MainActor
    func timerAcrossSteps() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        let current = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 118.2))
        #expect(current.timerLabel == "11:42")
        #expect(current.progress[0].timer == nil)
        store.send(.nextStep(now: 119))
        let running = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 118.2))
        #expect(running.progress[0].timer == .running(remainingLabel: "11:42"))
        let almost = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 819.5))
        #expect(almost.progress[0].timer == .running(remainingLabel: "0:01"))
        let finished = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 820))
        #expect(finished.progress[0].timer == .finished)
        store.send(.previousStep)
        let returned = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 821))
        #expect(returned.timerLabel == "0:00")
        #expect(returned.progress[0].timer == nil)
    }

    @Test("Several started timers keep independent running and finished segment states")
    @MainActor
    func multipleTimers() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 110))
        store.send(.startTimer(now: 110))
        store.send(.nextStep(now: 120))
        let running = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 120))
        #expect(running.progress.map(\.timer) == [
            .running(remainingLabel: "11:40"), .running(remainingLabel: "0:50"), nil,
        ])
        let finished = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 170))
        #expect(finished.progress.map(\.timer) == [.running(remainingLabel: "10:50"), .finished, nil])
        store.send(.previousStep)
        store.send(.previousStep)
        let back = try #require(store.cookingStepPresentation(for: recipe, clips: clips(), now: 170))
        #expect(back.progress[1].state == .upcoming)
        #expect(back.progress[1].timer == .finished)
    }

    @Test("Rows independently apply Intolerance safety to ingredient references in a restored session")
    func ingredientRowsApplySafety() throws {
        let recipe = recipe()
        let step = CookingStep(detail: "Stir gently.", summary: "Stir", ingredients: [
            StepIngredient(ingredientID: "butter", quantity: "1 tbsp"),
            StepIngredient(ingredientID: "tomato", quantity: "1"),
        ])
        let session = CookingSession(recipeID: recipe.id, steps: [step])
        let unrestricted = KartaState(session: session, safetyProfile: SafetyProfile(intolerances: []))
        let safe = KartaState(session: session, safetyProfile: SafetyProfile(intolerances: [.dairy]))
        let allRows = try #require(unrestricted.cookingStepPresentation(for: recipe, clips: clips(), now: 0))
        let safeRows = try #require(safe.cookingStepPresentation(for: recipe, clips: clips(), now: 0))
        #expect(allRows.ingredientRows.map(\.name) == ["Unsalted butter", "Roma tomatoes"])
        #expect(safeRows.ingredientRows.map(\.name) == ["Roma tomatoes"])
        #expect(safeRows.ingredientRows.map(\.quantity) == ["1"])
    }

    @Test("The store offers no Paso without an active matching session")
    @MainActor
    func absentSession() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        #expect(try store.cookingStepPresentation(for: recipe, clips: clips(), now: 0) == nil)
        let otherSession = CookingSession(recipeID: "other", steps: recipe.steps)
        let otherState = KartaState(session: otherSession, safetyProfile: SafetyProfile(intolerances: []))
        #expect(try otherState.cookingStepPresentation(for: recipe, clips: clips(), now: 0) == nil)
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.exitCooking)
        #expect(try store.cookingStepPresentation(for: recipe, clips: clips(), now: 110) == nil)
    }

}
