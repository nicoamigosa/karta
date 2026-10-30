import Foundation
import Observation
import KartaCore

private enum FeedPolicy {
    static let recentViewWindow: TimeInterval = 7 * 24 * 60 * 60
}

/// The value state shared by the presentation store and its pure reducer.
public struct KartaState: Equatable, Sendable {
    /// Outcome of the latest save attempt, including counts when blocked.
    public fileprivate(set) var lastSaveResult: SaveResult?
    /// Transient Undo receipt; the shell dismisses it when its toast expires.
    public fileprivate(set) var pendingUnsave: Cookbook.UnsaveUndo?
    public var cookbook: Cookbook
    public var onboarding: OnboardingState
    public var viewHistory: ViewHistory
    /// All Cocinados, independent of whether their recipes are currently saved.
    public var cookHistory: [CookEntry]
    public var session: CookingSession?
    /// Transient sheet visibility. Both OK and Open Settings dismiss it.
    public fileprivate(set) var showsAlarmPermissionSheet = false
    /// Persist this fact in UserSnapshot, independently of the cooking session.
    public fileprivate(set) var hasShownAlarmPermissionSheet: Bool
    /// The history slot emitted by this session, independent of older cooks.
    fileprivate var sessionCookHistoryIndex: Int?
    public var navigation: AppNavigationState
    public var filterState: FilterState

    /// The safety profile is kept separate from the non-safety draft.
    public var safetyProfile: SafetyProfile { filterState.safetyProfile }

    /// The non-safety filters currently applied across both Mundos.
    public var filterDraft: FilterDraft { filterState.filterDraft }

    /// Badge count for applied non-safety filters. Zero means no badge;
    /// Intolerancias never contribute, regardless of how many are declared.
    public var appliedFilterCount: Int {
        (filterDraft.maxMinutes == nil ? 0 : 1)
            + (filterDraft.maxDifficulty == nil ? 0 : 1)
            + (filterDraft.course == nil ? 0 : 1)
            + (filterDraft.diet == nil ? 0 : 1)
            + filterDraft.practicalTags.count
    }

    /// The single effective filter value consumed by Core queries.
    public var effectiveFeedFilters: FeedFilters {
        filterState.effectiveFeedFilters
    }

    /// Compatibility spelling for the effective query consumed by the shell.
    public var feedFilters: FeedFilters { effectiveFeedFilters }

    /// Build the feed only after onboarding is complete. The active safety
    /// profile is composed here, while taste and household signals remain
    /// ranking inputs and never become filters.
    public func feed(
        recipes: [Recipe],
        views: [ViewEntry],
        recentWindow: TimeInterval,
        clock: any KartaClock
    ) -> Feed? {
        guard onboarding.profile != nil,
              let householdSize = onboarding.householdSize else { return nil }
        return FeedQuery.feed(
            recipes: recipes,
            views: views,
            recentWindow: recentWindow,
            clock: clock,
            filters: effectiveFeedFilters,
            tastePreferences: onboarding.tastePreferences,
            householdSize: householdSize
        )
    }

    /// Build the feed from this state's view history and presentation policy.
    public func feed(recipes: [Recipe], clock: any KartaClock) -> Feed? {
        feed(
            recipes: recipes,
            views: viewHistory.entries,
            recentWindow: FeedPolicy.recentViewWindow,
            clock: clock
        )
    }

    /// For You's emptiness and copy, using the applied draft. Unavailable
    /// before onboarding, just like the feed itself.
    public func feedEmptyState(recipes: [Recipe], clock: any KartaClock) -> FeedEmptyState? {
        guard let feed = feed(recipes: recipes, clock: clock) else { return nil }
        return FeedEmptyState(feed: feed, recipes: recipes, draft: filterDraft, safetyProfile: safetyProfile)
    }

