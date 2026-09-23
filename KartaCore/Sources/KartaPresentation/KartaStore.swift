import Foundation
import Observation
import KartaCore

/// The value state shared by the presentation store and its pure reducer.
public struct KartaState: Equatable, Sendable {
    public var cookbook: Cookbook
    public var session: CookingSession?
    public var navigation: AppNavigationState
    public var filterState: FilterState

    /// The safety profile is kept separate from the non-safety draft.
    public var safetyProfile: SafetyProfile { filterState.safetyProfile }

    /// The time, difficulty and one-pan controls currently applied.
    public var filterDraft: FilterDraft { filterState.filterDraft }

    /// The single effective filter value consumed by Core queries.
    public var effectiveFeedFilters: FeedFilters {
        filterState.effectiveFeedFilters
    }

    /// Compatibility spelling for the effective query consumed by the shell.
    public var feedFilters: FeedFilters { effectiveFeedFilters }

    public init(
        cookbook: Cookbook = Cookbook(),
        session: CookingSession? = nil,
        navigation: AppNavigationState = AppNavigationState(),
        safetyProfile: SafetyProfile = SafetyProfile(intolerances: []),
        filterDraft: FilterDraft = FilterDraft()
    ) {
        self.cookbook = cookbook
        self.session = session
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
    case downgradeCookbookToFree
    case startCooking(Recipe)
    case nextStep
    case previousStep
    case exitCooking
    case respond(CookOutcome)
    case inferProbablyCooked(dwellSeconds: TimeInterval)
    case startTimer(now: TimeInterval)
    case selectWorld(World)
    case setFeedAnchor(ScrollAnchor?, world: World)
    case filter(FilterAction)
    case pushRoute(Route)
    case popRoute
}

/// Pure state transitions for the presentation layer.
public enum KartaReducer {

    public static func reduce(_ state: inout KartaState, action: KartaAction) {
        switch action {
        case let .saveRecipe(id):
            state.cookbook.save(id)
        case let .unsaveRecipe(id):
            state.cookbook.unsave(id)
        case .downgradeCookbookToFree:
            state.cookbook.downgradeToFree()
        case let .startCooking(recipe):
            state.session = recipe.cookingSession()
        case .nextStep:
            state.session?.next()
        case .previousStep:
            state.session?.previous()
        case .exitCooking:
            state.session?.exit()
        case let .respond(outcome):
            state.session?.respond(outcome)
        case let .inferProbablyCooked(dwellSeconds):
            state.session?.inferProbablyCooked(dwellSeconds: dwellSeconds)
        case let .startTimer(now):
            state.session?.startTimer(now: now)
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

    public init(state: KartaState = KartaState()) {
        self.state = state
    }

    /// Apply one presentation action through the pure reducer.
    public func send(_ action: Action) {
        KartaReducer.reduce(&state, action: action)
    }
}
