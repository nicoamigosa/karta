import Testing
@testable import KartaCore

private let sampleSteps = [
    CookingStep(text: "Chop the onion", ingredient: Ingredient(name: "Onion", quantity: "1")),
    CookingStep(text: "Fry it", ingredient: Ingredient(name: "Oil", quantity: "1 tbsp")),
    CookingStep(text: "Serve", ingredient: nil),
]

/// Cooking-mode state machine, exercised independently of any UI.
@Suite("Cooking session — navigation")
struct CookingSessionNavigationTests {

    private let steps = sampleSteps

    @Test("Entering cooking mode starts on the first step")
    func startsOnFirstStep() {
        let session = CookingSession(recipeID: "r1", steps: steps)

        #expect(session.currentIndex == 0)
        #expect(session.currentStep == steps[0])
        #expect(session.isExited == false)
    }

    @Test("next advances; previous goes back")
    func nextAndPrevious() {
        var session = CookingSession(recipeID: "r1", steps: steps)

        session.next()
        #expect(session.currentIndex == 1)
        session.next()
        #expect(session.currentIndex == 2)
        session.previous()
        #expect(session.currentIndex == 1)
    }

    @Test("Navigation clamps at both boundaries")
    func clampsAtBoundaries() {
        var session = CookingSession(recipeID: "r1", steps: steps)

        session.previous()
        #expect(session.currentIndex == 0) // cannot go before the first step

        session.next(); session.next(); session.next(); session.next()
        #expect(session.currentIndex == 2) // cannot go past the last step
    }

    @Test("exit is terminal and freezes navigation")
    func exitIsTerminal() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next()

        session.exit()
        #expect(session.isExited)

        session.next()
        session.previous()
        #expect(session.currentIndex == 1) // navigation no longer moves
    }
}

/// The `cooked` success signal — the core conversion event.
@Suite("Cooking session — cooked event")
struct CookingSessionCookedEventTests {

    private let steps = sampleSteps

    @Test("The prompt only appears on the last step")
    func promptOnlyOnLastStep() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        #expect(session.showsOutcomePrompt == false)

        session.next()
        #expect(session.showsOutcomePrompt == false)

