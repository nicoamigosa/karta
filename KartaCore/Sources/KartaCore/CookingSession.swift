import Foundation

/// An ingredient used by a cooking step, identified by the recipe ingredient's
/// stable id and carrying the amount used at that step.
public struct StepIngredient: Codable, Equatable, Sendable {
    public let ingredientID: String
    public let quantity: String

    public init(ingredientID: String, quantity: String) {
        self.ingredientID = ingredientID
        self.quantity = quantity
    }
}

/// A self-contained Paso with its Resumen, Detalle and ingredient quantities.
public struct CookingStep: Codable, Equatable, Sendable, ExpressibleByStringLiteral {
    /// Foto del paso; optional until the catalog's step photos are available.
    public let photo: MediaReference?
    /// The editor-written Detalle, shown only in the cooking session.
    public let detail: String
    /// The editor-written Resumen; catalog validation limits it to 36 characters.
    public let summary: String
    public let ingredients: [StepIngredient]
    public let isOptional: Bool
    /// Optional countdown for a timed action ("simmer 10 min" → 600), in seconds.
    public let timerSeconds: Int?
    /// Optional reference to a reusable technique clip, by id. Steps with no
    /// useful clip have no video. The clip itself lives in a shared library so
    /// many recipes reference the same clip without duplicating it.
    public let clipID: String?

    public init(
        detail: String,
        summary: String? = nil,
        ingredients: [StepIngredient] = [],
        timerSeconds: Int? = nil,
        clipID: String? = nil,
        isOptional: Bool = false,
        photo: MediaReference? = nil
    ) {
        self.photo = photo
        self.detail = detail
        self.summary = summary ?? detail
        self.ingredients = ingredients
        self.timerSeconds = timerSeconds
        self.clipID = clipID
        self.isOptional = isOptional
    }

    /// Convenience for programmatic sessions. Catalogs require distinct Resumen
    /// and Detalle, validated when decoding a recipe.
    public init(stringLiteral value: String) {
        self.init(detail: value, summary: value)
    }

    private enum CodingKeys: String, CodingKey {
        case detail, summary, ingredients, timerSeconds, clipID, photo
        case isOptional = "optional"
    }

    /// Catalog steps require an editor-written summary and use an object even
    /// when they carry no ingredients, timer, or technique clip.
    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           (try? single.decode(String.self)) != nil {
            throw DecodingError.dataCorruptedError(
                in: single,
                debugDescription: "A cooking step requires an editor-written summary"
            )
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            detail: try c.decode(String.self, forKey: .detail),
            summary: try c.decode(String.self, forKey: .summary),
            ingredients: try c.decodeIfPresent([StepIngredient].self, forKey: .ingredients) ?? [],
            timerSeconds: try c.decodeIfPresent(Int.self, forKey: .timerSeconds),
            clipID: try c.decodeIfPresent(String.self, forKey: .clipID),
            isOptional: try c.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false,
            photo: try c.decodeIfPresent(MediaReference.self, forKey: .photo)
        )
    }
}

/// A running, paused or finished in-step timer with its original duration.
/// Pure data — elapsed/remaining are computed against an injected clock.
public struct StepTimer: Equatable, Sendable {
    public let startedAt: TimeInterval
    public let duration: TimeInterval

    /// Frozen time left, or nil while running/finished.
    public let pausedRemaining: TimeInterval?
    public var isPaused: Bool { pausedRemaining != nil }

    public init(startedAt: TimeInterval, duration: TimeInterval, pausedRemaining: TimeInterval? = nil) {
        self.startedAt = startedAt
        self.duration = duration
        self.pausedRemaining = pausedRemaining
    }

    /// Seconds left at `now`, floored at zero.
    public func remaining(at now: TimeInterval) -> TimeInterval {
        pausedRemaining ?? max(duration - (now - startedAt), 0)
    }

    /// Whether the countdown has reached zero by `now`.
    public func hasFired(at now: TimeInterval) -> Bool {
        !isPaused && now - startedAt >= duration
    }
}

