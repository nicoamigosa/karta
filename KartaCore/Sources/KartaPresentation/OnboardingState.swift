import Foundation
import KartaCore

/// The explicit answer to the safety question. An empty set is meaningful only
/// after the user has chosen the no-intolerances answer.
public enum IntoleranceAnswer: Equatable, Sendable {
    case unanswered
    case answered(Set<Allergen>)
}

/// Actions from the onboarding flow that belong in the shared presentation
/// store rather than mutating the shell's local state.
public enum OnboardingAction: Sendable {
    case answerIntolerances(Set<Allergen>)
    case setHouseholdSize(Int)
    case tapCalibration(String)
}

/// Presentation state for the onboarding questions and taste calibration.
/// Feed construction is optional until the required onboarding answers exist.
public struct OnboardingState: Equatable, Sendable {
    public private(set) var intoleranceAnswer: IntoleranceAnswer
    public private(set) var householdSize: Int?
    public private(set) var calibration: TasteCalibration

    public init(
        intoleranceAnswer: IntoleranceAnswer = .unanswered,
        householdSize: Int? = nil,
        calibration: TasteCalibration = TasteCalibration()
    ) {
        if let householdSize {
            precondition(householdSize > 0, "householdSize must be positive")
        }
        self.intoleranceAnswer = intoleranceAnswer
        self.householdSize = householdSize
        self.calibration = calibration
    }

    /// The completed profile, or `nil` while either required answer is absent.
    public var profile: OnboardingProfile? {
        guard case let .answered(intolerances) = intoleranceAnswer,
              let householdSize else { return nil }
        return OnboardingProfile(
            intolerances: intolerances,
            householdSize: householdSize
        )
    }

    public var tastePreferences: TastePreferences {
        calibration.preferences
    }

    /// A card is renderable only after the required onboarding answers exist.
    public func cardPresentation(for recipe: Recipe) -> RecipeCardPresentation? {
        guard profile != nil, let householdSize else { return nil }
        return RecipeCardPresentation(recipe: recipe, householdSize: householdSize)
    }

    public mutating func answerIntolerances(_ intolerances: Set<Allergen>) {
        intoleranceAnswer = .answered(intolerances)
    }

    public mutating func setHouseholdSize(_ householdSize: Int) {
        precondition(householdSize > 0, "householdSize must be positive")
        self.householdSize = householdSize
    }

    /// Calibration is deliberately independent from Cookbook saving.
    public mutating func tapCalibration(_ recipeID: String) {
        calibration.tap(recipeID)
    }
}
