import Testing
import KartaCore

@Suite("Cooking session Temporizador starts")
struct CookingSessionTimerStartTests {
    @Test("A finished Temporizador can start again at zero or later", arguments: [820.0, 900.0])
    func finishedTimerCanRestart(now: Double) {
        var session = CookingSession(
            recipeID: "sauce", steps: [CookingStep(detail: "Simmer", timerSeconds: 720)]
        )
        session.startTimer(now: 100)
        #expect(session.currentStepTimerHasFired(at: now))

        session.startTimer(now: now)

        #expect(session.timers[0]?.startedAt == now)
        #expect(session.currentStepTimerRemaining(at: now) == 720)
        #expect(session.currentStepTimerHasFired(at: now) == false)
    }

    @Test("Starting a running Temporizador twice keeps its original start and cooking signal")
    func repeatedStartKeepsOriginalTimer() {
        var session = CookingSession(
            recipeID: "sauce", steps: [
                CookingStep(detail: "Simmer", timerSeconds: 720),
                CookingStep(detail: "Serve"),
            ], declaredDuration: 900, startedAt: 100
        )
        session.startTimer(now: 100)
        session.startTimer(now: 100)
        session.startTimer(now: 819.5)

        #expect(session.timers[0] == StepTimer(startedAt: 100, duration: 720))
        #expect(session.currentStepTimerRemaining(at: 819.5) == 0.5)
        session.next(at: 820)
        session.next(at: 820)
        #expect(session.inferProbablyCooked(at: 820) == CookedEvent(
            recipeID: "sauce", outcome: nil, wasInferred: true
        ))
    }
}
