import Testing
import Foundation
@testable import KartaCore

@Suite("Recipe decoding")
struct RecipeDecodingTests {

    @Test("An optional ingredient decodes its own reviewed allergens")
    func optionalIngredientDecodesAllergens() throws {
        let json = #"{"id":"cilantro","name":"Fresh cilantro","quantity":"1 tbsp","optional":true,"allergens":["dairy"]}"#

        let ingredient = try JSONDecoder().decode(Ingredient.self, from: Data(json.utf8))

        #expect(ingredient.isOptional)
        #expect(ingredient.allergens == [.dairy])
    }

    @Test("An optional ingredient requires a reviewed allergen set")
    func optionalIngredientRequiresAllergenSet() {
        let json = #"{"id":"butter","name":"Butter","quantity":"1 tbsp","optional":true}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Ingredient.self, from: Data(json.utf8))
        }
    }

    @Test("An optional ingredient rejects an unknown allergen term")
    func optionalIngredientRejectsUnknownAllergen() {
        let json = #"{"id":"butter","name":"Butter","quantity":"1 tbsp","optional":true,"allergens":["lactose"]}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Ingredient.self, from: Data(json.utf8))
        }
    }

    @Test("Required ingredient allergens belong in the recipe review")
    func requiredIngredientAllergensAreRejected() throws {
        let json = """
        {
            "id": "required-ingredient-allergens", "name": "Required ingredient allergens",
            "heroPhotoURL": "https://img.karta.app/required-ingredient-allergens.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [], "contains": [],
            "ingredients": [{
                "id": "milk", "name": "Milk", "quantity": "1 cup", "allergens": ["dairy"]
            }],
            "steps": [{ "text": "Cook with milk", "summary": "Cook with milk" }]
        }
        """

        #expect(decodingError(in: json) == .requiredIngredientHasAllergens(
            recipeID: "required-ingredient-allergens",
            recipeName: "Required ingredient allergens",
            ingredientID: "milk"
        ))
    }

    @Test("Recipe decoding rejects a missing allergen review state")
    func missingAllergenReviewFails() throws {
        let json = """
        {
            "id": "unlabelled-recipe",
            "name": "Unlabelled recipe",
            "heroPhotoURL": "https://img.karta.app/unlabelled-recipe.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 4,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"paso","summary":"paso"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected decoding to reject the missing allergen review state")
        } catch let error as RecipeDecodingError {
            #expect(error == .missingAllergenReview(
                recipeID: "unlabelled-recipe",
                recipeName: "Unlabelled recipe"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A catalog distinguishes reviewed-empty from unreviewed recipes")
    func catalogMixesReviewedAndUnreviewedRecipes() throws {
        let json = """
        [
            {
                "id": "reviewed-safe",
                "name": "Reviewed safe",
                "heroPhotoURL": "https://img.karta.app/reviewed-safe.jpg",
                "totalMinutes": 10,
                "difficulty": "easy",
                "servings": 4,
                "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
                "contains": [],
                "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
                "steps": [{"text":"s","summary":"s"}]
            },
            {
                "id": "still-draft",
                "name": "Still draft",
                "heroPhotoURL": "https://img.karta.app/still-draft.jpg",
                "totalMinutes": 10,
                "difficulty": "easy",
                "servings": 4,
                "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
                "contains": null,
                "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
                "steps": [{"text":"s","summary":"s"}]
            }
        ]
        """

        let catalog = try RecipeCatalog.decode(from: Data(json.utf8))

        #expect(catalog.map(\.id) == ["reviewed-safe", "still-draft"])
        #expect(catalog[0].allergenReview == .reviewed([]))
        #expect(catalog[1].allergenReview == .unreviewed)

        let feed = FeedQuery.feed(
            recipes: catalog,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )
        #expect(feed.newRecipes.map(\.id) == ["reviewed-safe"])
    }

    @Test("Allergen decoding is closed and normalizes input")
    func allergenVocabularyNormalizesInput() throws {
        #expect(Allergen(rawValue: " dairy ") == .dairy)
        #expect(Allergen(rawValue: "DAIRY") == .dairy)
        #expect(Allergen(rawValue: "lactose") == nil)

        let json = """
        {
            "id": "normalized-allergens",
            "name": "Normalized allergens",
            "heroPhotoURL": "https://img.karta.app/normalized-allergens.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 4,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [" DaIrY "],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"paso","summary":"paso"}]
        }
        """

        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(recipe.allergenReview == .reviewed([.dairy]))
    }

    @Test("Recipe decoding names an unknown allergen and its recipe")
    func unknownAllergenFailsWithContext() throws {
        let json = """
        {
            "id": "stale-pesto",
            "name": "Stale pesto",
            "heroPhotoURL": "https://img.karta.app/stale-pesto.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 4,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": ["lactose"],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"paso","summary":"paso"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected decoding to reject the unknown allergen")
        } catch let error as RecipeDecodingError {
            #expect(error == .unknownAllergen(
                recipeID: "stale-pesto",
                recipeName: "Stale pesto",
                value: "lactose"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe catalog rejects duplicate recipe ids")
    func duplicateRecipeIDsFailWithContext() throws {
        let json = """
        [
            {
                "id": "repeat",
                "name": "First repeat",
                "heroPhotoURL": "https://img.karta.app/repeat-1.jpg",
                "totalMinutes": 10,
                "difficulty": "easy",
                "servings": 4,
                "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
                "contains": [],
                "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
                "steps": [{"text":"Cook","summary":"Cook"}]
            },
            {
                "id": "repeat",
                "name": "Second repeat",
                "heroPhotoURL": "https://img.karta.app/repeat-2.jpg",
                "totalMinutes": 10,
                "difficulty": "easy",
                "servings": 4,
                "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
                "contains": [],
                "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
                "steps": [{"text":"Cook","summary":"Cook"}]
            }
        ]
        """

        do {
            _ = try RecipeCatalog.decode(from: Data(json.utf8))
            Issue.record("Expected duplicate recipe ids to be rejected")
        } catch let error as RecipeCatalogDecodingError {
            #expect(error == .duplicateRecipeID("repeat"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects empty ingredients with recipe context")
    func emptyIngredientsFailWithContext() throws {
        let json = """
        {
            "id": "empty-ingredients",
            "name": "Empty ingredients",
            "heroPhotoURL": "https://img.karta.app/empty-ingredients.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected empty ingredients to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyIngredients(
                recipeID: "empty-ingredients",
                recipeName: "Empty ingredients"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects empty ingredient names with recipe context")
    func emptyIngredientNameFailsWithContext() throws {
        let json = """
        {
            "id": "empty-ingredient-name",
            "name": "Empty ingredient name",
            "heroPhotoURL": "https://img.karta.app/empty-ingredient-name.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "blank-name", "name": "  ", "quantity": "1 cup" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty ingredient name to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyIngredientName(
                recipeID: "empty-ingredient-name",
                recipeName: "Empty ingredient name",
                ingredientIndex: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects empty steps with recipe context")
    func emptyStepsFailWithContext() throws {
        let json = """
        {
            "id": "empty-steps",
            "name": "Empty steps",
            "heroPhotoURL": "https://img.karta.app/empty-steps.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "flour", "name": "Flour", "quantity": "1 cup" }],
            "steps": []
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected empty steps to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptySteps(
                recipeID: "empty-steps",
                recipeName: "Empty steps"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects an empty recipe id")
    func emptyRecipeIDFailsWithContext() throws {
        let json = """
        {
            "id": "   ",
            "name": "Missing identity",
            "heroPhotoURL": "https://img.karta.app/missing-identity.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 4,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty recipe id to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyRecipeID(recipeName: "Missing identity"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding preserves the declared servings")
    func decodesServings() throws {
        let json = """
        {
            "id": "servings",
            "name": "Servings",
            "heroPhotoURL": "https://img.karta.app/servings.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 4,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))

        #expect(recipe.servings == 4)
    }

    @Test("Recipe decoding rejects non-positive servings with recipe context")
    func nonPositiveServingsFailWithContext() throws {
        let json = """
        {
            "id": "zero-servings",
            "name": "Zero servings",
            "heroPhotoURL": "https://img.karta.app/zero-servings.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 0,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected non-positive servings to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .nonPositiveServings(
                recipeID: "zero-servings",
                recipeName: "Zero servings",
                value: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects non-positive total duration with recipe context")
    func nonPositiveTotalDurationFailsWithContext() throws {
        let json = """
        {
            "id": "zero-duration",
            "name": "Zero duration",
            "heroPhotoURL": "https://img.karta.app/zero-duration.jpg",
            "totalMinutes": -1,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected non-positive total duration to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .nonPositiveTotalMinutes(
                recipeID: "zero-duration",
                recipeName: "Zero duration",
                value: -1
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects empty required recipe content")
    func emptyRecipeNameFailsWithContext() throws {
        let json = """
        {
            "id": "missing-name",
            "name": "  ",
            "heroPhotoURL": "https://img.karta.app/missing-name.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected empty recipe content to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyRecipeName(recipeID: "missing-name"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects an empty hero photo URL")
    func emptyHeroPhotoURLFailsWithContext() throws {
        let json = """
        {
            "id": "missing-photo",
            "name": "Missing photo",
            "heroPhotoURL": "  ",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty hero photo URL to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyHeroPhotoURL(
                recipeID: "missing-photo",
                recipeName: "Missing photo"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects an empty ingredient quantity")
    func emptyIngredientQuantityFailsWithContext() throws {
        let json = """
        {
            "id": "missing-quantity",
            "name": "Missing quantity",
            "heroPhotoURL": "https://img.karta.app/missing-quantity.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "flour", "name": "Flour", "quantity": "  " }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty ingredient quantity to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyIngredientQuantity(
                recipeID: "missing-quantity",
                recipeName: "Missing quantity",
                ingredientIndex: 0,
                ingredientName: "Flour"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects a non-positive ingredient quantity")
    func nonPositiveIngredientQuantityFailsWithContext() throws {
        let json = """
        {
            "id": "zero-quantity",
            "name": "Zero quantity",
            "heroPhotoURL": "https://img.karta.app/zero-quantity.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [],
            "ingredients": [{ "id": "flour", "name": "Flour", "quantity": "0 cups" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected a non-positive ingredient quantity to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .nonPositiveIngredientQuantity(
                recipeID: "zero-quantity",
                recipeName: "Zero quantity",
                ingredientIndex: 0,
                ingredientName: "Flour",
                value: "0 cups"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    /// Tracer bullet: proves the data-model → JSON decode path end to end.
    /// A single recipe must decode with the fields a feed card and the
    /// detail screen depend on, including ingredient quantities and ordered steps.
    @Test("A recipe decodes from JSON with its core fields")
    func decodesSingleRecipe() throws {
        let json = """
        {
            "id": "tortilla-de-papa",
            "name": "Tortilla de papa",
            "heroPhotoURL": "https://img.karta.app/tortilla.jpg",
            "totalMinutes": 35,
            "difficulty": "easy",
            "servings": 4,
            "primaryCourse": "dinner",
            "additionalCourses": ["lunch"],
            "diets": ["vegetarian"],
            "practicalTags": ["one-pan"],
            "contains": [],
            "ingredients": [
                { "id": "papa", "name": "Papa", "quantity": "4 unidades" },
                { "id": "huevo", "name": "Huevo", "quantity": "5 unidades" }
            ],
            "steps": [{"text":"Pelar y cortar las papas en rodajas finas.","summary":"Pelar y cortar las papas en rodajas finas."},{"text":"Freír a fuego medio hasta que estén tiernas.","summary":"Freír a fuego medio hasta que estén tiernas."}]
        }
        """

        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))

        #expect(recipe.id == "tortilla-de-papa")
        #expect(recipe.name == "Tortilla de papa")
        #expect(recipe.totalMinutes == 35)
        #expect(recipe.difficulty == .easy)
        #expect(recipe.primaryCourse == .dinner)
        #expect(recipe.additionalCourses == [.lunch])
        #expect(recipe.diets == [.vegetarian])
        #expect(recipe.practicalTags == [.onePan])
        #expect(recipe.ingredients.count == 2)
        let firstIngredient = try #require(recipe.ingredients.first)
        #expect(firstIngredient.name == "Papa")
        #expect(firstIngredient.quantity == "4 unidades")
        #expect(recipe.steps.count == 2)
    }

    @Test("A recipe preserves its editorial date through Codable")
    func editorialDateRoundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let recipe = Recipe(
            id: "dated-recipe",
            name: "Dated recipe",
            heroPhoto: .local("dated-recipe"),
            totalMinutes: 10,
            difficulty: .easy,
            servings: 2,
            primaryCourse: .dinner,
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["Cook"],
            allergenReview: .reviewed([]),
            editorialDate: date
        )

        let data = try JSONEncoder().encode(recipe)
        let decoded = try JSONDecoder().decode(Recipe.self, from: data)

        #expect(decoded.editorialDate == date)
    }

    @Test("Recipe decoding names an unknown practical tag and its recipe")
    func unknownPracticalTagFailsWithContext() {
        let json = """
        {
            "id": "legacy-tags",
            "name": "Legacy tags",
            "heroPhotoURL": "https://img.karta.app/legacy-tags.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "primaryCourse": "dinner",
            "additionalCourses": [],
            "diets": [],
            "practicalTags": ["one-pan", "quick"],
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"s","summary":"s"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected decoding to reject the unknown practical tag")
        } catch let error as RecipeDecodingError {
            #expect(error == .unknownPracticalTag(
                recipeID: "legacy-tags",
                recipeName: "Legacy tags",
                value: "quick"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Unknown Course and Diet values fail with recipe context")
    func unknownCourseAndDietFailWithContext() {
        let unknownCourse = """
        {
            "id": "unknown-course", "name": "Unknown Course",
            "heroPhotoURL": "https://img.karta.app/unknown-course.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "brunch", "additionalCourses": [], "diets": [], "practicalTags": [],
            "contains": [], "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }], "steps": [{"text":"s","summary":"s"}]
        }
        """
        let unknownDiet = """
        {
            "id": "unknown-diet", "name": "Unknown Diet",
            "heroPhotoURL": "https://img.karta.app/unknown-diet.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": ["pescatarian"], "practicalTags": [],
            "contains": [], "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }], "steps": [{"text":"s","summary":"s"}]
        }
        """

        #expect(decodingError(in: unknownCourse) == .unknownCourse(
            recipeID: "unknown-course",
            recipeName: "Unknown Course",
            value: "brunch"
        ))
        #expect(decodingError(in: unknownDiet) == .unknownDiet(
            recipeID: "unknown-diet",
            recipeName: "Unknown Diet",
            value: "pescatarian"
        ))
    }

    @Test("Additional Courses cannot repeat the primary Course")
    func additionalCoursesCannotRepeatPrimary() {
        let json = """
        {
            "id": "repeated-course", "name": "Repeated Course",
            "heroPhotoURL": "https://img.karta.app/repeated-course.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": ["dinner"], "diets": [], "practicalTags": [],
            "contains": [], "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }], "steps": [{"text":"s","summary":"s"}]
        }
        """

        #expect(decodingError(in: json) == .repeatedPrimaryCourse(
            recipeID: "repeated-course",
            recipeName: "Repeated Course",
            value: "dinner"
        ))
    }

    @Test("The flat legacy tags field is rejected after taxonomy migration")
    func legacyTagFieldIsRejected() {
        let json = """
        {
            "id": "legacy-tags", "name": "Legacy Tags",
            "heroPhotoURL": "https://img.karta.app/legacy-tags.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "dinner", "additionalCourses": [], "diets": [], "practicalTags": [],
            "tags": ["quick"], "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }], "steps": [{"text":"s","summary":"s"}]
        }
        """

        #expect(decodingError(in: json) == .legacyTagsField(
            recipeID: "legacy-tags",
            recipeName: "Legacy Tags"
        ))
    }

    @Test("Course, Diet and practical-tag vocabularies are closed and normalize input")
    func recipeVocabulariesNormalizeInput() {
        #expect(Course(rawValue: " LUNCH ") == .lunch)
        #expect(Diet(rawValue: " VEGAN ") == .vegan)
        #expect(PracticalTag(rawValue: " One-Pan ") == .onePan)
        #expect(Course(rawValue: "brunch") == nil)
        #expect(Diet(rawValue: "vegetariano") == nil)
        #expect(PracticalTag(rawValue: "quick") == nil)
    }

    @Test("A recipe without its primary Course fails to decode")
    func missingPrimaryCourseFailsWithContext() {
        let json = """
        {
            "id": "course-less",
            "name": "Course-less",
            "heroPhotoURL": "https://img.karta.app/course-less.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "contains": [],
            "ingredients": [{ "id": "x", "name": "x", "quantity": "1" }],
            "steps": [{"text":"Cook","summary":"Cook"}]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected decoding to reject the missing primary Course")
        } catch let error as RecipeDecodingError {
            #expect(error == .missingPrimaryCourse(
                recipeID: "course-less",
                recipeName: "Course-less"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func decodingError(in json: String) -> RecipeDecodingError? {
        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            return nil
        } catch let error as RecipeDecodingError {
            return error
        } catch {
            return nil
        }
    }
}
