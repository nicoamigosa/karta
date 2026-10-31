import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Cooking finish presentation")
struct CookingFinishPresentationTests {
    private func recipe(review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(
            id: "sauce", name: "Tomato sauce", heroPhoto: .local("sauce"),
            totalMinutes: 20, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [Ingredient(id: "butter", name: "Unsalted butter", quantity: "1 tbsp",
                                     isOptional: true, allergens: [.dairy])],
            steps: [
                CookingStep(detail: "Simmer gently.", summary: "Simmer", timerSeconds: 720,
                            photo: .local("simmer")),
                CookingStep(detail: "Stir until melted.", summary: "Add butter",
                            ingredients: [StepIngredient(ingredientID: "butter", quantity: "1 tbsp")],
                            timerSeconds: 60, isOptional: true),
                CookingStep(detail: "Divide between bowls.", summary: "Serve", timerSeconds: 30),
            ], allergenReview: review
        )
    }

    @Test("The restored dismissal streak controls the finish card and sharing resets it", arguments: [0, 1, 2, 3])
    @MainActor
    func restoredShareCardRule(dismissals: Int) throws {
        var history = ShareCardHistory()
        for index in 0..<dismissals { history.close(for: "old-\(index)", as: .dismissed) }
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            shareCardHistory: history
        )
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot)
        let recipe = recipe()
        let store = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: []),
            shareBaseURL: URL(string: "https://karta.app/r"),
            shareCardHistory: restored.shareCardHistory
        ))
        store.send(.startCooking(recipe, startedAt: 100))
        for time in [110.0, 120.0, 130.0] { store.send(.nextStep(now: time)) }
        store.send(.respond(.thumbsUp))
        #expect((store.cookingFinishPresentation(for: recipe, now: 130)?.sharePayload != nil) == (dismissals < 3))
        store.send(.closeShareCard(.shared))
        #expect(store.state.shareCardHistory.consecutiveDismissals == (dismissals < 3 ? 0 : 3))
    }

    @Test("Finish dismisses an offered share card")
    @MainActor
    func finishDismissesShareCard() {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: []),
            shareBaseURL: URL(string: "https://karta.app/r")
        ))
        store.send(.startCooking(recipe, startedAt: 100))
        for time in [110.0, 120.0, 130.0] { store.send(.nextStep(now: time)) }
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        store.send(.exitCooking)
        #expect(store.state.shareCardHistory.shownRecipeIDs == [recipe.id])
        #expect(store.state.shareCardHistory.consecutiveDismissals == 1)
    }

    @Test("Closing the share card consumes this recipe only once", arguments: [false, true])
    @MainActor
    func closesShareCard(shared: Bool) throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: []),
            shareBaseURL: URL(string: "https://karta.app/r")
        ))
        store.send(.startCooking(recipe, startedAt: 100))
        for time in [110.0, 120.0, 130.0] { store.send(.nextStep(now: time)) }
        store.send(.respond(.thumbsUp))
        #expect(store.cookingFinishPresentation(for: recipe, now: 130)?.sharePayload != nil)
        store.send(.closeShareCard(shared ? .shared : .dismissed))
        store.send(.closeShareCard(shared ? .shared : .dismissed))
        #expect(store.cookingFinishPresentation(for: recipe, now: 130)?.sharePayload == nil)
        #expect(store.state.shareCardHistory.shownRecipeIDs == [recipe.id])
        #expect(store.state.shareCardHistory.consecutiveDismissals == (shared ? 0 : 1))
        store.send(.startCooking(recipe, startedAt: 200))
        for time in [210.0, 220.0, 230.0] { store.send(.nextStep(now: time)) }
        store.send(.respond(.thumbsUp))
        #expect(store.cookingFinishPresentation(for: recipe, now: 230)?.sharePayload == nil)
    }

    @Test("The share card needs an available link and the explicit Good answer", arguments: [false, true])
    @MainActor
    func shareCardAfterGood(available: Bool) throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: []),
            shareBaseURL: available ? URL(string: "https://karta.app/r") : nil
        ))
        store.send(.startCooking(recipe, startedAt: 100))
        #expect(store.cookingFinishPresentation(for: recipe, now: 110) == nil)
        for time in [110.0, 120.0, 400.0] { store.send(.nextStep(now: time)) }
        #expect(store.cookingFinishPresentation(for: recipe, now: 400)?.sharePayload == nil)
        store.send(.respond(.thumbsDown))
        #expect(store.cookingFinishPresentation(for: recipe, now: 400)?.sharePayload == nil)
        // A fresh session is needed because an explicit answer is final.
        store.send(.startCooking(recipe, startedAt: 500))
        for time in [510.0, 520.0, 530.0] { store.send(.nextStep(now: time)) }
        store.send(.respond(.thumbsUp))
        let finish = try #require(store.cookingFinishPresentation(for: recipe, now: 530))
        #expect((finish.sharePayload != nil) == available)
        #expect(finish.sharePayload?.title == (available ? "Tomato sauce" : nil))
    }

    @Test("Cierre projects the recipe Foto and completed progress instead of a Paso")
    @MainActor
    func finishContent() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        let clips = try TechniqueClipLibrary(clips: [])
        store.send(.startCooking(recipe, startedAt: 100))
        for time in [110.0, 120.0, 130.0] {
            #expect(store.cookingFinishPresentation(for: recipe, now: time) == nil)
            #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: time) != nil)
            store.send(.nextStep(now: time))
        }
        #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: 130) == nil)
        let finish = try #require(store.cookingFinishPresentation(for: recipe, now: 130))
        #expect(finish.recipeName == "Tomato sauce")
        #expect(finish.photo == .local("sauce"))
        #expect(finish.outcome == .asking)
        #expect(finish.progress.map(\.stepIndex) == [0, 1, 2])
        #expect(finish.progress.map(\.state) == [.done, .done, .done])
        #expect(finish.progress.allSatisfy { $0.timer == nil })
        store.send(.previousStep)
        #expect(store.cookingFinishPresentation(for: recipe, now: 140) == nil)
        #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: 140) != nil)
    }
    @Test("Every started timer, including the last Paso's, stays visible at Cierre")
    @MainActor
    func finishTimers() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 110))
        store.send(.startTimer(now: 110))
        store.send(.nextStep(now: 120))
        store.send(.startTimer(now: 120))
        store.send(.nextStep(now: 130))
        let running = try #require(store.cookingFinishPresentation(for: recipe, now: 149.5))
        #expect(running.progress.map(\.timer) == [
            .running(remainingLabel: "11:11"), .running(remainingLabel: "0:21"),
            .running(remainingLabel: "0:01"),
        ])
        let finished = try #require(store.cookingFinishPresentation(for: recipe, now: 170))
        #expect(finished.progress.map(\.timer) == [.running(remainingLabel: "10:50"), .finished, .finished])
        #expect(finished.progress.map(\.state) == [.done, .done, .done])
    }

    @Test("A Temporizador paused on a Paso stays paused at Cierre")
    @MainActor
    func finishPausedTimer() throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.pauseTimer(now: 280))
        store.send(.nextStep(now: 290))
        store.send(.nextStep(now: 300))
        store.send(.nextStep(now: 310))
        let finish = try #require(store.cookingFinishPresentation(for: recipe, now: 5000))
        #expect(finish.progress.map(\.timer) == [.paused(remainingLabel: "9:00"), nil, nil])
    }

    @Test("Arriving at Cierre infers one Cocinado at arrival without a shell inference action")
    @MainActor
    func finishInfersCook() throws {
        let recipe = recipe()
        let earlier = CookEntry(recipeID: recipe.id, date: Date(timeIntervalSince1970: 50))
        let store = KartaStore(state: KartaState(cookHistory: [earlier], safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 110))
        store.send(.nextStep(now: 120))
        #expect(store.state.cookHistory == [earlier])
        store.send(.nextStep(now: 400))
        #expect(store.state.cookHistory == [
            earlier, CookEntry(recipeID: recipe.id, date: Date(timeIntervalSince1970: 400), wasInferred: true),
        ])
        #expect(store.session?.cookedEvent?.wasInferred == true)
        #expect(store.cookingFinishPresentation(for: recipe, now: 400)?.outcome == .asking)
        store.send(.nextStep(now: 450))
        store.send(.previousStep)
        store.send(.nextStep(now: 500))
        store.send(.inferProbablyCooked(now: 600))
        #expect(store.state.cookHistory.count == 2)
        #expect(store.state.cookHistory.last?.date == Date(timeIntervalSince1970: 400))
    }

    @Test("An answer at Cierre records or enriches one explicit Cocinado", arguments: [
        CookOutcome.thumbsUp, .thumbsDown, .photo,
    ], [false, true])
    @MainActor
    func finishAnswer(outcome: CookOutcome, inferred: Bool) throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        if inferred { store.send(.startTimer(now: 100)) }
        store.send(.nextStep(now: 110))
        store.send(.nextStep(now: 120))
        store.send(.nextStep(now: 400))
        #expect(store.state.cookHistory.count == (inferred ? 1 : 0))
        store.send(.respond(outcome))
        #expect(store.cookingFinishPresentation(for: recipe, now: 400)?.outcome == .answered(outcome))
        #expect(store.session?.showsOutcomePrompt == false)
        #expect(store.session?.cookedEvent?.outcome == outcome)
        #expect(store.session?.cookedEvent?.wasInferred == false)
        #expect(store.state.cookHistory == [
            CookEntry(recipeID: recipe.id, date: Date(timeIntervalSince1970: 120)),
        ])
        store.send(.respond(.thumbsDown))
        store.send(.inferProbablyCooked(now: 500))
        store.send(.previousStep)
        store.send(.nextStep(now: 600))
        #expect(store.session?.cookedEvent?.outcome == outcome)
        #expect(store.state.cookHistory.count == 1)
    }

    @Test("A fast journey or an unstarted declared timer leaves the answer available", arguments: [false, true])
    @MainActor
    func finishInferenceRequiresEvidence(startTimer: Bool) throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        if startTimer { store.send(.startTimer(now: 100)) }
        store.send(.nextStep(now: 110))
        store.send(.nextStep(now: 120))
        store.send(.nextStep(now: startTimer ? 399 : 400))
        #expect(store.state.cookHistory.isEmpty)
        #expect(store.cookingFinishPresentation(for: recipe, now: 500)?.outcome == .asking)
        store.send(.nextStep(now: 600))
        store.send(.previousStep)
        store.send(.nextStep(now: 700))
        store.send(.inferProbablyCooked(now: 800))
        #expect(store.state.cookHistory.isEmpty)
        store.send(.respond(.photo))
        #expect(store.state.cookHistory.count == 1)
        #expect(store.state.cookHistory.first?.wasInferred == false)
    }

    @Test("A restored finish answer enriches its persisted inferred Cocinado")
    @MainActor
    func restoredFinishAnswer() throws {
        let recipe = recipe()
        let earlier = CookEntry(recipeID: recipe.id, date: Date(timeIntervalSince1970: 50), wasInferred: true)
        let store = KartaStore(state: KartaState(cookHistory: [earlier], safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        store.send(.nextStep(now: 110))
        store.send(.nextStep(now: 120))
        store.send(.nextStep(now: 400))
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookHistory: store.state.cookHistory, cookingSession: store.session
        )
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot)
        let resumed = KartaStore(state: KartaState(
            cookHistory: restored.cookHistory, session: restored.cookingSession,
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        resumed.send(.respond(.thumbsUp))
        #expect(resumed.state.cookHistory == [
            earlier, CookEntry(recipeID: recipe.id, date: Date(timeIntervalSince1970: 120)),
        ])
        #expect(resumed.cookingFinishPresentation(for: recipe, now: 500)?.outcome == .answered(.thumbsUp))
    }

    @Test("Cierre applies the active-session and recipe-opening guards")
    @MainActor
    func finishGuards() throws {
        let recipe = recipe(review: .reviewed([.dairy]))
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [.dairy])))
        #expect(store.cookingFinishPresentation(for: recipe, now: 100) == nil)
        store.send(.saveRecipe(recipe.id))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.nextStep(now: 110))
        store.send(.nextStep(now: 120))
        let finish = try #require(store.cookingFinishPresentation(for: recipe, now: 120))
        #expect(finish.progress.map(\.stepIndex) == [0, 1])
        #expect(finish.progress.map(\.state) == [.done, .done])
        #expect(store.cookingFinishPresentation(for: self.recipe(review: .unreviewed), now: 120) == nil)
        store.send(.unsaveRecipe(recipe.id))
        #expect(store.cookingFinishPresentation(for: recipe, now: 120) == nil)
        store.send(.saveRecipe(recipe.id))
        store.send(.exitCooking)
        store.send(.previousStep)
        store.send(.nextStep(now: 500))
        store.send(.respond(.thumbsUp))
        #expect(store.session?.isOnFinish == true)
        #expect(store.session?.isExited == true)
        #expect(store.state.cookHistory.isEmpty)
        #expect(store.cookingFinishPresentation(for: recipe, now: 500) == nil)
        var otherSession = CookingSession(recipeID: "other", steps: ["Serve"])
        otherSession.next(at: 100)
        let other = KartaState(
            session: otherSession,
            safetyProfile: SafetyProfile(intolerances: [])
        )
        #expect(other.cookingFinishPresentation(for: recipe, now: 500) == nil)
    }

    @Test("Today's shell can stop on the last Paso and answer or request inference", arguments: [false, true])
    @MainActor
    func legacyShellFlow(inferred: Bool) throws {
        let recipe = recipe()
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.startCooking(recipe, startedAt: 100))
        store.send(.startTimer(now: 100))
        while store.session?.isOnLastStep == false {
            store.send(.nextStep(now: 400))
        }
        #expect(store.session?.isOnFinish == false)
        #expect(store.session?.showsOutcomePrompt == true)
        if inferred {
            store.send(.inferProbablyCooked(now: 450))
            #expect(store.session?.cookedEvent?.wasInferred == true)
            #expect(store.session?.showsOutcomePrompt == true)
            #expect(store.state.cookHistory.first?.date == Date(timeIntervalSince1970: 450))
        } else {
            store.send(.respond(.thumbsUp))
            store.send(.inferProbablyCooked(now: 450))
            #expect(store.session?.cookedEvent?.outcome == .thumbsUp)
            #expect(store.session?.showsOutcomePrompt == false)
            #expect(store.state.cookHistory.first?.date == Date(timeIntervalSince1970: 400))
        }
        #expect(store.state.cookHistory.count == 1)
        #expect(store.cookingFinishPresentation(for: recipe, now: 450) == nil)
        let clips = try TechniqueClipLibrary(clips: [])
        #expect(store.cookingStepPresentation(for: recipe, clips: clips, now: 450) != nil)
    }

    @Test("Untimed recipes need no timer activity but retain the multi-Paso journey rule", arguments: [false, true])
    @MainActor
    func untimedJourney(multiStep: Bool) {
        let session = CookingSession(
            recipeID: "untimed", steps: multiStep ? ["Prepare", "Serve"] : ["Serve"],
            declaredDuration: 60, startedAt: 100
        )
        let store = KartaStore(state: KartaState(session: session, safetyProfile: SafetyProfile(intolerances: [])))
        if multiStep { store.send(.nextStep(now: 101)) }
        store.send(.nextStep(now: 115))
        #expect(store.session?.isOnFinish == true)
        if multiStep {
            #expect(store.state.cookHistory == [
                CookEntry(recipeID: "untimed", date: Date(timeIntervalSince1970: 115), wasInferred: true),
            ])
        } else {
            #expect(store.state.cookHistory.isEmpty)
            #expect(store.session?.showsOutcomePrompt == true)
        }
    }

}