extension Recipe {
    /// Open cooking mode for this recipe: a fresh `CookingSession` over its own
    /// structured steps. This is the seam between the static recipe and the
    /// runtime cooking state machine.
    public func cookingSession(
        startedAt: TimeInterval = 0,
        intolerances: Set<Allergen> = []
    ) -> CookingSession {
        CookingSession(
            recipeID: id,
            recipeName: name,
            steps: visibleSteps(for: intolerances),
            declaredDuration: TimeInterval(totalMinutes) * 60,
            startedAt: startedAt
        )
    }
}

/// How a finished cook turned out, captured by the "How did it turn out?" prompt.
public enum CookOutcome: String, Equatable, Sendable {
    case thumbsUp   // 👍
    case thumbsDown // 👎
    case photo      // 📷
}

/// The core success signal: the user reached the end of a recipe and (explicitly
/// or by inference) cooked it.
public struct CookedEvent: Equatable, Sendable {
    public let recipeID: String
    public let outcome: CookOutcome?
    /// True when emitted by the session inference rather than an explicit tap.
    public let wasInferred: Bool

    public init(recipeID: String, outcome: CookOutcome?, wasInferred: Bool) {
        self.recipeID = recipeID
        self.outcome = outcome
        self.wasInferred = wasInferred
    }
}

/// Step-by-step cooking mode modeled as a UI-independent state machine.
///
/// The session walks an ordered list of `CookingStep`s. Navigation clamps at the
/// boundaries; exiting is terminal. Reaching the last step is the gateway to the
/// success signal (`cooked`), which may be explicit or inferred from the complete journey.
public struct CookingSession: Equatable, Sendable {
    public let recipeID: String
    /// Recipe name retained for alarms when the session is restored.
    public let recipeName: String
    public let steps: [CookingStep]
    /// The recipe's declared preparation time, in seconds.
    public let declaredDuration: TimeInterval
    /// The injected start time used to measure this session deterministically.
    public let startedAt: TimeInterval

    /// Cierre is a separate position; legacy step members still describe the last Paso.
    public private(set) var isOnFinish: Bool = false
    /// The first injected arrival time at Cierre, retained when navigating back.
    public private(set) var finishReachedAt: TimeInterval?

    public private(set) var currentIndex: Int
    public private(set) var isExited: Bool
    /// The emitted success signal once the cook responds (or is inferred), else `nil`.
    public private(set) var cookedEvent: CookedEvent?
    /// Started timers keyed by step index, so a timer survives navigating away
    /// from and back to its step.
    public private(set) var timers: [Int: StepTimer]
    /// ADR 0008 evidence survives Reset and Stop.
    public private(set) var startedTimerSteps: Set<Int>
    /// The furthest step reached during the session. Going back does not erase
    /// evidence of the journey.
    private(set) var furthestIndex: Int
    /// The first injected time at which the session reached the last step.
    public private(set) var lastStepReachedAt: TimeInterval?

    init(
        recipeID: String,
        recipeName: String? = nil,
        steps: [CookingStep],
        declaredDuration: TimeInterval,
        startedAt: TimeInterval,
        currentIndex: Int,
        isExited: Bool,
        cookedEvent: CookedEvent?,
        timers: [Int: StepTimer],
        furthestIndex: Int,
        lastStepReachedAt: TimeInterval?,
        isOnFinish: Bool = false,
        finishReachedAt: TimeInterval? = nil,
        startedTimerSteps: Set<Int>? = nil
    ) {
        self.recipeID = recipeID
        self.recipeName = recipeName ?? recipeID
        self.steps = steps
        self.declaredDuration = declaredDuration
        self.startedAt = startedAt
        self.currentIndex = currentIndex
        self.isExited = isExited
        self.cookedEvent = cookedEvent
        self.timers = isExited ? [:] : timers
        self.startedTimerSteps = (startedTimerSteps ?? []).union(timers.keys)
        self.furthestIndex = furthestIndex
        self.lastStepReachedAt = lastStepReachedAt
        self.isOnFinish = isOnFinish
        self.finishReachedAt = finishReachedAt
    }

