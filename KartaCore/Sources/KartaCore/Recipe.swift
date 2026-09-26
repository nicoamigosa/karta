import Foundation

public enum RecipeDecodingError: Error, Equatable, LocalizedError, Sendable {
    case missingAllergenReview(recipeID: String, recipeName: String)
    case unknownAllergen(recipeID: String, recipeName: String, value: String)
    case missingPrimaryCourse(recipeID: String, recipeName: String)
    case unknownCourse(recipeID: String, recipeName: String, value: String)
    case repeatedPrimaryCourse(recipeID: String, recipeName: String, value: String)
    case unknownDiet(recipeID: String, recipeName: String, value: String)
    case unknownPracticalTag(recipeID: String, recipeName: String, value: String)
    case legacyTagsField(recipeID: String, recipeName: String)
    case emptyRecipeID(recipeName: String)
    case nonPositiveServings(recipeID: String, recipeName: String, value: Int)
    case nonPositiveTotalMinutes(recipeID: String, recipeName: String, value: Int)
    case nonPositiveTimerSeconds(recipeID: String, recipeName: String, stepIndex: Int, value: Int)
    case emptyRecipeName(recipeID: String)
    case emptyHeroPhotoURL(recipeID: String, recipeName: String)
    case invalidHeroPhotoReference(recipeID: String, recipeName: String, value: String)
    case emptyIngredients(recipeID: String, recipeName: String)
    case emptySteps(recipeID: String, recipeName: String)
    case emptyIngredientName(recipeID: String, recipeName: String, ingredientIndex: Int)
    case emptyIngredientID(recipeID: String, recipeName: String, ingredientIndex: Int)
    case duplicateIngredientID(recipeID: String, recipeName: String, ingredientID: String)
    case requiredIngredientHasAllergens(
        recipeID: String,
        recipeName: String,
        ingredientID: String
    )
    case emptyIngredientQuantity(
        recipeID: String,
        recipeName: String,
        ingredientIndex: Int,
        ingredientName: String
    )
    case nonPositiveIngredientQuantity(
        recipeID: String,
        recipeName: String,
        ingredientIndex: Int,
        ingredientName: String,
        value: String
    )
    case emptyStepIngredientID(recipeID: String, recipeName: String, stepIndex: Int)
    case unknownStepIngredientID(
        recipeID: String,
        recipeName: String,
        stepIndex: Int,
        ingredientID: String
    )
    case optionalIngredientInRequiredStep(
        recipeID: String,
        recipeName: String,
        stepIndex: Int,
        ingredientID: String
    )
    case emptyStepIngredientQuantity(
        recipeID: String,
        recipeName: String,
        stepIndex: Int,
        ingredientID: String
    )
    case nonPositiveStepIngredientQuantity(
        recipeID: String,
        recipeName: String,
        stepIndex: Int,
        ingredientID: String,
        value: String
    )
    case emptyStepText(recipeID: String, recipeName: String, stepIndex: Int)
    case emptyStepSummary(recipeID: String, recipeName: String, stepIndex: Int)
    case multilineStepSummary(recipeID: String, recipeName: String, stepIndex: Int)
    case emptyStepClipID(recipeID: String, recipeName: String, stepIndex: Int)