    /// Preview a Mundo with an uncommitted draft and the current safety
    /// profile. Both feed stretches count; the frontier does not. Leftovers
    /// remains unavailable until its store integration in #9.
    public func draftRecipeCount(
        for world: World,
        draft: FilterDraft,
        recipes: [Recipe],
        clock: any KartaClock
    ) -> Int? {
        switch world {
        case .forYou:
            var preview = self
            preview.filterState.reduce(.apply(draft))
            return preview.feed(recipes: recipes, clock: clock)?.recipes.count
        case .leftovers:
            return nil
        }
    }

    /// Build the feed Card projection with the active safety profile.
    public func cardPresentation(for recipe: Recipe) -> RecipeCardPresentation? {
        guard onboarding.profile != nil,
              let householdSize = onboarding.householdSize,
              FeedFilters(intolerances: safetyProfile.intolerances).allows(recipe) else {
            return nil
        }
        return RecipeCardPresentation(
            recipe: recipe,
            householdSize: householdSize,
            intolerances: safetyProfile.intolerances
        )
    }

    /// Reviewed deliberate saves remain openable after a new intolerance.
    /// Feed Cards retain their stricter safety boundary.
    func canOpenRecipe(_ recipe: Recipe) -> Bool {
        guard case .reviewed = recipe.allergenReview else { return false }
        return cookbook.isSaved(recipe.id)
            || FeedFilters(intolerances: safetyProfile.intolerances).allows(recipe)
    }

    /// Build the reverse, including warnings for saved recipes.
    public func reversePresentation(for recipe: Recipe) -> RecipeReversePresentation? {
        guard onboarding.profile != nil, canOpenRecipe(recipe) else { return nil }
        return RecipeReversePresentation(recipe: recipe, intolerances: safetyProfile.intolerances)
    }

    public init(
        cookbook: Cookbook = Cookbook(),
        onboarding: OnboardingState = OnboardingState(),
        viewHistory: ViewHistory = ViewHistory(),
        cookHistory: [CookEntry] = [],
        session: CookingSession? = nil,
        navigation: AppNavigationState = AppNavigationState(),
        safetyProfile: SafetyProfile,
        filterDraft: FilterDraft = FilterDraft(),
        hasShownAlarmPermissionSheet: Bool = false
    ) {
        self.cookbook = cookbook
        self.onboarding = onboarding
        self.viewHistory = viewHistory
        self.cookHistory = cookHistory
        self.session = session
        self.hasShownAlarmPermissionSheet = hasShownAlarmPermissionSheet
        // Automatic Cierre inference has a persisted date: its first arrival.
        // Reconnect that history entry so a resumed answer enriches it in place.
        if let session, session.cookedEvent?.wasInferred == true,
           let arrival = session.finishReachedAt {
            self.sessionCookHistoryIndex = cookHistory.lastIndex {
                $0.recipeID == session.recipeID && $0.wasInferred
                    && $0.date == Date(timeIntervalSince1970: arrival)
            }
        }
        self.navigation = navigation
        self.filterState = FilterState(
            safetyProfile: safetyProfile,
            filterDraft: filterDraft
        )
    }
}

/// Inputs accepted by the presentation state machine.
public enum KartaAction: Sendable {
    case saveRecipe(String)
    case unsaveRecipe(String)
    case undoUnsave
    case dismissUnsaveToast
    case recordView(recipeID: String, at: Date)
    case recordOpen(recipeID: String, at: Date)
    /// Record an emitted Cocinado with its date supplied by the shell.
    case recordCook(CookEntry)
    case downgradeCookbookToFree
    case onboarding(OnboardingAction)
    case startCooking(Recipe, startedAt: TimeInterval)
    case nextStep(now: TimeInterval)
    case previousStep
    case exitCooking
    case respond(CookOutcome)
    case inferProbablyCooked(now: TimeInterval)
    case startTimer(now: TimeInterval)
    case pauseTimer(now: TimeInterval)
    /// AlarmKit presses target a session Paso by its zero-based index.
    case pauseTimerAtStep(stepIndex: Int, now: TimeInterval)
    case resumeTimer(now: TimeInterval)
    case resumeTimerAtStep(stepIndex: Int, now: TimeInterval)
    case resetTimer
    case stopTimer(now: TimeInterval)
    case stopTimerAtStep(stepIndex: Int, now: TimeInterval)
    /// The shell reports denial after requesting AlarmKit permission on start.
    case alarmPermissionDenied
    case dismissAlarmPermissionSheet
    case selectWorld(World)
    case setFeedAnchor(ScrollAnchor?, world: World)
    case filter(FilterAction)
    case pushRoute(Route)
    case popRoute

