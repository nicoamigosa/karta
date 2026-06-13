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

    @Test("Responding before the last step emits nothing")
    func noEventBeforeLastStep() {
        var session = CookingSession(recipeID: "r1", steps: steps)

        #expect(session.respond(.thumbsUp) == nil)
        #expect(session.cookedEvent == nil)
    }

    @Test("Dwelling on the last step infers a 'probably cooked' event")
    func dwellInfersProbablyCooked() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next(); session.next() // last step

        // Not enough dwell yet.
        #expect(session.inferProbablyCooked(dwellSeconds: 5) == nil)
        #expect(session.cookedEvent == nil)

        // Sufficient dwell → inferred event with no explicit outcome.
        let event = session.inferProbablyCooked(dwellSeconds: 30)
        #expect(event == CookedEvent(recipeID: "r1", outcome: nil, wasInferred: true))
    }

    @Test("Inference never fires off the last step and never overrides an explicit response")
    func inferenceGuards() {
        var early = CookingSession(recipeID: "r1", steps: steps)
        #expect(early.inferProbablyCooked(dwellSeconds: 999) == nil) // not last step

        var answered = CookingSession(recipeID: "r1", steps: steps)
        answered.next(); answered.next()
        answered.respond(.thumbsDown)
        #expect(answered.inferProbablyCooked(dwellSeconds: 999) == nil) // already recorded
        #expect(answered.cookedEvent?.outcome == .thumbsDown)
    }
}
