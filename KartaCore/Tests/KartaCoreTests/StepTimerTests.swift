import Testing
@testable import KartaCore

/// In-step cooking timers, exercised independently of UI. Time is injected so
/// the countdown is deterministic.
@Suite("Step timers")
struct StepTimerTests {

    private let steps = [
        CookingStep(text: "Chop", ingredient: nil),
        CookingStep(text: "Simmer 10 min", ingredient: nil, timerSeconds: 600),
        CookingStep(text: "Serve", ingredient: nil),
    ]

    @Test("Starting a timer on a timed step counts down")
    func startAndCountDown() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next() // the simmer step

        #expect(session.currentStepTimerRemaining(at: 0) == nil) // not started yet

        session.startTimer(now: 1_000)
        #expect(session.currentStepTimerRemaining(at: 1_000) == 600)
        #expect(session.currentStepTimerRemaining(at: 1_240) == 360)
    }

    @Test("Starting a timer on a step without one is a no-op")
    func noTimerOnPlainStep() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.startTimer(now: 1_000) // step 0 has no timer

        #expect(session.currentStepTimerRemaining(at: 1_000) == nil)
    }

    @Test("Starting a timer after exit is ignored")
    func noTimerAfterExit() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next()
        session.exit()

        session.startTimer(now: 1_000)

        #expect(session.currentStepTimerRemaining(at: 1_000) == nil)
    }

    @Test("A timer fires once the countdown reaches zero")
    func timerFires() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next()
        session.startTimer(now: 1_000)

        #expect(session.currentStepTimerHasFired(at: 1_599) == false)
        #expect(session.currentStepTimerHasFired(at: 1_600))
        #expect(session.currentStepTimerRemaining(at: 1_900) == 0) // floors at zero
    }

    @Test("Timer state survives navigating away and back")
    func timerSurvivesNavigation() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next()
        session.startTimer(now: 1_000)

        session.next()                                    // leave the timed step
        #expect(session.currentStepTimerRemaining(at: 1_100) == nil) // step 2 has no timer
        session.previous()                                // return to it

        #expect(session.currentStepTimerRemaining(at: 1_100) == 500) // kept counting
    }

    @Test("A timer that was running at exit keeps counting")
    func timerSurvivesExit() {
        var session = CookingSession(recipeID: "r1", steps: steps)
        session.next()
        session.startTimer(now: 1_000)
        session.exit()

        #expect(session.currentStepTimerRemaining(at: 1_100) == 500)
        #expect(session.currentStepTimerHasFired(at: 1_600))
    }
}