    /// Keep the current-Paso case while allowing an explicitly named Paso.
    /// Distinct indexed case names keep Swift's reducer patterns unambiguous.
    public static func pauseTimer(stepIndex: Int, now: TimeInterval) -> Self {
        .pauseTimerAtStep(stepIndex: stepIndex, now: now)
    }

    public static func resumeTimer(stepIndex: Int, now: TimeInterval) -> Self {
        .resumeTimerAtStep(stepIndex: stepIndex, now: now)
    }

    public static func stopTimer(stepIndex: Int, now: TimeInterval) -> Self {
        .stopTimerAtStep(stepIndex: stepIndex, now: now)
    }
}

/// Pure state transitions for the presentation layer.
public enum KartaReducer {

    public static func reduce(_ state: inout KartaState, action: KartaAction) {
        switch action {
        case let .saveRecipe(id):
            state.pendingUnsave = nil
            state.lastSaveResult = state.cookbook.save(id)
        case let .unsaveRecipe(id):
            state.lastSaveResult = nil
            state.pendingUnsave = state.cookbook.unsave(id)
        case .undoUnsave:
            state.lastSaveResult = nil
            if let removal = state.pendingUnsave {
                state.cookbook.undoUnsave(removal)
            }
            state.pendingUnsave = nil
        case .dismissUnsaveToast:
            state.pendingUnsave = nil
        case let .recordView(recipeID, date):
            state.viewHistory.recordView(recipeID: recipeID, at: date)
        case let .recordOpen(recipeID, date):
            state.viewHistory.recordOpen(recipeID: recipeID, at: date)
        case let .recordCook(entry):
            state.cookHistory.append(entry)
        case .downgradeCookbookToFree:
            state.lastSaveResult = nil
            state.pendingUnsave = nil
            state.cookbook.downgradeToFree()
        case let .onboarding(action):
            let previousFilters = state.effectiveFeedFilters
            switch action {
            case let .answerIntolerances(intolerances):
                state.onboarding.answerIntolerances(intolerances)
                state.filterState.reduce(
                    .setSafetyProfile(SafetyProfile(intolerances: intolerances))
                )
            case let .setHouseholdSize(householdSize):
                state.onboarding.setHouseholdSize(householdSize)
            case let .tapCalibration(recipeID):
                state.onboarding.tapCalibration(recipeID)
            }
            if state.effectiveFeedFilters != previousFilters {
                state.navigation.discardAnchors()
            }
        case let .startCooking(recipe, startedAt):
            state.sessionCookHistoryIndex = nil
            state.session = recipe.cookingSession(
                startedAt: startedAt,
                intolerances: state.safetyProfile.intolerances
            )
        case let .nextStep(now):
            let firstArrival = state.session.map { !$0.isOnFinish && $0.finishReachedAt == nil } ?? false
            state.session?.next(at: now)
            if firstArrival, state.session?.isOnFinish == true,
               let event = state.session?.inferProbablyCooked(at: now) {
                state.sessionCookHistoryIndex = state.cookHistory.count
                state.cookHistory.append(CookEntry(event: event, date: Date(timeIntervalSince1970: now)))
            }
        case .previousStep:
            state.session?.previous()
        case .exitCooking:
            state.session?.exit()
        case let .respond(outcome):
            if let event = state.session?.respond(outcome), let session = state.session {
                // A one-step session starts on its last step. Legacy sessions
                // without step timing also fall back to the injected start.
                let date = Date(timeIntervalSince1970: session.lastStepReachedAt ?? session.startedAt)
                let entry = CookEntry(event: event, date: date)
                if let index = state.sessionCookHistoryIndex {
                    state.cookHistory[index] = entry
                } else {
                    state.sessionCookHistoryIndex = state.cookHistory.count
                    state.cookHistory.append(entry)
                }
            }
        case let .inferProbablyCooked(now):
            if let event = state.session?.inferProbablyCooked(at: now) {
                state.sessionCookHistoryIndex = state.cookHistory.count
                state.cookHistory.append(CookEntry(event: event, date: Date(timeIntervalSince1970: now)))
            }
        case let .startTimer(now):
            state.session?.startTimer(now: now)
        case let .pauseTimer(now):
            state.session?.pauseTimer(now: now)
        case let .pauseTimerAtStep(stepIndex, now):
            state.session?.pauseTimer(stepIndex: stepIndex, now: now)
        case let .resumeTimer(now):
            state.session?.resumeTimer(now: now)
        case let .resumeTimerAtStep(stepIndex, now):
            state.session?.resumeTimer(stepIndex: stepIndex, now: now)
        case .resetTimer:
            state.session?.resetTimer()
        case let .stopTimer(now):
            state.session?.stopTimer(now: now)
        case let .stopTimerAtStep(stepIndex, now):
            state.session?.stopTimer(stepIndex: stepIndex, now: now)
        case .alarmPermissionDenied:
            guard !state.hasShownAlarmPermissionSheet else { return }
            state.hasShownAlarmPermissionSheet = true
            state.showsAlarmPermissionSheet = true
        case .dismissAlarmPermissionSheet:
            state.showsAlarmPermissionSheet = false
        case let .selectWorld(world):
            state.navigation.selectWorld(world)
        case let .setFeedAnchor(anchor, world):
            state.navigation.setAnchor(anchor, for: world)
        case let .filter(action):
            let previousFilters = state.effectiveFeedFilters
            state.filterState.reduce(action)
            guard state.effectiveFeedFilters != previousFilters else { return }
            state.navigation.discardAnchors()
        case let .pushRoute(route):
            state.navigation.push(route)
        case .popRoute:
            state.navigation.pop()
        }
    }
}

