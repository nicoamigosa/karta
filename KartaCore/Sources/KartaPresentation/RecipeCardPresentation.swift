import KartaCore

/// Formats a non-negative duration without consulting locale or converting
/// units. The catalog's duration is already authored in the chosen unit.
public enum DurationText {

    public static func format(seconds: Int) -> String {
        precondition(seconds >= 0, "seconds must be non-negative")

        return format(
            hours: seconds / 3_600,
            minutes: (seconds % 3_600) / 60,
            seconds: seconds % 60
        )
    }

    public static func format(minutes: Int) -> String {
        precondition(minutes >= 0, "minutes must be non-negative")

        return format(
            hours: minutes / 60,
            minutes: minutes % 60,
            seconds: 0
        )
    }

    private static func format(hours: Int, minutes: Int, seconds: Int) -> String {

        if hours > 0 {
            return [unit(hours, singular: "hour"),
                    minutes > 0 ? unit(minutes, singular: "minute") : nil,
                    seconds > 0
                        ? unit(seconds, singular: "second")
                        : nil]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        if minutes > 0 {
            return [unit(minutes, singular: "minute"),
                    seconds > 0
                        ? unit(seconds, singular: "second")
                        : nil]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        return unit(seconds, singular: "second")
    }

    private static func unit(_ value: Int, singular: String) -> String {
        "\(value) \(singular)\(value == 1 ? "" : "s")"
    }
}

/// The non-UI values the shell needs to render a recipe card. Formatting lives
/// here so the SwiftUI shell does not recreate domain presentation rules.
public struct RecipeCardPresentation: Equatable, Sendable {
    public let recipeID: String
    public let name: String
    public let durationLabel: String
    public let rankValue: String
    public let rankUnit: String
    public let difficultyLabel: String
    public let servingsLabel: String
    public let primaryCourse: Course
    public let ingredientQuantities: [String]
    public let householdSize: Int

    public init(
        recipe: Recipe,
        householdSize: Int,
        intolerances: Set<Allergen>
    ) {
        precondition(householdSize > 0, "householdSize must be positive")
        self.recipeID = recipe.id
        self.name = recipe.name
        self.durationLabel = DurationText.format(minutes: recipe.totalMinutes)
        self.rankValue = recipe.totalMinutes > 60 ? "+60" : String(recipe.totalMinutes)
        self.rankUnit = "MIN"
        self.difficultyLabel = switch recipe.difficulty {
        case .easy: "beginner"
        case .medium: "intermediate"
        case .hard: "advanced"
        }
        self.servingsLabel = "Serves \(recipe.servings)"
        self.primaryCourse = recipe.primaryCourse
        self.ingredientQuantities = recipe.visibleIngredients(for: intolerances).map(\.quantity)
        self.householdSize = householdSize
    }
}