    public init(
        recipeID: String,
        recipeName: String? = nil,
        steps: [CookingStep],
        declaredDuration: TimeInterval = 0,
        startedAt: TimeInterval = 0
    ) {
        self.init(
            recipeID: recipeID,
            recipeName: recipeName,
            steps: steps,
            declaredDuration: declaredDuration,
            startedAt: startedAt,
            currentIndex: 0,
            isExited: false,
            cookedEvent: nil,
            timers: [:],
            furthestIndex: 0,
            lastStepReachedAt: nil
        )
    }

    /// The step currently shown, or `nil` if there are no steps.
    public var currentStep: CookingStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    /// Whether the cook is on the final step.
    public var isOnLastStep: Bool {
        !steps.isEmpty && currentIndex == steps.count - 1
    }

    /// How far the session progressed through the ordered steps, from zero to
    /// one. A one-step recipe has no journey to measure.
    public var stepProgress: Double {
        guard steps.count > 1 else { return 0 }
        return Double(furthestIndex) / Double(steps.count - 1)
    }

    /// Elapsed session time at an injected clock value, never negative.
    public func sessionDuration(at now: TimeInterval) -> TimeInterval {
        max(now - startedAt, 0)
    }

    /// Whether the "How did it turn out?" prompt should be shown. An inferred
    /// cook leaves the prompt open so an explicit outcome can enrich it.
    public var showsOutcomePrompt: Bool {
        isOnLastStep && !isExited && (cookedEvent?.wasInferred ?? true)
    }

    /// Record the cook's response to the outcome prompt. Only valid on the last
    /// step; repeated explicit responses are ignored, while an inferred event
    /// is enriched in place. Returns the new or updated event.
    @discardableResult
    public mutating func respond(_ outcome: CookOutcome) -> CookedEvent? {
        guard isOnLastStep, !isExited else { return nil }
        guard cookedEvent?.wasInferred ?? true else { return nil }
        let event = CookedEvent(recipeID: recipeID, outcome: outcome, wasInferred: false)
        cookedEvent = event
        return event
    }

    /// Advance through the Pasos to Cierre, where navigation clamps.
    public mutating func next() {
        advanceToNextStep(at: nil)
    }

    /// Advance through the Pasos to Cierre, recording the first injected arrival
    /// time at the last Paso and at Cierre separately.
    public mutating func next(at now: TimeInterval) {
        advanceToNextStep(at: now)
    }

    private mutating func advanceToNextStep(at now: TimeInterval?) {
        guard !isExited, !steps.isEmpty, !isOnFinish else { return }
        if isOnLastStep {
            isOnFinish = true
            if finishReachedAt == nil { finishReachedAt = now }
            return
        }
        let previousIndex = currentIndex
        currentIndex = min(currentIndex + 1, max(steps.count - 1, 0))
        furthestIndex = max(furthestIndex, currentIndex)
        if previousIndex != currentIndex,
           currentIndex == steps.count - 1,
           lastStepReachedAt == nil {
            lastStepReachedAt = now
        }
    }

    /// Go back to the previous step (swipe-left). Clamps at the first step.
    public mutating func previous() {
        guard !isExited else { return }
        if isOnFinish {
            isOnFinish = false
            return
        }
        currentIndex = max(currentIndex - 1, 0)
    }

    /// A session must account for at least this fraction of the recipe's
    /// declared time before it can be considered a probable cook.
    public static let probablyCookedMinimumDurationRatio: Double = 0.25

    /// Infer a cook from the complete session rather than time spent on the
    /// final step. The session must have traversed a real multi-step journey, started
    /// a declared timer when the recipe has one, and taken long enough to reach
    /// Cierre relative to the recipe's declared time (the final Paso for legacy
    /// callers still on a Paso). Time spent idle after that arrival does not count.
    /// Won't override an explicit response and is ignored after exit.
    @discardableResult
    public mutating func inferProbablyCooked(at now: TimeInterval) -> CookedEvent? {
        let declaredTimerSteps = steps.indices.filter { steps[$0].timerSeconds != nil }
        let startedDeclaredTimer = declaredTimerSteps.isEmpty || declaredTimerSteps.contains { startedTimerSteps.contains($0) }
        // Variant E measures the journey at first arrival at Cierre. Legacy
        // callers on a Paso retain the first-last-Paso timing rule.
        let arrival = isOnFinish ? finishReachedAt : lastStepReachedAt
        let lastedLongEnough = arrival.map { reachedAt in
            now >= reachedAt
                && declaredDuration > 0
                && sessionDuration(at: reachedAt) >= declaredDuration * Self.probablyCookedMinimumDurationRatio
        } ?? false

        guard isOnLastStep,
              !isExited,
              cookedEvent == nil,
              stepProgress >= 1,
              startedDeclaredTimer,
              lastedLongEnough
        else { return nil }

        let event = CookedEvent(recipeID: recipeID, outcome: nil, wasInferred: true)
        cookedEvent = event
        return event
    }

