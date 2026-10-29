import Testing
import KartaCore

@Suite("Cooking Temporizador controls")
struct CookingTimerControlTests {
    private func session() -> CookingSession {
        CookingSession(recipeID: "sauce", steps: [
            CookingStep(detail: "Simmer", timerSeconds: 720), "Serve",
        ], declaredDuration: 900, startedAt: 100)
    }

    @Test("Pause freezes the time left and resume moves the end by the paused interval")
    func pauseAndResume() {
        var session = session()
        session.startTimer(now: 100)
        session.pauseTimer(now: 280)
        #expect(session.timers[0]?.isPaused == true)
        #expect(session.currentStepTimerRemaining(at: 1000) == 540)
        #expect(!session.currentStepTimerHasFired(at: 1000))
        session.resumeTimer(now: 1000)
        #expect(session.timers[0]?.isPaused == false)
        #expect(session.currentStepTimerRemaining(at: 1539.5) == 0.5)
        #expect(session.currentStepTimerHasFired(at: 1540))
    }
    @Test("Reset and Stop return to ready without erasing the started cooking signal", arguments: [false, true])
    func removeTimerKeepsSignal(stop: Bool) {
        var session = session()
        session.startTimer(now: 100)
        if stop {
            session.stopTimer(now: 820)
        } else {
            session.pauseTimer(now: 280)
            session.resetTimer()
        }
        #expect(session.currentStepTimerRemaining(at: 900) == nil)
        session.next(at: 900)
        #expect(session.inferProbablyCooked(at: 900)?.wasInferred == true)
        session.previous()
        session.startTimer(now: 1000)
        #expect(session.currentStepTimerRemaining(at: 1000) == 720)
    }

    @Test("Controls ignore states without their matching button", arguments: ["ready", "running", "paused", "finished"])
    func invalidControls(state: String) {
        var session = session()
        if state != "ready" { session.startTimer(now: 100) }
        if state == "paused" { session.pauseTimer(now: 280) }
        let before = session
        switch state {
        case "ready", "running":
            session.resumeTimer(now: 300)
            session.resetTimer()
            session.stopTimer(now: 300)
            if state == "ready" { session.pauseTimer(now: 300) }
        case "paused":
            session.pauseTimer(now: 1000)
            session.startTimer(now: 1000)
            session.stopTimer(now: 1000)
        default:
            session.pauseTimer(now: 820)
            session.resumeTimer(now: 820)
            session.resetTimer()
        }
        #expect(session == before)
    }

    @Test("Every new timer control is ignored after exit", arguments: ["ready", "running", "paused", "finished"])
    func controlsAfterExit(state: String) {
        var session = session()
        if state != "ready" { session.startTimer(now: 100) }
        if state == "paused" { session.pauseTimer(now: 280) }
        session.exit()
        let before = session
        let now = state == "finished" ? 1000.0 : 300.0
        session.pauseTimer(now: now)
        session.resumeTimer(now: now)
        session.resetTimer()
        session.stopTimer(now: now)
        #expect(session == before)
    }

    @Test("Controls on another Paso or Cierre leave the original Temporizador alone")
    func controlsTargetCurrentPaso() {
        var session = session()
        session.startTimer(now: 100)
        session.next(at: 200)
        let away = session
        session.pauseTimer(now: 280)
        session.resumeTimer(now: 300)
        session.resetTimer()
        session.stopTimer(now: 1000)
        #expect(session == away)
        session.previous()
        session.pauseTimer(now: 280)
        session.next(at: 300)
        session.next(at: 300)
        let finish = session
        session.pauseTimer(now: 400)
        session.resumeTimer(now: 400)
        session.resetTimer()
        session.stopTimer(now: 1000)
        #expect(session == finish)
    }

}
