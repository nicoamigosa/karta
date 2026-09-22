import Foundation
import Observation
import KartaCore

/// The value state shared by the presentation store and its pure reducer.
public struct KartaState: Equatable, Sendable {
    public var cookbook: Cookbook
    public var session: CookingSession?

    public init(
        cookbook: Cookbook = Cookbook(),
        session: CookingSession? = nil
    ) {
        self.cookbook = cookbook
        self.session = session
    }
}

/// Inputs accepted by the presentation state machine.
public enum KartaAction: Sendable {
    case saveRecipe(String)
    case unsaveRecipe(String)
    case startCooking(Recipe)
    case nextStep
    case previousStep
    case exitCooking
    case respond(CookOutcome)
    case inferProbablyCooked(dwellSeconds: TimeInterval)
    case startTimer(now: TimeInterval)
}

/// Pure state transitions for the presentation layer.
public enum KartaReducer {

    public static func reduce(_ state: inout KartaState, action: KartaAction) {
        switch action {
        case let .saveRecipe(id):
            state.cookbook.save(id)
        case let .unsaveRecipe(id):
            state.cookbook.unsave(id)
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
