import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Cooking session shell")
struct CookingSessionTests {
    private struct FixedClock: KartaClock {
        let now: Date
    }

    @Test("Gestures map to next / previous; there is no vertical gesture")
    func gestureDecisions() {
        let threshold = KartaDesign.cooking.swipeThreshold

        // Swipe left advances.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: -60, height: 4),
            predictedTranslation: CGSize(width: -threshold, height: 0)
        ) == .next)

        // Swipe right goes back.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 60, height: 4),
            predictedTranslation: CGSize(width: threshold, height: 0)
        ) == .previous)

        // Swipe down does nothing: leaving is only the ✕, which asks first.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 6, height: 80),
            predictedTranslation: CGSize(width: 0, height: threshold)
        ) == nil)

        // Swipe up does nothing.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 0, height: -90),
            predictedTranslation: CGSize(width: 0, height: -threshold)
        ) == nil)

        // Sub-threshold gestures do nothing.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 30, height: 30),
            predictedTranslation: CGSize(width: 39, height: 0)
        ) == nil)
    }

    @Test("Taps: right half advances, left half goes back")
    func tapDecisions() {
        #expect(CookingTapDecision.command(locationX: 300, width: 390) == .next)
        #expect(CookingTapDecision.command(locationX: 60, width: 390) == .previous)
        #expect(CookingTapDecision.command(locationX: 10, width: 0) == nil)
    }

    // The Paso ingredient rows now come from `CookingStepPresentation`
    // (#103); their intolerance filtering is covered in KartaPresentation's
    // own test suite — the shell joins nothing.

    @Test("The signal chip counts rows measured in the scroll viewport")
    func hiddenRowCounting() {
        // Row bottoms live in the scroll viewport's coordinate space: they
        // move with the content, so the threshold is only the viewport
        // height minus the fade — the offset is never added back.
        let viewport: CGFloat = 500
        let fade: CGFloat = 32

        // Rows at viewport positions 400 / 480 / 520: only the last two are
        // below the fade's top edge (500 − 32 = 468).
        var result = CookingScrollSignal.hiddenRows(
            rowBottoms: [0: 400, 1: 480, 2: 520],
            viewportHeight: viewport,
            fadeHeight: fade
        )
        #expect(result.count == 2)
        #expect(result.nextIndex == 1)

        // After the user scrolls down 60 pt the same rows read 340 / 420 /
        // 460 in viewport space — all visible, no scroll offset subtracted
        // twice.
        result = CookingScrollSignal.hiddenRows(
            rowBottoms: [0: 340, 1: 420, 2: 460],
            viewportHeight: viewport,
            fadeHeight: fade
        )
        #expect(result.count == 0)
        #expect(result.nextIndex == nil)

        // A card without ingredient rows (the Cierre) reports nothing, so
        // the chip falls back to "More below".
        result = CookingScrollSignal.hiddenRows(
            rowBottoms: [:],
            viewportHeight: viewport,
            fadeHeight: fade
        )
        #expect(result.count == 0)
        #expect(result.nextIndex == nil)
    }

    // The store itself evaluates the inferred Cocinado on arrival at the
    // finish card (#121); the shell reports nothing, so there is no
    // step-arrival seam left to test here.

    @MainActor
    @Test("Start → advance → last step → response emits the cooked event")
    func successEventEmission() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        // Entered cooking mode.
        let startedAt = now.timeIntervalSince1970
        store.send(.startCooking(recipe, startedAt: startedAt))
        var session = try #require(store.session)
        #expect(session.recipeID == recipe.id)
        #expect(session.currentIndex == 0)
        #expect(session.cookedEvent == nil)

        // Walked to the last step.
        while !session.isOnLastStep {
            store.send(.nextStep(now: Date().timeIntervalSince1970))
            session = try #require(store.session)
        }
        #expect(session.showsOutcomePrompt)

        // Prompt response emits the explicit cooked event.
        store.send(.respond(.thumbsUp))
        let event = try #require(store.session?.cookedEvent)
        #expect(event.recipeID == recipe.id)
        #expect(event.outcome == .thumbsUp)
        #expect(!event.wasInferred)

        // Exiting is terminal.
        store.send(.exitCooking)
        #expect(store.session?.isExited == true)
        #expect(CookingRoute.recipe(for: store.session, in: recipes) == nil)
    }

    @MainActor
    @Test("The photo outcome emits the cooked event too")
    func photoOutcome() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        store.send(.startCooking(recipe, startedAt: now.timeIntervalSince1970))
        while store.session?.isOnLastStep == false {
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        store.send(.respond(.photo))

        let event = try #require(store.session?.cookedEvent)
        #expect(event.outcome == .photo)
        #expect(!event.wasInferred)
    }

    @MainActor
    @Test("The overlay resolves the running session's recipe")
    func cookingRoute() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let session = recipe.cookingSession()

        #expect(CookingRoute.recipe(for: session, in: recipes) == recipe)
        #expect(CookingRoute.recipe(for: nil, in: recipes) == nil)

        var exited = session
        exited.exit()
        #expect(CookingRoute.recipe(for: exited, in: recipes) == nil)

        var other = CookingSession(
            recipeID: "not-in-the-catalog",
            steps: [CookingStep(detail: "Step")]
        )
        #expect(CookingRoute.recipe(for: other, in: recipes) == nil)
        other.exit()
        #expect(CookingRoute.recipe(for: other, in: recipes) == nil)
    }
}

