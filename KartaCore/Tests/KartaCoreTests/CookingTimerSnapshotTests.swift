import Foundation
import Testing
import KartaCore

@Suite("Cooking Temporizador snapshot")
struct CookingTimerSnapshotTests {
    @Test("A paused Temporizador restores frozen, then its reset cooking signal survives another restore")
    func pausedAndResetRoundTrip() throws {
        var session = CookingSession(recipeID: "sauce", steps: [
            CookingStep(detail: "Simmer", timerSeconds: 720), "Serve",
        ], declaredDuration: 900, startedAt: 100)
        session.startTimer(now: 100)
        session.pauseTimer(now: 280)
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookingSession: session
        )
        var restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot?.cookingSession)
        #expect(restored == session)
        #expect(restored.currentStepTimerRemaining(at: 10000) == 540)
        #expect(!restored.currentStepTimerHasFired(at: 10000))
        restored.resetTimer()
        let resetSnapshot = UserSnapshot(
            profile: snapshot.profile, cookingSession: restored
        )
        var reset = try #require(UserSnapshot.restore(from: resetSnapshot.encoded()).snapshot?.cookingSession)
        #expect(reset.timers.isEmpty)
        reset.next(at: 1000)
        #expect(reset.inferProbablyCooked(at: 1000)?.wasInferred == true)
    }
    @Test("An old exited session restores without its alarms")
    func legacyExitedSession() throws {
        let data = Data(#"""
        {"version":1,"profile":{"intolerances":[],"householdSize":2},
         "cookingSession":{"recipeID":"sauce","isExited":true,
         "steps":[{"text":"Simmer","timerSeconds":720}],
         "timers":[{"stepIndex":0,"startedAt":100,"duration":720,"pausedRemaining":540}]}}
        """#.utf8)
        let restored = try #require(UserSnapshot.restore(from: data).snapshot?.cookingSession)
        #expect(restored.isExited)
        #expect(restored.timers.isEmpty)
        #expect(restored.startedTimerSteps == [0])
    }

    @Test("The old timer fixture remains running and supplies its original cooking signal")
    func legacyTimerFixture() throws {
        let data = Data(#"""
        {"version":1,"profile":{"intolerances":[],"householdSize":2},
         "cookingSession":{"recipeID":"sauce","declaredDuration":900,"startedAt":100,
         "steps":[{"text":"Simmer","timerSeconds":720},{"text":"Serve"}],
         "timers":[{"stepIndex":0,"startedAt":100,"duration":720}]}}
        """#.utf8)
        var restored = try #require(UserSnapshot.restore(from: data).snapshot?.cookingSession)
        #expect(restored.timers[0] == StepTimer(startedAt: 100, duration: 720))
        #expect(restored.currentStepTimerRemaining(at: 280) == 540)
        #expect(restored.currentStepTimerHasFired(at: 820))
        restored.stopTimer(now: 820)
        let stopped = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2), cookingSession: restored
        )
        var roundTripped = try #require(UserSnapshot.restore(from: stopped.encoded()).snapshot?.cookingSession)
        #expect(roundTripped.timers.isEmpty)
        roundTripped.next(at: 1000)
        #expect(roundTripped.inferProbablyCooked(at: 1000)?.wasInferred == true)
    }

    @Test("Invalid additive timer data preserves the original snapshot", arguments: [
        (#""pausedRemaining":-1"#, "0"),
        (#""pausedRemaining":0"#, "0"),
        (#""pausedRemaining":1e400"#, "0"),
        (#""pausedRemaining":"540""#, "0"),
        (#""pausedRemaining":540"#, "2"),
    ])
    func invalidTimerData(timerField: String, startedStep: String) {
        let json = #"""
        {"version":1,"profile":{"intolerances":[],"householdSize":2},
         "cookingSession":{"recipeID":"sauce","steps":[{"text":"Simmer","timerSeconds":720}],
         "startedTimerSteps":[
        """# + startedStep + #"""
         ],"timers":[{"stepIndex":0,"startedAt":100,"duration":720,
        """# + timerField + "}]}}"
        let data = Data(json.utf8)
        let result = UserSnapshot.restore(from: data)
        #expect(result.snapshot == nil)
        #expect(result.preservedData == data)
    }

}
