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
    case coldLaunch(reduceMotion: Bool)
    case tourDelayElapsed
    case tourTap
    case filterButtonTapped
    case setMine
    case closePanel
    case toggleFirstRunAllergen(Allergen)
    case chooseFirstRunHousehold(Int)
    case showMyCards
}

/// First-open answers and transient panel/tour state. Unanswered users can
/// already use the Baraja segura.
public struct OnboardingState: Equatable, Sendable {
    public private(set) var intoleranceAnswer: IntoleranceAnswer
    public private(set) var householdSize: Int?
    public private(set) var tourStop: TourStop?
    public private(set) var hasShownFullTour: Bool
    public private(set) var panel: Panel?
    public private(set) var reduceMotion = false
    public private(set) var firstRunPanel = FirstRunPanel()

    public enum Panel: Equatable, Sendable { case firstRun, full }
    public enum TourStop: Int, Equatable, Sendable {
        case cookbook = 1, world, filters
        public var title: String {
            switch self {
            case .cookbook: "Your cookbook"
            case .world: "For You or Leftovers"
            case .filters: "Start here"
            }
        }
        public var line: String {
            switch self {
            case .cookbook: "What you save lives here."
            case .world: "Switch decks here."
            case .filters: "Tell us what you never eat. We'll never show it."
            }
        }
        public var progress: String { "\(rawValue) OF 3" }
        public var delay: TimeInterval? { self == .filters ? nil : 1.2 }
    }

    public var banner: SafeDeckBanner? {
        intoleranceAnswer == .unanswered ? SafeDeckBanner() : nil
    }
    public var tourSkipLine: String? {
        tourStop == .cookbook || tourStop == .world ? "Tap anywhere to skip to the filter" : nil
    }
    public var pulsesFilter: Bool { tourStop == .filters && !reduceMotion }
    public var canShowEntryNudge: Bool { tourStop == nil && panel == nil }

    public init(
        intoleranceAnswer: IntoleranceAnswer = .unanswered,
        householdSize: Int? = nil,
        hasShownFullTour: Bool = false
    ) {
        if let householdSize {
            precondition(householdSize > 0, "householdSize must be positive")
        }
        self.intoleranceAnswer = intoleranceAnswer
        self.householdSize = householdSize
        self.hasShownFullTour = hasShownFullTour
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

    /// The Baraja segura remains renderable before either answer exists.
    public func cardPresentation(for recipe: Recipe) -> RecipeCardPresentation? {
        let intolerances: Set<Allergen> = if case let .answered(value) = intoleranceAnswer {
            value
        } else { Set(Allergen.allCases) }
        guard FeedFilters(intolerances: intolerances).allows(recipe) else { return nil }
        return RecipeCardPresentation(
            recipe: recipe,
            householdSize: householdSize ?? recipe.servings,
            intolerances: intolerances
        )
    }

    public mutating func answerIntolerances(_ intolerances: Set<Allergen>) {
        intoleranceAnswer = .answered(intolerances)
    }

    public mutating func setHouseholdSize(_ householdSize: Int) {
        precondition(householdSize > 0, "householdSize must be positive")
        self.householdSize = householdSize
    }

    /// The shell sends coldLaunch once per process, and delayElapsed only
    /// after the current stop's delay. No clocks or animation live here.
    public mutating func reduce(_ action: OnboardingAction) {
        switch action {
        case let .coldLaunch(reduceMotion):
            self.reduceMotion = reduceMotion
            panel = nil
            guard intoleranceAnswer == .unanswered else { tourStop = nil; return }
            tourStop = hasShownFullTour || reduceMotion ? .filters : .cookbook
            // Persist on entry: a quit halfway must not replay the full tour.
            hasShownFullTour = true
        case .tourDelayElapsed:
            if tourStop == .cookbook { tourStop = .world }
            else if tourStop == .world { tourStop = .filters }
        case .tourTap:
            tourStop = tourStop == .cookbook || tourStop == .world ? .filters : nil
        case .filterButtonTapped:
            if tourStop == .cookbook || tourStop == .world {
                tourStop = .filters
            } else {
                tourStop = nil
                panel = panel == nil ? (intoleranceAnswer == .unanswered ? .firstRun : .full) : nil
            }
        case .setMine:
            tourStop = nil
            panel = intoleranceAnswer == .unanswered ? .firstRun : .full
        case .closePanel: panel = nil
        case let .toggleFirstRunAllergen(allergen):
            guard panel == .firstRun else { return }
            firstRunPanel.toggle(allergen)
        case let .chooseFirstRunHousehold(size):
            guard panel == .firstRun else { return }
            firstRunPanel.chooseHousehold(size)
        case .showMyCards:
            guard panel == .firstRun, let size = firstRunPanel.householdSize else { return }
            answerIntolerances(firstRunPanel.intolerances)
            setHouseholdSize(size)
            panel = nil
            tourStop = nil
        case let .answerIntolerances(value):
            answerIntolerances(value)
            tourStop = nil
        case let .setHouseholdSize(value): setHouseholdSize(value)
        }
    }
}

public struct SafeDeckBanner: Equatable, Sendable {
    public let line = "Free of all five allergens until you tell us yours."
    public let actionLabel = "Set mine"
    public var action: OnboardingAction { .setMine }
}
