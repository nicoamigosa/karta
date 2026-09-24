import Testing
import KartaCore
import KartaPresentation

@Suite("Recipe card presentation")
struct RecipeCardPresentationTests {

    @Test("Duration text pluralizes seconds and crosses the minute boundary")
    func durationTextCrossesMinuteBoundary() {
        #expect(DurationText.format(seconds: 0) == "0 seconds")
        #expect(DurationText.format(seconds: 59) == "59 seconds")
        #expect(DurationText.format(seconds: 60) == "1 minute")
        #expect(DurationText.format(seconds: 61) == "1 minute 1 second")
    }

    @Test("Duration text crosses the hour boundary and pluralizes each unit")
    func durationTextCrossesHourBoundary() {
        #expect(DurationText.format(seconds: 3_599) == "59 minutes 59 seconds")
        #expect(DurationText.format(seconds: 3_600) == "1 hour")
        #expect(DurationText.format(seconds: 3_661) == "1 hour 1 minute 1 second")
    }

    @Test("A card presents recipe metadata and keeps quantities literal")
    func cardPresentsRecipeText() {
        let recipe = Recipe(
            id: "pasta",
            name: "Pasta",
            heroPhoto: .local("pasta.jpg"),
            totalMinutes: 61,
            difficulty: .medium,
            servings: 1,
            tags: [],
            ingredients: [
                Ingredient(name: "flour", quantity: "1 1/2 cups"),
                Ingredient(name: "salt", quantity: "as needed"),
            ],
            steps: ["Mix"],
            allergenReview: .reviewed([])
        )

        let card = RecipeCardPresentation(recipe: recipe, householdSize: 2)

        #expect(card.recipeID == "pasta")
        #expect(card.name == "Pasta")
        #expect(card.durationLabel == "1 hour 1 minute")
        #expect(card.difficultyLabel == "intermediate")
        #expect(card.servingsLabel == "Serves 1")
        #expect(card.ingredientQuantities == ["1 1/2 cups", "as needed"])
    }

    @Test("Difficulty labels use the card vocabulary")
    func difficultyLabels() {
        #expect(card(for: .easy).difficultyLabel == "beginner")
        #expect(card(for: .medium).difficultyLabel == "intermediate")
        #expect(card(for: .hard).difficultyLabel == "advanced")
    }

    private func card(for difficulty: Difficulty) -> RecipeCardPresentation {
        RecipeCardPresentation(
            recipe: Recipe(
                id: difficulty.rawValue,
                name: "Recipe",
                heroPhoto: .local("recipe.jpg"),
                totalMinutes: 1,
                difficulty: difficulty,
                servings: 2,
                tags: [],
                ingredients: [Ingredient(name: "x", quantity: "1")],
                steps: ["Cook"],
                allergenReview: .reviewed([])
            ),
            householdSize: 1
        )
    }
}
