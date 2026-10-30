import Testing
import KartaCore

@Suite("Cooking Temporizador controls by Paso")
struct CookingIndexedTimerControlTests {
    private func session() -> CookingSession {
        CookingSession(recipeID: "sauce", steps: [
            "Prepare", CookingStep(detail: "Simmer", timerSeconds: 720), "Serve",
        ], declaredDuration: 900, startedAt: 100)
    }

    @Test("Pause away from its Paso uses the press time even after observing a finished countdown", arguments: [false, true])
    func pauseOnAnotherPaso(fromFinish: Bool) {
        var session = session()
        session.next(at: 100)
        session.startTimer(now: 100)
        session.next(at: 200)
        if fromFinish { session.next(at: 250) }
        #expect(session.timers[1]?.hasFired(at: 1000) == true)

        session.pauseTimer(stepIndex: 1, now: 280)

        #expect(session.currentIndex == 2)
        #expect(session.isOnFinish == fromFinish)
        #expect(session.timers[1]?.pausedRemaining == 540)
        #expect(session.timers[1]?.remaining(at: 1200) == 540)
        #expect(session.startedTimerSteps == [1])
    }

    @Test("Resume and Stop at Cierre keep its position and the started cooking signal")
    func resumeAndStopAtFinish() {
        var session = session()
        session.next(at: 100)
        session.startTimer(now: 100)
        session.pauseTimer(stepIndex: 1, now: 280)
        session.next(at: 400)
        session.next(at: 500)

        session.resumeTimer(stepIndex: 1, now: 1000)
        #expect(session.timers[1]?.remaining(at: 1200) == 340)
        #expect(session.timers[1]?.hasFired(at: 1540) == true)
        session.stopTimer(stepIndex: 1, now: 1540)

        #expect(session.timers.isEmpty)
        #expect(session.currentIndex == 2)
        #expect(session.isOnFinish)
        #expect(session.finishReachedAt == 500)
        #expect(session.startedTimerSteps == [1])
        #expect(session.inferProbablyCooked(at: 1540)?.wasInferred == true)
    }

    @Test("Indexed controls ignore Temporizadores without their matching state", arguments: ["ready", "running", "paused", "finished"])
    func invalidControls(state: String) {
        var session = session()
        session.next(at: 100)
        if state != "ready" { session.startTimer(now: 100) }
        if state == "paused" { session.pauseTimer(now: 280) }
        session.next(at: 300)
        session.next(at: 400)
        let before = session
        let now = state == "finished" ? 820.0 : 300.0

        if state != "running" { session.pauseTimer(stepIndex: 1, now: now) }
        if state != "paused" { session.resumeTimer(stepIndex: 1, now: now) }
        if state != "finished" { session.stopTimer(stepIndex: 1, now: now) }

        #expect(session == before)
    }

    @Test("Indexed controls ignore out-of-range indices", arguments: [-1, 3, Int.max], ["running", "paused", "finished"])
    func invalidIndex(index: Int, state: String) {
        var session = session()
        session.next(at: 100)
        session.startTimer(now: 100)
        if state == "paused" { session.pauseTimer(now: 280) }
        session.next(at: 300)
        let before = session
        let now = state == "finished" ? 820.0 : 300.0
        session.pauseTimer(stepIndex: index, now: now)
        session.resumeTimer(stepIndex: index, now: now)
        session.stopTimer(stepIndex: index, now: now)
        #expect(session == before)
    }

    @Test("Indexed controls are ignored after leaving the session")
    func afterExit() {
        var session = session()
        session.next(at: 100)
        session.startTimer(now: 100)
        session.exit()
        let before = session
        session.pauseTimer(stepIndex: 1, now: 280)
        session.resumeTimer(stepIndex: 1, now: 300)
        session.stopTimer(stepIndex: 1, now: 1000)
        #expect(session == before)
    }
}
