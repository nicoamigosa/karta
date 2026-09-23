import Testing
@testable import KartaCore

/// Minimal onboarding + taste calibration, exercised independently of UI.
@Suite("Onboarding — feed seed")
struct OnboardingFeedSeedTests {

    private func recipe(_ id: String, reviewedAllergens: [Allergen] = []) -> Recipe {
        Recipe(
            id: id, name: id, heroPhotoURL: "", totalMinutes: 10, difficulty: .easy, servings: 4,
            tags: [], ingredients: [Ingredient(name: "x", quantity: "1")], steps: ["s"],
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

@Suite("Onboarding — taste calibration")
struct TasteCalibrationTests {

    @Test("Calibration records the recipes the user tapped")
    func recordsTaps() {
        var calibration = TasteCalibration()
        calibration.tap("r1")
        calibration.tap("r2")
        calibration.tap("r1") // idempotent

        #expect(calibration.likedIDs == ["r1", "r2"])
    }

    @Test("Calibration taps never consume the cookbook save cap")
    func doesNotConsumeSaveCap() {
        var cookbook = Cookbook() // free tier, cap 7
        var calibration = TasteCalibration()

        // Many more taps than the save cap.
        for i in 0..<20 { calibration.tap("r\(i)") }

        // The cookbook is entirely untouched — calibration is a separate channel.
        #expect(cookbook.savedIDs.isEmpty)
        #expect(cookbook.isAtCap == false)
        #expect(cookbook.save("real-save") == .saved)
    }
}
