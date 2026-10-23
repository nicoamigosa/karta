import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Feed header")
struct FeedHeaderTests {
    @Test("The Mundo menu offers For You then Leftovers")
    func worlds() {
        #expect(World.allCases == [.forYou, .leftovers])
    }

    @Test("Filters applied in For You stay in force in both Mundos")
    func sharedFilters() {
        let profile = SafetyProfile(intolerances: [.dairy, .gluten])
        let draft = FilterDraft(maxMinutes: 30, maxDifficulty: .easy, course: .dinner,
                                diet: .vegetarian, practicalTags: [.onePan, .shareable])
        var state = KartaState(safetyProfile: profile)
        KartaReducer.reduce(&state, action: .filter(.apply(draft)))
        let filters = state.effectiveFeedFilters
        for world in World.allCases + [.forYou] {
            KartaReducer.reduce(&state, action: .selectWorld(world))
            #expect(state.filterDraft == draft)
            #expect(state.safetyProfile == profile)
            #expect(state.effectiveFeedFilters == filters)
        }
    }

    @Test("The panel exposes every option in panel order and its current selection")
    func panelOptions() {
        let panel = FilterPanelPresentation(
            draft: FilterDraft(maxMinutes: 30, maxDifficulty: .medium,
                               diet: .vegan, practicalTags: [.onePan, .makeAhead]),
            safetyProfile: SafetyProfile(intolerances: [.dairy, .gluten]))
        #expect(panel.intolerances.map(\.allergen) == [.dairy, .egg, .fish, .gluten, .nuts])
        #expect(panel.intolerances.map(\.label) == ["Dairy", "Egg", "Fish", "Gluten", "Nuts"])
        #expect(panel.intolerances.map(\.isOn) == [true, false, false, true, false])
        #expect(panel.readyIn.map(\.value) == [nil, 20, 30, 45, 60])
        #expect(panel.readyIn.map(\.label) == ["Any", "20", "30", "45", "60"])
        #expect(panel.readyIn.map(\.isOn) == [false, false, true, false, false])
        #expect(panel.difficulty.map(\.value) == [nil, .easy, .medium])
        #expect(panel.difficulty.map(\.label) == ["Any", "Easy", "Up to medium"])
        #expect(panel.difficulty.map(\.isOn) == [false, false, true])
        #expect(panel.practical.map(\.value) == [.onePan, .oven, .makeAhead, .shareable])
        #expect(panel.practical.map(\.label) == ["One pan", "Oven", "Make ahead", "Shareable"])
        #expect(panel.practical.map(\.isOn) == [true, false, true, false])
        #expect(panel.diet.map(\.value) == [nil, .vegetarian, .vegan])
        #expect(panel.diet.map(\.label) == ["Any", "Vegetarian", "Vegan"])
        #expect(panel.diet.map(\.isOn) == [false, false, true])
    }

