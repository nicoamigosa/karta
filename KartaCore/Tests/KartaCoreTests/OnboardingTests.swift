import Testing
@testable import KartaCore

/// Minimal onboarding, exercised independently of UI.
@Suite("Onboarding — feed seed")
struct OnboardingFeedSeedTests {

    private func recipe(_ id: String, reviewedAllergens: [Allergen] = []) -> Recipe {
        Recipe(
            id: id, name: id, heroPhoto: .local("test"), totalMinutes: 10, difficulty: .easy, servings: 4,
            primaryCourse: .dinner, ingredients: [Ingredient(name: "x", quantity: "1")], steps: ["s"],
            allergenReview: .reviewed(Set(reviewedAllergens))
        )
    }

    @Test("A non-positive household size is rejected")
    func nonPositiveHouseholdSizeIsRejected() async {
        await #expect(processExitsWith: .failure) {
            _ = OnboardingProfile(intolerances: [], householdSize: 0)
        }
    }

    @Test("Onboarding intolerances seed a non-generic first feed via the engine")
    func intolerancesSeedFirstFeed() {
        let recipes = [recipe("safe"), recipe("glutenous", reviewedAllergens: [.gluten])]
        let profile = OnboardingProfile(intolerances: [.gluten], householdSize: 2)

        let firstFeed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: profile.feedFilters
        )

        // Non-generic: the intolerance-violating recipe is filtered out from the start.
        #expect(firstFeed.newRecipes.map(\.id) == ["safe"])
    }
}