@Suite("Timer fire detector")
struct TimerFireDetectorTests {
    @Test("A running timer crossing zero fires once; a paused one re-arms")
    func fireOnce() {
        var detector = TimerFireDetector()
        var timers: [Int: StepTimer] = [
            1: StepTimer(startedAt: 0, duration: 10)
        ]

        #expect(detector.poll(timers: timers, now: 5) == [])
        #expect(detector.poll(timers: timers, now: 10) == [1])
        #expect(detector.poll(timers: timers, now: 11) == [])

        // Pausing before zero arms again when it resumes.
        timers[1] = StepTimer(startedAt: 0, duration: 10, pausedRemaining: 4)
        #expect(detector.poll(timers: timers, now: 12) == [])
        // Resumed at 12 with 4 s left: startedAt shifts so it ends at 16.
        timers[1] = StepTimer(startedAt: 6, duration: 10)
        #expect(detector.poll(timers: timers, now: 15.5) == [])
        #expect(detector.poll(timers: timers, now: 16) == [1])

        // A timer that disappeared while armed can never fire again.
        timers.removeAll()
        #expect(detector.poll(timers: timers, now: 20) == [])
        timers[1] = StepTimer(startedAt: 20, duration: 10)
        #expect(detector.poll(timers: timers, now: 29) == [])
    }
}

@Suite("Cooking alarm reconcile")
struct CookingAlarmPlanTests {
    private typealias Observed = CookingAlarmPlan.Observed
    private typealias Op = CookingAlarmPlan.Op

    private let idA = CookingAlarmID.id(recipeID: "r1", stepIndex: 0)
    private let idB = CookingAlarmID.id(recipeID: "r1", stepIndex: 2)