        session.next() // last step
        #expect(session.showsOutcomePrompt)
    }

    @Test("Responding to the prompt emits a cooked event with the outcome")
    func respondingEmitsCookedEvent() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next(); session.next() // reach last step

        let event = session.respond(.thumbsUp)

        #expect(event == CookedEvent(recipeID: "r1", outcome: .thumbsUp, wasInferred: false))
        #expect(session.cookedEvent == event)
    }

    @Test("An explicit response closes the outcome prompt")
    func responseClosesPrompt() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next(); session.next() // reach last step

        session.respond(.thumbsUp)

        #expect(session.showsOutcomePrompt == false)
    }

    @Test("Responding twice emits only one cooked event")
    func responseIsIdempotent() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next(); session.next() // reach last step

        let first = session.respond(.thumbsUp)
        let second = session.respond(.thumbsUp)

        #expect(first == CookedEvent(recipeID: "r1", outcome: .thumbsUp, wasInferred: false))
        #expect(second == nil)
        #expect(session.cookedEvent == first)
    }

    @Test("An explicit response enriches an inferred cook")
    func explicitResponseEnrichesInference() {
        var session = CookingSession(recipeID: "r1", steps: steps, declaredDuration: 60)
        session.next(); session.next() // reach last step

        let inferred = session.inferProbablyCooked(at: 30)
        let explicit = session.respond(.thumbsDown)

        #expect(inferred == CookedEvent(recipeID: "r1", outcome: nil, wasInferred: true))
        #expect(explicit == CookedEvent(recipeID: "r1", outcome: .thumbsDown, wasInferred: false))
        #expect(session.cookedEvent == explicit)
        #expect(session.showsOutcomePrompt == false)
    }

    @Test("Responding before the last step emits nothing")
    func noEventBeforeLastStep() {
        var session = CookingSession(recipeID: "r1", steps: steps)

        #expect(session.respond(.thumbsUp) == nil)
        #expect(session.cookedEvent == nil)
    }

    @Test("A full session infers a cook from progress, timers, and declared duration")
    func fullSessionInfersProbablyCooked() {
        let recipe = Recipe(
            id: "r1",
            name: "Recipe",
            heroPhoto: .local("r1"),
            totalMinutes: 30,
            difficulty: .easy,
            servings: 2,
            tags: [],
            ingredients: [Ingredient(name: "Onion", quantity: "1")],
            steps: [
                CookingStep(text: "Chop", timerSeconds: 120),
                CookingStep(text: "Cook"),
                CookingStep(text: "Serve"),
            ],
            allergenReview: .reviewed([])
        )
        var session = recipe.cookingSession(startedAt: 0)

        session.startTimer(now: 10)
        session.next(); session.next() // complete the journey to the last step

        let event = session.inferProbablyCooked(at: 900)

        #expect(event == CookedEvent(recipeID: "r1", outcome: nil, wasInferred: true))
        #expect(session.cookedEvent?.wasInferred == true)
    }

    @Test("A timed recipe without a started timer does not infer a cook")
    func aTimedRecipeNeedsTimerActivity() {
        let recipe = Recipe(
            id: "r1",
            name: "Recipe",
            heroPhoto: .local("r1"),
            totalMinutes: 30,
            difficulty: .easy,
            servings: 2,
            tags: [],
            ingredients: [Ingredient(name: "Onion", quantity: "1")],
            steps: [
                CookingStep(text: "Chop", timerSeconds: 120),
                CookingStep(text: "Cook"),
                CookingStep(text: "Serve"),
            ],
            allergenReview: .reviewed([])
        )
        var session = recipe.cookingSession(startedAt: 0)
        session.next(); session.next()

        #expect(session.inferProbablyCooked(at: 900) == nil)
        #expect(session.cookedEvent == nil)
    }

    @Test("Idling on the only step, even with a timer, does not infer a cook")
    func anIdleLastStepDoesNotInfer() {
        let recipe = Recipe(
            id: "r1",
            name: "Recipe",
            heroPhoto: .local("r1"),
            totalMinutes: 30,
            difficulty: .easy,
            servings: 2,
            tags: [],
            ingredients: [Ingredient(name: "Onion", quantity: "1")],
            steps: [CookingStep(text: "Serve", timerSeconds: 120)],
            allergenReview: .reviewed([])
        )
        var session = recipe.cookingSession(startedAt: 0)
        session.startTimer(now: 0)

        #expect(session.inferProbablyCooked(at: 900) == nil)
        #expect(session.cookedEvent == nil)
    }

    @Test("A complete-looking journey dispatched far faster than the recipe does not infer")
    func aTooShortSessionDoesNotInfer() {
        let recipe = Recipe(
            id: "r1",
            name: "Recipe",
            heroPhoto: .local("r1"),
            totalMinutes: 30,
            difficulty: .easy,
            servings: 2,
            tags: [],
            ingredients: [Ingredient(name: "Onion", quantity: "1")],
            steps: [
                CookingStep(text: "Chop", timerSeconds: 120),
                CookingStep(text: "Cook"),
                CookingStep(text: "Serve"),
            ],
            allergenReview: .reviewed([])
        )
        var session = recipe.cookingSession(startedAt: 0)
        session.startTimer(now: 10)
        session.next(); session.next()

        #expect(session.inferProbablyCooked(at: 90) == nil)
        #expect(session.cookedEvent == nil)
    }

    @Test("Inference never fires off the last step and never overrides an explicit response")
    func inferenceGuards() {
        var early = CookingSession(recipeID: "r1", steps: steps)
        #expect(early.inferProbablyCooked(at: 999) == nil) // not last step

        var answered = CookingSession(recipeID: "r1", steps: steps, declaredDuration: 60)
        answered.next(); answered.next()
        answered.respond(.thumbsDown)
        #expect(answered.inferProbablyCooked(at: 999) == nil) // already recorded
        #expect(answered.cookedEvent?.outcome == .thumbsDown)
    }

    @Test("Inference does nothing after the session exits")
    func inferenceIsIgnoredAfterExit() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next(); session.next()
        session.exit()

        #expect(session.inferProbablyCooked(at: 999) == nil)
        #expect(session.cookedEvent == nil)
    }
}