    public var errorDescription: String? {
        switch self {
        case let .missingAllergenReview(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') is missing its allergen review state"
        case let .unknownAllergen(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown allergen '\(value)'"
        case let .missingPrimaryCourse(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') is missing its primary Course"
        case let .unknownCourse(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown Course '\(value)'"
        case let .repeatedPrimaryCourse(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') repeats primary Course '\(value)' among additional Courses"
        case let .unknownDiet(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown Diet '\(value)'"
        case let .unknownPracticalTag(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown practical tag '\(value)'"
        case let .legacyTagsField(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') uses the retired flat tags field"
        case let .emptyRecipeID(recipeName):
            return "Recipe ('\(recipeName)') has an empty recipe id"
        case let .nonPositiveServings(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has non-positive servings '\(value)'"
        case let .nonPositiveTotalMinutes(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has non-positive total minutes '\(value)'"
        case let .nonPositiveTimerSeconds(recipeID, recipeName, stepIndex, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has non-positive timer seconds '\(value)'"
        case let .emptyRecipeName(recipeID):
            return "Recipe '\(recipeID)' has an empty recipe name"
        case let .emptyHeroPhotoURL(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') has an empty hero photo URL"
        case let .invalidHeroPhotoReference(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has invalid hero photo reference '\(value)'"
        case let .emptyIngredients(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') has no ingredients"
        case let .emptySteps(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') has no steps"
        case let .emptyIngredientName(recipeID, recipeName, ingredientIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) has an empty name"
        case let .emptyIngredientID(recipeID, recipeName, ingredientIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) has an empty id"
        case let .duplicateIngredientID(recipeID, recipeName, ingredientID):
            return "Recipe '\(recipeID)' ('\(recipeName)') has duplicate ingredient id '\(ingredientID)'"
        case let .requiredIngredientHasAllergens(recipeID, recipeName, ingredientID):
            return "Recipe '\(recipeID)' ('\(recipeName)') required ingredient '\(ingredientID)' has an ingredient-level allergen set"
        case let .emptyIngredientQuantity(recipeID, recipeName, ingredientIndex, ingredientName):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) '\(ingredientName)' has an empty quantity"
        case let .nonPositiveIngredientQuantity(recipeID, recipeName, ingredientIndex, ingredientName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) '\(ingredientName)' has non-positive quantity '\(value)'"
        case let .emptyStepIngredientID(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has an ingredient with an empty id"
        case let .unknownStepIngredientID(recipeID, recipeName, stepIndex, ingredientID):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) references unknown ingredient id '\(ingredientID)'"
        case let .optionalIngredientInRequiredStep(recipeID, recipeName, stepIndex, ingredientID):
            return "Recipe '\(recipeID)' ('\(recipeName)') required step \(stepIndex) references optional ingredient id '\(ingredientID)'"
        case let .emptyStepIngredientQuantity(recipeID, recipeName, stepIndex, ingredientID):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) ingredient '\(ingredientID)' has an empty quantity"
        case let .nonPositiveStepIngredientQuantity(recipeID, recipeName, stepIndex, ingredientID, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) ingredient '\(ingredientID)' has non-positive quantity '\(value)'"
        case let .emptyStepText(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has empty text"
        case let .emptyStepSummary(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has an empty summary"
        case let .multilineStepSummary(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has a summary that spans multiple lines"
        case let .emptyStepClipID(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has an empty technique clip id"
        }
    }
}

/// The editor's allergen decision for a recipe.
///
/// An unreviewed recipe has no allergen set. Keeping that state as a separate
/// case prevents it from being treated as a reviewed recipe with no allergens.
public enum AllergenReview: Equatable, Sendable {
    case reviewed(Set<Allergen>)
    case unreviewed
}

/// A cookable recipe: the foundation domain model every feature builds on.
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let heroPhoto: MediaReference
    public let totalMinutes: Int
    public let difficulty: Difficulty
    public let servings: Int
    /// The editor's single primary Course, shown on the Card.
    public let primaryCourse: Course
    /// Additional Courses are used only by filters; the primary Course is not repeated.
    public let additionalCourses: Set<Course>
    public let diets: Set<Diet>
    public let practicalTags: Set<PracticalTag>
    public let ingredients: [Ingredient]
    /// Ordered, structured steps. Each step is self-contained and may carry the
    /// exact ingredients it needs, a timer, and a reusable technique clip. Decodes
    /// backward-compatibly from a bare string (text-only step).
    public let steps: [CookingStep]
    /// The editor's explicit allergen review decision.
    public let allergenReview: AllergenReview
    /// The date the editor published this recipe for feed freshness ranking.
    public let editorialDate: Date
    /// Precalculated popularity score; the feed uses this after freshness and fit.
    public let popularity: Int

    public init(
        id: String,
        name: String,
        heroPhoto: MediaReference,
        totalMinutes: Int,
        difficulty: Difficulty,
        servings: Int,
        primaryCourse: Course,
        additionalCourses: Set<Course> = [],
        diets: Set<Diet> = [],
        practicalTags: Set<PracticalTag> = [],
        ingredients: [Ingredient],
        steps: [CookingStep],
        allergenReview: AllergenReview,
        editorialDate: Date = .distantPast,
        popularity: Int = 0
    ) {
        self.id = id
        self.name = name
        self.heroPhoto = heroPhoto
        self.totalMinutes = totalMinutes
        self.difficulty = difficulty
        self.servings = servings
        self.primaryCourse = primaryCourse
        self.additionalCourses = additionalCourses.subtracting([primaryCourse])
        self.diets = diets
        self.practicalTags = practicalTags
        self.ingredients = ingredients
        self.steps = steps
        self.allergenReview = allergenReview
        self.editorialDate = editorialDate
        self.popularity = popularity
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeDecodingError.emptyRecipeID(recipeName: name)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeDecodingError.emptyRecipeName(recipeID: id)
        }
        let rawHeroPhoto = try c.decode(String.self, forKey: .heroPhotoURL)
        guard !rawHeroPhoto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeDecodingError.emptyHeroPhotoURL(
                recipeID: id,
                recipeName: name
            )
        }
        do {
            heroPhoto = try MediaReference(validating: rawHeroPhoto)
        } catch {
            throw RecipeDecodingError.invalidHeroPhotoReference(
                recipeID: id,
                recipeName: name,
                value: rawHeroPhoto
            )
        }
        totalMinutes = try c.decode(Int.self, forKey: .totalMinutes)
        guard totalMinutes > 0 else {
            throw RecipeDecodingError.nonPositiveTotalMinutes(
                recipeID: id,
                recipeName: name,
                value: totalMinutes
            )
        }
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        servings = try c.decode(Int.self, forKey: .servings)
        guard servings > 0 else {
            throw RecipeDecodingError.nonPositiveServings(
                recipeID: id,
                recipeName: name,
                value: servings
            )
        }
        guard let rawPrimaryCourse = try c.decodeIfPresent(String.self, forKey: .primaryCourse) else {
            throw RecipeDecodingError.missingPrimaryCourse(recipeID: id, recipeName: name)
        }
        guard let decodedPrimaryCourse = Course(rawValue: rawPrimaryCourse) else {
            throw RecipeDecodingError.unknownCourse(
                recipeID: id,
                recipeName: name,
                value: rawPrimaryCourse
            )
        }
        primaryCourse = decodedPrimaryCourse
        guard !c.contains(.legacyTags) else {
            throw RecipeDecodingError.legacyTagsField(recipeID: id, recipeName: name)
        }
        let recipeID = id
        let recipeName = name
        let rawAdditionalCourses = try c.decodeIfPresent(
            [String].self,
            forKey: .additionalCourses
        ) ?? []
        let decodedAdditionalCourses = try rawAdditionalCourses.map { rawValue in
            guard let course = Course(rawValue: rawValue) else {
                throw RecipeDecodingError.unknownCourse(
                    recipeID: recipeID,
                    recipeName: recipeName,
                    value: rawValue
                )
            }
            return course
        }
        guard !decodedAdditionalCourses.contains(decodedPrimaryCourse) else {
            throw RecipeDecodingError.repeatedPrimaryCourse(
                recipeID: recipeID,
                recipeName: recipeName,
                value: decodedPrimaryCourse.rawValue
            )
        }
        additionalCourses = Set(decodedAdditionalCourses)
        diets = try (c.decodeIfPresent([String].self, forKey: .diets) ?? [])
            .reduce(into: Set<Diet>()) { result, rawValue in
                guard let diet = Diet(rawValue: rawValue) else {
                    throw RecipeDecodingError.unknownDiet(
                        recipeID: recipeID,
                        recipeName: recipeName,
                        value: rawValue
                    )
                }
                result.insert(diet)
            }
        practicalTags = try (c.decodeIfPresent([String].self, forKey: .practicalTags) ?? [])
            .reduce(into: Set<PracticalTag>()) { result, rawValue in
                guard let tag = PracticalTag(rawValue: rawValue) else {
                    throw RecipeDecodingError.unknownPracticalTag(
                        recipeID: recipeID,
                        recipeName: recipeName,
                        value: rawValue
                    )
                }
                result.insert(tag)
            }
        ingredients = try c.decode([Ingredient].self, forKey: .ingredients)
        guard !ingredients.isEmpty else {
            throw RecipeDecodingError.emptyIngredients(recipeID: id, recipeName: name)
        }
        var ingredientIDs = Set<String>()
        var optionalIngredientIDs = Set<String>()
        for (index, ingredient) in ingredients.enumerated() {
            guard !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeDecodingError.emptyIngredientName(
                    recipeID: id,
                    recipeName: name,
                    ingredientIndex: index
                )
            }
            guard !ingredient.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeDecodingError.emptyIngredientID(
                    recipeID: id,
                    recipeName: name,
                    ingredientIndex: index
                )
            }
            guard ingredientIDs.insert(ingredient.id).inserted else {
                throw RecipeDecodingError.duplicateIngredientID(
                    recipeID: id,
                    recipeName: name,
                    ingredientID: ingredient.id
                )
            }
            guard ingredient.isOptional || ingredient.allergens.isEmpty else {
                throw RecipeDecodingError.requiredIngredientHasAllergens(
                    recipeID: id,
                    recipeName: name,
                    ingredientID: ingredient.id
                )
            }
            if ingredient.isOptional {
                optionalIngredientIDs.insert(ingredient.id)
            }
            try validateRecipeIngredientQuantity(
                ingredient,
                recipeID: id,
                recipeName: name,
                ingredientIndex: index
            )
        }
        steps = try c.decode([CookingStep].self, forKey: .steps)
        guard !steps.isEmpty else {
            throw RecipeDecodingError.emptySteps(recipeID: id, recipeName: name)
        }
        for (index, step) in steps.enumerated() {
            guard !step.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeDecodingError.emptyStepText(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
            }
            guard !step.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeDecodingError.emptyStepSummary(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
            }
            guard !step.summary.contains(where: { $0.isNewline }) else {
                throw RecipeDecodingError.multilineStepSummary(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
            }
            if step.clipID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                throw RecipeDecodingError.emptyStepClipID(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
            }
            if let timerSeconds = step.timerSeconds, timerSeconds <= 0 {
                throw RecipeDecodingError.nonPositiveTimerSeconds(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index,
                    value: timerSeconds
                )
            }
            for ingredient in step.ingredients {
                let ingredientID = ingredient.ingredientID.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !ingredientID.isEmpty else {
                    throw RecipeDecodingError.emptyStepIngredientID(
                        recipeID: id,
                        recipeName: name,
                        stepIndex: index
                    )
                }
                try validateStepIngredientQuantity(
                    ingredient,
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
                guard ingredientIDs.contains(ingredient.ingredientID) else {
                    throw RecipeDecodingError.unknownStepIngredientID(
                        recipeID: id,
                        recipeName: name,
                        stepIndex: index,
                        ingredientID: ingredient.ingredientID
                    )
                }
                if optionalIngredientIDs.contains(ingredient.ingredientID), !step.isOptional {
                    throw RecipeDecodingError.optionalIngredientInRequiredStep(
                        recipeID: id,
                        recipeName: name,
                        stepIndex: index,
                        ingredientID: ingredient.ingredientID
                    )
                }
            }
        }
        guard c.contains(.allergenReview) else {
            throw RecipeDecodingError.missingAllergenReview(
                recipeID: recipeID,
                recipeName: recipeName
            )
        }
        if try c.decodeNil(forKey: .allergenReview) {
            allergenReview = .unreviewed
        } else {
            let rawContains = try c.decode([String].self, forKey: .allergenReview)
            allergenReview = .reviewed(try Set(rawContains.map { rawValue in
                guard let allergen = Allergen(rawValue: rawValue) else {
                    throw RecipeDecodingError.unknownAllergen(
                        recipeID: recipeID,
                        recipeName: recipeName,
                        value: rawValue
                    )
                }
                return allergen
            }))
        }
        // Recipes constructed before editorial dates existed remain valid and
        // intentionally rank as the oldest content until the catalog supplies one.
        editorialDate = try c.decodeIfPresent(Date.self, forKey: .editorialDate) ?? .distantPast
        popularity = try c.decodeIfPresent(Int.self, forKey: .popularity) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(heroPhoto.rawValue, forKey: .heroPhotoURL)
        try c.encode(totalMinutes, forKey: .totalMinutes)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(servings, forKey: .servings)
        try c.encode(primaryCourse, forKey: .primaryCourse)
        try c.encode(additionalCourses.map(\.rawValue).sorted(), forKey: .additionalCourses)
        try c.encode(diets.map(\.rawValue).sorted(), forKey: .diets)
        try c.encode(practicalTags.map(\.rawValue).sorted(), forKey: .practicalTags)
        try c.encode(ingredients, forKey: .ingredients)
        try c.encode(steps, forKey: .steps)
        switch allergenReview {
        case let .reviewed(allergens):
            try c.encode(allergens.map(\.rawValue).sorted(), forKey: .allergenReview)
        case .unreviewed:
            try c.encodeNil(forKey: .allergenReview)
        }
        try c.encode(editorialDate, forKey: .editorialDate)
        try c.encode(popularity, forKey: .popularity)
    }

    /// The required ingredients and optional ingredients safe for this
    /// intolerance profile.
    public func visibleIngredients(for intolerances: Set<Allergen>) -> [Ingredient] {
        ingredients.filter { ingredient in
            !ingredient.isOptional || ingredient.allergens.isDisjoint(with: intolerances)
        }
    }

    /// Required steps plus optional steps that do not use a hidden optional
    /// ingredient. Filtering by ingredient references also protects callers
    /// from malformed programmatically-created recipes.
    public func visibleSteps(for intolerances: Set<Allergen>) -> [CookingStep] {
        let hiddenOptionalIngredientIDs = Set(
            ingredients
                .filter { $0.isOptional && !$0.allergens.isDisjoint(with: intolerances) }
                .map(\.id)
        )
        return steps.filter { step in
            !step.ingredients.contains { hiddenOptionalIngredientIDs.contains($0.ingredientID) }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case heroPhotoURL
        case totalMinutes
        case difficulty
        case servings
        case primaryCourse
        case additionalCourses
        case diets
        case practicalTags
        case legacyTags = "tags"
        case ingredients
        case steps
        case allergenReview = "contains"
        case editorialDate
        case popularity
    }
}

/// An ingredient line shown in a recipe's ingredient list. Cooking steps refer
/// back to these lines by `id` and carry their own per-step quantity.
public struct Ingredient: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quantity: String
    public let isOptional: Bool
    /// Allergen review for an optional ingredient. Recipe-level `contains`
    /// remains the review of required ingredients only.
    public let allergens: Set<Allergen>

    public init(
        id: String,
        name: String,
        quantity: String,
        isOptional: Bool = false,
        allergens: Set<Allergen> = []
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isOptional = isOptional
        self.allergens = allergens
    }

    /// Compatibility for programmatic recipes created before ingredient ids
    /// were part of the catalog contract. Catalog data must declare `id`
    /// explicitly.
    public init(
        name: String,
        quantity: String,
        isOptional: Bool = false,
        allergens: Set<Allergen> = []
    ) {
        self.init(
            id: Self.derivedID(from: name),
            name: name,
            quantity: quantity,
            isOptional: isOptional,
            allergens: allergens
        )
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false
        let allergens: Set<Allergen>
        if container.contains(.allergens) {
            let rawAllergens = try container.decode([String].self, forKey: .allergens)
            allergens = try Set(rawAllergens.map { rawValue in
                guard let allergen = Allergen(rawValue: rawValue) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .allergens,
                        in: container,
                        debugDescription: "Unknown optional ingredient allergen '\(rawValue)'"
                    )
                }
                return allergen
            })
        } else {
            guard !isOptional else {
                throw DecodingError.keyNotFound(
                    CodingKeys.allergens,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "An optional ingredient requires an allergen review set"
                    )
                )
            }
            allergens = []
        }
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: name,
            quantity: try container.decode(String.self, forKey: .quantity),
            isOptional: isOptional,
            allergens: allergens
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isOptional, forKey: .isOptional)
        try container.encode(allergens.map(\.rawValue).sorted(), forKey: .allergens)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, quantity
        case isOptional = "optional"
        case allergens
    }

    private static func derivedID(from name: String) -> String {
        name
            .split { !$0.isLetter && !$0.isNumber }
            .map { $0.lowercased() }
            .joined(separator: "-")
    }
}

private func validateRecipeIngredientQuantity(
    _ ingredient: Ingredient,
    recipeID: String,
    recipeName: String,
    ingredientIndex: Int
) throws {
    let quantity = ingredient.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !quantity.isEmpty else {
        throw RecipeDecodingError.emptyIngredientQuantity(
            recipeID: recipeID,
            recipeName: recipeName,
            ingredientIndex: ingredientIndex,
            ingredientName: ingredient.name
        )
    }

    let numericPrefix = String(quantity.prefix { character in
        character == "." || character == "-" || character == "+"
            || character.isNumber
    })
    if let numericValue = Double(numericPrefix), numericValue <= 0 {
        throw RecipeDecodingError.nonPositiveIngredientQuantity(
            recipeID: recipeID,
            recipeName: recipeName,
            ingredientIndex: ingredientIndex,
            ingredientName: ingredient.name,
            value: ingredient.quantity
        )
    }
}

private func validateStepIngredientQuantity(
    _ ingredient: StepIngredient,
    recipeID: String,
    recipeName: String,
    stepIndex: Int
) throws {
    let quantity = ingredient.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !quantity.isEmpty else {
        throw RecipeDecodingError.emptyStepIngredientQuantity(
            recipeID: recipeID,
            recipeName: recipeName,
            stepIndex: stepIndex,
            ingredientID: ingredient.ingredientID
        )
    }

    let numericPrefix = String(quantity.prefix { character in
        character == "." || character == "-" || character == "+"
            || character.isNumber
    })
    if let numericValue = Double(numericPrefix), numericValue <= 0 {
        throw RecipeDecodingError.nonPositiveStepIngredientQuantity(
            recipeID: recipeID,
            recipeName: recipeName,
            stepIndex: stepIndex,
            ingredientID: ingredient.ingredientID,
            value: ingredient.quantity
        )
    }
}

public enum Difficulty: String, Codable, Equatable, Sendable, Comparable, CaseIterable {
    case easy
    case medium
    case hard

    private var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rank < rhs.rank
    }
}
