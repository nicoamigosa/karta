import Foundation
import Observation
import KartaCore

private enum FeedPolicy {
    static let recentViewWindow: TimeInterval = 7 * 24 * 60 * 60
}

/// The value state shared by the presentation store and its pure reducer.
public struct KartaState: Equatable, Sendable {
    public internal(set) var leftoversToastHistory = LeftoversToastHistory()
    internal var pendingLeftoversToast: LeftoversToast?

    public internal(set) var shoppingList = ShoppingList()
    public internal(set) var shoppingSheet: ShoppingAddSheet?
    public internal(set) var shoppingToast: ShoppingToast?
    internal var shoppingUndo: ShoppingList.Undo?
    public internal(set) var addRecipesAsSaved = false
    public internal(set) var hasAskedAutoAdd = false
    public internal(set) var showsAutoAddQuestion = false
    internal var askAfterShoppingToast = false
    public internal(set) var showsShoppingInvitation = false
    public internal(set) var showsShoppingList = false
    /// Transient purchase sheet and one-shot restore notice; never persisted.
    public internal(set) var paywall: Paywall?
    public internal(set) var restoreToast: RestoreToast?
    /// Outcome of the latest save attempt, including counts when blocked.
    public fileprivate(set) var lastSaveResult: SaveResult?
    /// Transient Undo receipt; the shell dismisses it when its toast expires.
    public fileprivate(set) var pendingUnsave: Cookbook.UnsaveUndo?
    /// Unknown until the shell reports the App Store result for this launch. Never persisted.
    public fileprivate(set) var entitlement: Entitlement?
    /// Raised after saving; the shell presents it when the save animation ends.
    public fileprivate(set) var pendingSaveToast: SaveToast?
    /// Persist when raised, even while the toast is still visible.
    public fileprivate(set) var hasShownSaveToast: Bool
    /// Opaque legacy user data is carried through every save, never ranked.
    public internal(set) var legacyPayload: StoredJSON?
    /// Transient selection shared by both Cookbook halves, never persisted.
    public fileprivate(set) var isSelectingCookbook = false
    public fileprivate(set) var selectedCookbookRecipeIDs: Set<String> = []
    public var cookbook: Cookbook
    public var onboarding: OnboardingState
    public var viewHistory: ViewHistory
    /// All Cocinados, independent of whether their recipes are currently saved.
    public var cookHistory: [CookEntry]
    /// Transient Feed notice, cleared by the shell after showing it.
    public fileprivate(set) var recipeGoneNotice: RecipeGoneNotice?
    /// Include this value when saving or restoring UserSnapshot.
    public var shareCardHistory: ShareCardHistory
    /// Injected configuration, never persisted; nil disables Share everywhere.
    public var shareBaseURL: URL?
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
    public var safetyProfile: SafetyProfile {
        onboarding.intoleranceAnswer == .unanswered
            ? SafetyProfile(intolerances: Set(Allergen.allCases)) : filterState.safetyProfile
    }

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
        var filters = filterState.effectiveFeedFilters
        filters.intolerances = safetyProfile.intolerances
        return filters
    }

    /// Compatibility spelling for the effective query consumed by the shell.
    public var feedFilters: FeedFilters { effectiveFeedFilters }

    /// Build the Baraja segura while unanswered, otherwise the personal feed.
    /// Gusto and household fit only rank recipes that passed hard filters.
    public func feed(
        recipes: [Recipe],
        views: [ViewEntry],
        recentWindow: TimeInterval,
        clock: any KartaClock
    ) -> Feed? {
        let householdSize = onboarding.householdSize
        return FeedQuery.feed(
            recipes: recipes,
            views: views,
            recentWindow: recentWindow,
            clock: clock,
            filters: effectiveFeedFilters,
            tastePreferences: TastePreferences(recipes: recipes, history: viewHistory, savedIDs: cookbook.savedIDs),
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

    /// For You's emptiness and copy, including all five allergens while unanswered.
    public func feedEmptyState(recipes: [Recipe], clock: any KartaClock) -> FeedEmptyState? {
        guard let feed = feed(recipes: recipes, clock: clock) else { return nil }
        return FeedEmptyState(feed: feed, recipes: recipes, draft: filterDraft, safetyProfile: safetyProfile)
    }

    /// Leftovers ranks shared keys before Gusto and household and has no Frontera.
    public func leftoversFeed(recipes: [Recipe], clock: any KartaClock) -> Feed {
        let suggestions = LeftoversQuery.suggestions(
            recipes: recipes, cooks: cookHistory,
            recentWindow: PurchasePolicy.leftoversWindow, clock: clock,
            filters: effectiveFeedFilters,
            tastePreferences: TastePreferences(recipes: recipes, history: viewHistory, savedIDs: cookbook.savedIDs),
            householdSize: onboarding.householdSize)
        return Feed(newRecipes: suggestions, alreadySeenRecipes: [], hasFrontier: false)
    }

    /// Preview a Mundo with an uncommitted draft and the current safety
    /// profile. Both feed stretches count; the frontier does not.
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
            var preview = self
            preview.filterState.reduce(.apply(draft))
            return preview.leftoversFeed(recipes: recipes, clock: clock).recipes.count
        }
    }

    /// Build the feed Card projection with the active safety profile.
    public func cardPresentation(for recipe: Recipe) -> RecipeCardPresentation? {
        let householdSize = onboarding.householdSize ?? recipe.servings
        guard FeedFilters(intolerances: safetyProfile.intolerances).allows(recipe) else {
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
        guard canOpenRecipe(recipe) else { return nil }
        return RecipeReversePresentation(
            recipe: recipe, intolerances: safetyProfile.intolerances,
            isSaved: cookbook.isSaved(recipe.id), isOnList: shoppingList.contains(recipe.id)
        )
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
        hasShownAlarmPermissionSheet: Bool = false,
        hasShownSaveToast: Bool = false,
        shareBaseURL: URL? = nil,
        shareCardHistory: ShareCardHistory = ShareCardHistory()
    ) {
        self.cookbook = cookbook
        self.onboarding = onboarding
        self.viewHistory = viewHistory
        self.cookHistory = cookHistory
        self.shareCardHistory = shareCardHistory
        self.shareBaseURL = shareBaseURL
        self.session = session
        self.hasShownAlarmPermissionSheet = hasShownAlarmPermissionSheet
        self.hasShownSaveToast = hasShownSaveToast
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
    case shopping(ShoppingAction)
    case shoppingContext(ShoppingAction, recipes: [Recipe], now: Date)
    case paywall(PaywallAction)
    case saveRecipe(String)
    case saveRecipeContext(String, recipes: [Recipe], now: Date)
    case beginCookbookSelection
    case endCookbookSelection
    case toggleCookbookSelection(String)
    case removeCookbookSelection
    /// Cookbook grid context menu: the same removal path as a selection of one.
    case unsaveRecipe(String)
    case undoUnsave
    case dismissSaveToast
    case dismissUnsaveToast
    case recordView(recipeID: String, at: Date)
    case recordOpen(recipeID: String, at: Date)
    /// Record an emitted Cocinado with its date supplied by the shell.
    case recordCook(CookEntry)
    case entitlementChanged(Entitlement)
    @available(*, deprecated, message: "Report entitlementChanged(.free) instead")
    case downgradeCookbookToFree
    case onboarding(OnboardingAction)
    case startCooking(Recipe, startedAt: TimeInterval)
    case nextStep(now: TimeInterval)
    case previousStep
    case dismissRecipeGoneNotice
    /// Shared means tapping Share, regardless of what happens in the native sheet.
    /// Swipe, timeout and VoiceOver dismissal all send dismissed.
    case closeShareCard(ShareCardHistory.Close)
    case exitCooking
    case exitCookingContext(recipes: [Recipe], now: Date)
    case closeLeftoversToast(LeftoversToastHistory.Close)
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

    private static func removeCookbookRecipes(_ state: inout KartaState, ids: [String]) {
        // Removal belongs to the grid; an open reverse never removes or creates a toast.
        guard state.navigation.routes.isEmpty else { return }
        state.pendingSaveToast = nil
        state.lastSaveResult = nil
        state.pendingUnsave = state.cookbook.unsave(ids)
        state.isSelectingCookbook = false
        state.selectedCookbookRecipeIDs = []
    }

    public static func reduce(_ state: inout KartaState, action: KartaAction) {
        switch action {
        case let .shopping(action):
            reduceShopping(&state, action: action, recipes: [], now: nil)
        case let .shoppingContext(action, recipes, now):
            reduceShopping(&state, action: action, recipes: recipes, now: now)
        case let .paywall(action):
            reducePaywall(&state, action: action)
        case let .saveRecipeContext(id, recipes, now):
            reduce(&state, action: .saveRecipe(id))
            if state.lastSaveResult == .saved, state.hasShoppingPremium, state.addRecipesAsSaved,
               let recipe = recipes.first(where: { $0.id == id }), state.canOpenRecipe(recipe) {
                autoAddSavedRecipe(&state, recipe: recipe, recipes: recipes, now: now)
            }
        case let .saveRecipe(id):
            state.pendingSaveToast = nil
            state.pendingUnsave = nil
            state.lastSaveResult = state.cookbook.save(id)
            if state.lastSaveResult == .saved, state.entitlement == .free,
               let ceiling = state.cookbook.saveCap,
               ceiling - state.cookbook.savedIDs.count == 1,
               !state.hasShownSaveToast {
                state.hasShownSaveToast = true
                state.pendingSaveToast = SaveToast(recipeID: id)
            }
        case .beginCookbookSelection:
            guard !state.cookbook.savedIDs.isEmpty else { return }
            state.isSelectingCookbook = true
        case .endCookbookSelection:
            state.isSelectingCookbook = false
            state.selectedCookbookRecipeIDs = []
        case let .toggleCookbookSelection(id):
            guard state.isSelectingCookbook, state.cookbook.isSaved(id) else { return }
            if !state.selectedCookbookRecipeIDs.insert(id).inserted {
                state.selectedCookbookRecipeIDs.remove(id)
            }
        case .removeCookbookSelection:
            guard state.isSelectingCookbook, !state.selectedCookbookRecipeIDs.isEmpty else { return }
            removeCookbookRecipes(&state, ids: Array(state.selectedCookbookRecipeIDs))
        case let .unsaveRecipe(id):
            removeCookbookRecipes(&state, ids: [id])
        case .undoUnsave:
            state.pendingSaveToast = nil
            state.lastSaveResult = nil
            if let removal = state.pendingUnsave {
                state.cookbook.undoUnsave(removal)
            }
            state.pendingUnsave = nil
        case .dismissSaveToast:
            state.pendingSaveToast = nil
        case .dismissUnsaveToast:
            state.pendingUnsave = nil
        case let .recordView(recipeID, date):
            state.viewHistory.recordView(recipeID: recipeID, at: date)
        case let .recordOpen(recipeID, date):
            state.viewHistory.recordOpen(recipeID: recipeID, at: date)
        case let .recordCook(entry):
            state.cookHistory.append(entry)
        case .downgradeCookbookToFree:
            reduce(&state, action: .entitlementChanged(.free))
        case let .entitlementChanged(entitlement):
            guard state.entitlement != entitlement else { return }
            state.entitlement = entitlement
            state.pendingSaveToast = nil
            state.lastSaveResult = nil
            state.pendingUnsave = nil
            switch entitlement {
            case .free:
                state.cookbook.downgradeToFree()
                state.addRecipesAsSaved = false
                state.shoppingSheet = nil
                state.showsAutoAddQuestion = false
                state.askAfterShoppingToast = false
            case .trial, .premium: state.cookbook.liftCupo()
            }
        case let .onboarding(action):
            let previousFilters = state.effectiveFeedFilters
            let submitsFirstRun: Bool
            if case .showMyCards = action {
                submitsFirstRun = state.onboarding.panel == .firstRun
                    && state.onboarding.firstRunPanel.canShowCards
            } else {
                submitsFirstRun = false
            }
            state.onboarding.reduce(action)
            switch action {
            case .answerIntolerances:
                if case let .answered(intolerances) = state.onboarding.intoleranceAnswer {
                    state.filterState.reduce(.setSafetyProfile(SafetyProfile(intolerances: intolerances)))
                }
            case .showMyCards where submitsFirstRun:
                state.filterState.reduce(.setSafetyProfile(
                    SafetyProfile(intolerances: state.onboarding.firstRunPanel.intolerances)))
            default: break
            }
            if submitsFirstRun || state.effectiveFeedFilters != previousFilters {
                state.navigation.discardAnchors()
            }
        case let .startCooking(recipe, startedAt):
            state.pendingLeftoversToast = nil
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
        case .dismissRecipeGoneNotice:
            state.recipeGoneNotice = nil
        case let .closeShareCard(action):
            guard state.shareBaseURL != nil, let session = state.session,
                  !session.isExited, session.isOnFinish,
                  state.shareCardHistory.offersCard(for: session.cookedEvent) else { return }
            state.shareCardHistory.close(for: session.recipeID, as: action)
        case let .exitCookingContext(recipes, now):
            guard state.session?.isExited == false else { return }
            reduce(&state, action: .exitCooking)
            offerLeftoversToast(&state, recipes: recipes, now: now)
        case let .closeLeftoversToast(action):
            guard state.pendingLeftoversToast != nil else { return }
            if case .see = action, state.leftoversToast == nil { return }
            state.leftoversToastHistory.close(as: action)
            state.pendingLeftoversToast = nil
            if case .see = action {
                state.navigation.setAnchor(nil, for: .leftovers)
                state.navigation.selectWorld(.leftovers)
            }
        case .exitCooking:
            reduce(&state, action: .closeShareCard(.dismissed))
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
            if case let .setSafetyProfile(profile) = action,
               case .answered = state.onboarding.intoleranceAnswer {
                state.onboarding.answerIntolerances(profile.intolerances)
            }
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

    private let recipes: [Recipe]
    private let clock: (any KartaClock)?

    public init(state: KartaState, recipes: [Recipe] = [], clock: (any KartaClock)? = nil) {
        self.state = state
        self.recipes = recipes
        self.clock = clock
    }

    /// Apply one presentation action through the pure reducer.
    public func send(_ action: Action) {
        if case .exitCooking = action, let clock {
            KartaReducer.reduce(&state, action: .exitCookingContext(recipes: recipes, now: clock.now))
        } else if case let .saveRecipe(id) = action, let clock {
            KartaReducer.reduce(&state, action: .saveRecipeContext(id, recipes: recipes, now: clock.now))
        } else if case let .shopping(shopping) = action, let clock {
            KartaReducer.reduce(&state, action: .shoppingContext(shopping, recipes: recipes, now: clock.now))
        } else {
            KartaReducer.reduce(&state, action: action)
        }
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

    /// Resolve a shared link using current catalogue and safety state. Dates come
    /// from the shell so an Apertura has the same deterministic history seam.
    public func openRecipeLink(_ url: URL, recipes: [Recipe], at date: Date) -> RecipeLinkOpening {
        guard let id = RecipeShare(baseURL: state.shareBaseURL).recipeID(for: url) else { return .ignored }
        guard let recipe = recipes.first(where: { $0.id == id }) else {
            state.navigation = AppNavigationState()
            state.pendingLeftoversToast = nil
            state.recipeGoneNotice = RecipeGoneNotice()
            return .gone
        }
        // A shared link proposes a recipe, so saved-recipe warning exceptions
        // never weaken the receiver's Intolerancias guarantee.
        guard FeedFilters(intolerances: state.safetyProfile.intolerances).allows(recipe),
              let reverse = state.reversePresentation(for: recipe) else { return .notOffered }
        send(.recordOpen(recipeID: id, at: date))
        send(.pushRoute(.recipeDetail(recipeID: id)))
        return .reverse(reverse)
    }
}