    @Test("Missing alarms schedule; extras are removed; transitions map")
    func diff() {
        // A running desired timer with no alarm schedules a countdown.
        let ops = CookingAlarmPlan.diff(
            desired: [(idA, .running(endsAt: 130))],
            observed: [:],
            now: 100
        )
        #expect(ops == [.schedule(id: idA, running: true, seconds: 30)])

        // Paused desired schedules then the controller pauses it.
        #expect(CookingAlarmPlan.diff(
            desired: [(idA, .paused(remaining: 45))],
            observed: [:],
            now: 100
        ) == [.schedule(id: idA, running: false, seconds: 45)])

        // Paused observed + running desired → resume.
        #expect(CookingAlarmPlan.diff(
            desired: [(idA, .running(endsAt: 130))],
            observed: [idA: .paused],
            now: 100
        ) == [.resume(id: idA)])

        // Countdown observed + paused desired → pause.
        #expect(CookingAlarmPlan.diff(
            desired: [(idA, .paused(remaining: 45))],
            observed: [idA: .countdown],
            now: 100
        ) == [.pause(id: idA)])

        // A timer the store no longer reports is cancelled; an alerting one
        // is stopped.
        #expect(CookingAlarmPlan.diff(
            desired: [],
            observed: [idA: .countdown, idB: .alerting],
            now: 100
        ) == [.remove(id: idA, alerting: false), .remove(id: idB, alerting: true)])

        // In agreement → no ops.
        #expect(CookingAlarmPlan.diff(
            desired: [
                (idA, .running(endsAt: 130)),
                (idB, .finished)
            ],
            observed: [idA: .countdown, idB: .alerting],
            now: 100
        ) == [])
    }

    @Test("Alarm ids are stable per recipe and Paso")
    func stableIDs() {
        #expect(CookingAlarmID.id(recipeID: "r1", stepIndex: 0)
            == CookingAlarmID.id(recipeID: "r1", stepIndex: 0))
        #expect(CookingAlarmID.id(recipeID: "r1", stepIndex: 0)
            != CookingAlarmID.id(recipeID: "r1", stepIndex: 1))
        #expect(CookingAlarmID.id(recipeID: "r1", stepIndex: 0)
            != CookingAlarmID.id(recipeID: "r2", stepIndex: 0))
    }

    @Test("System transitions map to the equivalent Temporizador action")
    func systemEffects() {
        // Pause pressed on the Lock Screen.
        #expect(CookingAlarmPlan.systemEffect(old: .countdown, new: .paused) == .pause)
        // Resume pressed on the Lock Screen.
        #expect(CookingAlarmPlan.systemEffect(old: .paused, new: .countdown) == .resume)
        // An alert stopped from the Lock Screen disappears.
        #expect(CookingAlarmPlan.systemEffect(old: .alerting, new: nil) == .stop)
        // Everything else is noise: schedule, fire, transient states.
        #expect(CookingAlarmPlan.systemEffect(old: nil, new: .countdown) == nil)
        #expect(CookingAlarmPlan.systemEffect(old: .countdown, new: .alerting) == nil)
        #expect(CookingAlarmPlan.systemEffect(old: .countdown, new: .countdown) == nil)
        #expect(CookingAlarmPlan.systemEffect(old: .paused, new: nil) == nil)
    }

    @Test("A mirrored press is stamped with AlarmKit's instant, not the observe time")
    func systemInstant() {
        // Lock Screen pause 3 minutes before the app woke up: the frozen
        // remaining must be AlarmKit's 300 s, so now = endsAt - 300.
        #expect(CookingAlarmPlan.systemInstant(
            .pause,
            press: .init(pausedRemaining: 300),
            endsAt: 1_000,
            pausedRemaining: nil,
            observedAt: 10_000
        ) == 700)
        // Lock Screen resume: AlarmKit's new fire date decides now, so
        // endsAt = now + remaining lands exactly on it.
        #expect(CookingAlarmPlan.systemInstant(
            .resume,
            press: .init(resumedFireDate: 10_300),
            endsAt: nil,
            pausedRemaining: 300,
            observedAt: 10_000
        ) == 10_000)
        // Stop carries no instant.
        #expect(CookingAlarmPlan.systemInstant(
            .stop,
            press: .init(),
            endsAt: nil,
            pausedRemaining: nil,
            observedAt: 10_000
        ) == 10_000)
        // Anything AlarmKit did not report falls back to the observe time.
        #expect(CookingAlarmPlan.systemInstant(
            .pause,
            press: .init(),
            endsAt: 1_000,
            pausedRemaining: nil,
            observedAt: 10_000
        ) == 10_000)
        #expect(CookingAlarmPlan.systemInstant(
            .resume,
            press: .init(resumedFireDate: 10_300),
            endsAt: nil,
            pausedRemaining: nil,
            observedAt: 10_000
        ) == 10_000)
    }
}