/// The single observable object consumed by the iOS shell.
@MainActor
@Observable
public final class KartaStore {
    public typealias Action = KartaAction

    public private(set) var state: KartaState

    /// The user's saved recipes, exposed as a read-only value snapshot.
    public var cookbook: Cookbook { state.cookbook }

    /// The active cooking session, exposed as a read-only value snapshot.
    public var session: CookingSession? { state.session }

    public init(state: KartaState) {
        self.state = state
    }

    /// Apply one presentation action through the pure reducer.
    public func send(_ action: Action) {
        KartaReducer.reduce(&state, action: action)
    }

    /// The shell's read seam for the current feed.
    public func feed(
        recipes: [Recipe],
        views: [ViewEntry],
        recentWindow: TimeInterval,
        clock: any KartaClock
    ) -> Feed? {
        state.feed(
            recipes: recipes,
            views: views,
            recentWindow: recentWindow,
            clock: clock
        )
    }

    /// The shell's feed seam; view history and its recency window are owned by
    /// the presentation state.
    public func feed(recipes: [Recipe], clock: any KartaClock) -> Feed? {
        state.feed(recipes: recipes, clock: clock)
    }

    /// The shell's For You empty-state projection.
    public func feedEmptyState(recipes: [Recipe], clock: any KartaClock) -> FeedEmptyState? {
        state.feedEmptyState(recipes: recipes, clock: clock)
    }

    /// The shell-facing projection for a recipe Card, using the store's profile.
    public func cardPresentation(for recipe: Recipe) -> RecipeCardPresentation? {
        state.cardPresentation(for: recipe)
    }

    /// The shell-facing projection for the Card reverse, using the store's profile.
    public func reversePresentation(for recipe: Recipe) -> RecipeReversePresentation? {
        state.reversePresentation(for: recipe)
    }
}