    @Test("Single choices replace, Practical toggles, and Reset only edits the draft")
    func panelDraftTaps() {
        let profile = SafetyProfile(intolerances: [.dairy])
        var draft = FilterDraft(maxMinutes: 30, maxDifficulty: .easy, course: .lunch,
                                diet: .vegetarian, practicalTags: [.onePan])
        func tap(_ action: FilterPanelPresentation.DraftAction) {
            draft = FilterPanelPresentation(draft: draft, safetyProfile: profile).nextDraft(after: action)
        }
        tap(.readyIn(45))
        tap(.readyIn(45))
        tap(.difficulty(.medium))
        tap(.diet(.vegan))
        tap(.practical(.oven))
        #expect(draft == FilterDraft(maxMinutes: 45, maxDifficulty: .medium, course: .lunch,
                                     diet: .vegan, practicalTags: [.onePan, .oven]))
        tap(.practical(.onePan))
        tap(.readyIn(nil))
        tap(.difficulty(nil))
        tap(.diet(nil))
        #expect(draft == FilterDraft(course: .lunch, practicalTags: [.oven]))
        tap(.reset)
        #expect(draft == FilterDraft(course: .lunch))
        let panel = FilterPanelPresentation(draft: draft, safetyProfile: profile)
        #expect(panel.readyIn.map(\.isOn) == [true, false, false, false, false])
        #expect(panel.difficulty.map(\.isOn) == [true, false, false])
        #expect(panel.diet.map(\.isOn) == [true, false, false])
        #expect(panel.practical.allSatisfy { !$0.isOn })
        #expect(panel.intolerances.first?.isOn == true)
    }

    @Test("Intolerancia taps save separately and the note describes the latest change")
    func intoleranceTaps() {
        let draft = FilterDraft(maxMinutes: 30, course: .dinner, practicalTags: [.onePan])
        var state = KartaState(safetyProfile: SafetyProfile(intolerances: [.dairy]), filterDraft: draft)
        let panel = FilterPanelPresentation(draft: draft, safetyProfile: state.safetyProfile)
        #expect(panel.intoleranceNote(after: nil) == nil)
        let added = panel.nextSafetyProfile(toggling: .gluten)
        #expect(added.intolerances == [.dairy, .gluten])
        KartaReducer.reduce(&state, action: .filter(.setSafetyProfile(added)))
        let saved = FilterPanelPresentation(draft: draft, safetyProfile: state.safetyProfile)
        #expect(saved.intoleranceNote(after: .gluten) ==
                "Saved. Gluten is now hidden everywhere. Reset and Clear never touch it.")
        #expect(state.filterDraft == draft)
        KartaReducer.reduce(&state, action: .filter(.cancel))
        #expect(state.safetyProfile == added)
        KartaReducer.reduce(&state, action: .filter(.setSafetyProfile(saved.nextSafetyProfile(toggling: .gluten))))
        let removed = FilterPanelPresentation(draft: draft, safetyProfile: state.safetyProfile)
        #expect(removed.intoleranceNote(after: .gluten) == "Saved. Gluten recipes can show up again.")
        #expect(state.safetyProfile.intolerances == [.dairy])
        #expect(state.filterDraft == draft)
    }

    @Test("The draft count matches the seed without applying or counting the frontier")
    func seedDraftCount() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let clock = HeaderClock()
        var state = KartaState(
            onboarding: OnboardingState(intoleranceAnswer: .answered([.dairy]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [.dairy]),
            filterDraft: FilterDraft(maxMinutes: 60))
        KartaReducer.reduce(&state, action: .recordView(recipeID: "quick-chicken-curry", at: clock.now))
        let before = state
        #expect(state.draftRecipeCount(for: .forYou,
                    draft: FilterDraft(maxMinutes: 30, practicalTags: [.onePan]), recipes: recipes, clock: clock) == 2)
        #expect(state.draftRecipeCount(for: .forYou,
                    draft: FilterDraft(maxMinutes: 20, practicalTags: [.onePan]), recipes: recipes, clock: clock) == 0)
        #expect(state.draftRecipeCount(for: .forYou,
                    draft: FilterDraft(practicalTags: [.onePan]), recipes: recipes, clock: clock) == 4)
        #expect(state.draftRecipeCount(for: .forYou, draft: FilterDraft(), recipes: recipes, clock: clock) == 5)
        #expect(state == before)
        KartaReducer.reduce(&state, action: .filter(.setSafetyProfile(SafetyProfile(intolerances: [.dairy, .gluten]))))
        #expect(state.draftRecipeCount(for: .forYou, draft: FilterDraft(), recipes: recipes, clock: clock) == 4)
        #expect(state.draftRecipeCount(for: .leftovers, draft: FilterDraft(), recipes: recipes, clock: clock) == nil)
    }
    @Test("Draft previews enforce every Intolerancia, review, Dieta and all Practical tags",
          arguments: Allergen.allCases)
    func draftCountSafetyAndTaxonomy(_ allergen: Allergen) throws {
        func recipe(_ id: String, review: AllergenReview = .reviewed([]),
                    diets: Set<Diet> = [.vegetarian],
                    tags: Set<PracticalTag> = [.onePan, .makeAhead]) -> Recipe {
            Recipe(id: id, name: id, heroPhoto: .remote(URL(string: "https://img.karta.app/test.jpg")!),
                   totalMinutes: 30, difficulty: .easy, servings: 2, primaryCourse: .dinner,
                   diets: diets, practicalTags: tags, ingredients: [Ingredient(name: "Rice", quantity: "1 cup")],
                   steps: ["Cook rice"], allergenReview: review)
        }
        let recipes = [recipe("vegetarian"), recipe("vegan", diets: [.vegan]),
                       recipe("unsafe", review: .reviewed([allergen])),
                       recipe("unreviewed", review: .unreviewed),
                       recipe("missing-tag", tags: [.onePan]), recipe("no-diet", diets: [])]
        let draft = FilterDraft(diet: .vegetarian, practicalTags: [.onePan, .makeAhead])
        let clock = HeaderClock()
        var state = KartaState(
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [allergen]))
        KartaReducer.reduce(&state, action: .recordView(recipeID: "vegan", at: clock.now))
        let before = state
        #expect(state.draftRecipeCount(for: .forYou, draft: draft, recipes: recipes, clock: clock) == 2)
        #expect(state == before)
        KartaReducer.reduce(&state, action: .filter(.apply(draft)))
        let feed = try #require(state.feed(recipes: recipes, clock: clock))
        #expect(feed.newRecipes.map(\.id) == ["vegetarian"])
        #expect(feed.alreadySeenRecipes.map(\.id) == ["vegan"])
        #expect(state.draftRecipeCount(for: state.navigation.world, draft: draft,
                                      recipes: recipes, clock: clock) == feed.recipes.count)
        #expect(state.draftRecipeCount(for: .forYou, draft: FilterDraft(diet: .vegan),
                                      recipes: recipes, clock: clock) == 1)
        #expect(KartaState(safetyProfile: state.safetyProfile).draftRecipeCount(
            for: .forYou, draft: draft, recipes: recipes, clock: clock) == nil)
    }

    @Test("The badge counts applied non-safety filters, including each Practical tag and Course")
    func appliedBadgeCount() {
        var state = KartaState(safetyProfile: SafetyProfile(intolerances: [.dairy, .gluten]))
        #expect(state.appliedFilterCount == 0)
        KartaReducer.reduce(&state, action: .filter(.apply(FilterDraft(maxMinutes: 30, practicalTags: [.onePan]))))
        #expect(state.appliedFilterCount == 2)
        KartaReducer.reduce(&state, action: .filter(.apply(FilterDraft(
            maxMinutes: 45, maxDifficulty: .medium, course: .dinner,
            diet: .vegan, practicalTags: [.onePan, .oven, .makeAhead, .shareable]))))
        #expect(state.appliedFilterCount == 8)
        KartaReducer.reduce(&state, action: .filter(.reset))
        #expect(state.appliedFilterCount == 0)
        #expect(state.safetyProfile.intolerances == [.dairy, .gluten])
    }

    @Test("The apply button handles zero, one and multiple recipes")
    func showRecipesLabel() {
        #expect(FilterPanelPresentation.showRecipesLabel(count: 0) == "Show 0 recipes")
        #expect(FilterPanelPresentation.showRecipesLabel(count: 1) == "Show 1 recipe")
        #expect(FilterPanelPresentation.showRecipesLabel(count: 2) == "Show 2 recipes")
    }

}

private struct HeaderClock: KartaClock {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
}
