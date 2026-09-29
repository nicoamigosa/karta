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

    @Test("Short duration text abbreviates minutes")
    func shortDurationTextAbbreviatesMinutes() {
        #expect(DurationText.shortFormat(seconds: 720) == "12 min")
        #expect(DurationText.shortFormat(seconds: 600) == "10 min")
        #expect(DurationText.shortFormat(seconds: 60) == "1 min")
    }

    @Test("Short duration text includes nonzero hour components")
    func shortDurationTextIncludesHours() {
        #expect(DurationText.shortFormat(seconds: 3_600) == "1 h")
        #expect(DurationText.shortFormat(seconds: 5_400) == "1 h 30 min")
        #expect(DurationText.shortFormat(seconds: 3_661) == "1 h 1 min 1 s")
    }

    @Test("Short duration text includes nonzero seconds and formats zero")
    func shortDurationTextIncludesSecondsAndZero() {
        #expect(DurationText.shortFormat(seconds: 90) == "1 min 30 s")
        #expect(DurationText.shortFormat(seconds: 45) == "45 s")
        #expect(DurationText.shortFormat(seconds: 0) == "0 s")
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
            primaryCourse: .breakfast,
            ingredients: [
                Ingredient(name: "flour", quantity: "1 1/2 cups"),
                Ingredient(name: "salt", quantity: "as needed"),
            ],
            steps: ["Mix"],
            allergenReview: .reviewed([])
        )

        let card = RecipeCardPresentation(recipe: recipe, householdSize: 2, intolerances: [])

        #expect(card.recipeID == "pasta")
        #expect(card.name == "Pasta")
        #expect(card.durationLabel == "1 hour 1 minute")
        #expect(card.difficultyLabel == "intermediate")
        #expect(card.servingsLabel == "Serves 1")
        #expect(card.primaryCourse == .breakfast)
        #expect(card.ingredientQuantities == ["1 1/2 cups", "as needed"])
    }

    @Test("Card rank caps durations over an hour while prose keeps exact time")
    func cardRankCapsLongDurations() {
        let card = card(for: .medium, totalMinutes: 61)

        #expect(card.rankValue == "+60")
        #expect(card.rankUnit == "MIN")
        #expect(card.durationLabel == "1 hour 1 minute")
    }

    @Test("Card rank stays capped for durations longer than two hours")
    func cardRankStaysCappedForLongDurations() {
        let card = card(for: .medium, totalMinutes: 125)

        #expect(card.rankValue == "+60")
        #expect(card.rankUnit == "MIN")
        #expect(card.durationLabel == "2 hours 5 minutes")
    }

    @Test("Card rank preserves minute values through one hour")
    func cardRankPreservesMinutesThroughOneHour() {
        let zeroMinuteCard = card(for: .medium, totalMinutes: 0)
        let thirtyFiveMinuteCard = card(for: .medium, totalMinutes: 35)
        let oneHourCard = card(for: .medium, totalMinutes: 60)

        #expect(zeroMinuteCard.rankValue == "0")
        #expect(zeroMinuteCard.rankUnit == "MIN")
        #expect(thirtyFiveMinuteCard.rankValue == "35")
        #expect(thirtyFiveMinuteCard.rankUnit == "MIN")
        #expect(oneHourCard.rankValue == "60")
        #expect(oneHourCard.rankUnit == "MIN")
    }

    @Test("Card ingredients omit optional ingredients that conflict with the profile")
    func cardHidesOptionalIngredientsForIntolerance() {
        let recipe = Recipe(
            id: "dairy-garnish",
            name: "Dairy garnish",
            heroPhoto: .local("dairy-garnish"),
            totalMinutes: 10,
            difficulty: .easy,
            servings: 2,
            primaryCourse: .dinner,
            ingredients: [
                Ingredient(name: "Tomato", quantity: "2"),
                Ingredient(
                    name: "Greek yogurt",
                    quantity: "2 tbsp",
                    isOptional: true,
                    allergens: [.dairy]
                ),
            ],
            steps: ["Serve"],
            allergenReview: .reviewed([])
        )

        let card = RecipeCardPresentation(
            recipe: recipe,
            householdSize: 2,
            intolerances: [.dairy]
        )

        #expect(card.ingredientQuantities == ["2"])
    }

    @Test("Difficulty labels use the card vocabulary")
    func difficultyLabels() {
        #expect(card(for: .easy).difficultyLabel == "beginner")
        #expect(card(for: .medium).difficultyLabel == "intermediate")
        #expect(card(for: .hard).difficultyLabel == "advanced")
    }

    private func card(for difficulty: Difficulty, totalMinutes: Int = 1) -> RecipeCardPresentation {
        RecipeCardPresentation(
            recipe: Recipe(
                id: difficulty.rawValue,
                name: "Recipe",
                heroPhoto: .local("recipe.jpg"),
                totalMinutes: totalMinutes,
                difficulty: difficulty,
                servings: 2,
                primaryCourse: .dinner,
                ingredients: [Ingredient(name: "x", quantity: "1")],
                steps: ["Cook"],
                allergenReview: .reviewed([])
            ),
            householdSize: 1,
            intolerances: []
        )
    }
}