    // MARK: - In-step timers

    /// Start the current step's timer at `now`, if that step declares one.
    /// A running timer keeps its original start; a finished timer can start again.
    /// Starting a timer after exit is ignored.
    public mutating func startTimer(now: TimeInterval) {
        guard !isExited, let seconds = currentStep?.timerSeconds else { return }
        if let timer = timers[currentIndex], !timer.hasFired(at: now) { return }
        timers[currentIndex] = StepTimer(startedAt: now, duration: TimeInterval(seconds))
        startedTimerSteps.insert(currentIndex)
    }

    /// Freeze only a running Temporizador on the current Paso.
    public mutating func pauseTimer(now: TimeInterval) {
        guard !isOnFinish else { return }
        pauseTimer(stepIndex: currentIndex, now: now)
    }

    /// Freeze a running Temporizador on the named Paso, including from Cierre.
    /// Uses the instant of the press, even if a later time was already observed.
    public mutating func pauseTimer(stepIndex: Int, now: TimeInterval) {
        guard !isExited, steps.indices.contains(stepIndex), let timer = timers[stepIndex],
              !timer.isPaused, !timer.hasFired(at: now) else { return }
        timers[stepIndex] = StepTimer(
            startedAt: timer.startedAt, duration: timer.duration,
            pausedRemaining: timer.remaining(at: now)
        )
    }

    /// Resume from the frozen time left, keeping the original duration for progress.
    public mutating func resumeTimer(now: TimeInterval) {
        guard !isOnFinish else { return }
        resumeTimer(stepIndex: currentIndex, now: now)
    }

    /// Resume the named Paso's paused Temporizador without navigating to it.
    public mutating func resumeTimer(stepIndex: Int, now: TimeInterval) {
        guard !isExited, steps.indices.contains(stepIndex), let timer = timers[stepIndex],
              let remaining = timer.pausedRemaining else { return }
        timers[stepIndex] = StepTimer(
            startedAt: now - (timer.duration - remaining), duration: timer.duration
        )
    }

    /// Reset only a paused Temporizador to the declared ready duration.
    public mutating func resetTimer() {
        guard !isExited, !isOnFinish, timers[currentIndex]?.isPaused == true else { return }
        timers.removeValue(forKey: currentIndex)
    }

    /// Stop only a finished Temporizador. The shell supplies time, as for start/pause.
    public mutating func stopTimer(now: TimeInterval) {
        guard !isOnFinish else { return }
        stopTimer(stepIndex: currentIndex, now: now)
    }

    /// Stop the named Paso's finished Temporizador, including from Cierre.
    public mutating func stopTimer(stepIndex: Int, now: TimeInterval) {
        guard !isExited, steps.indices.contains(stepIndex),
              timers[stepIndex]?.hasFired(at: now) == true else { return }
        timers.removeValue(forKey: stepIndex)
    }

    /// Seconds left on the current step's running timer at `now`, or `nil` if none.
    public func currentStepTimerRemaining(at now: TimeInterval) -> TimeInterval? {
        timers[currentIndex]?.remaining(at: now)
    }

    /// Whether the current step's running timer has fired by `now` (false if none).
    public func currentStepTimerHasFired(at now: TimeInterval) -> Bool {
        timers[currentIndex]?.hasFired(at: now) ?? false
    }

    /// Leave the Sesión de cocina, cancelling every Temporizador. Terminal.
    public mutating func exit() {
        isExited = true
        timers.removeAll()
    }
}
