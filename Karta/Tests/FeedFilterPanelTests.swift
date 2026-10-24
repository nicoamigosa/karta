import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Filter panel and feed empty states")
struct FeedFilterPanelTests {
    private struct FixedClock: KartaClock {
        let now: Date
    }

    @MainActor
    private func makeStore(
        intolerances: Set<Allergen> = [],
        draft: FilterDraft = FilterDraft()
    ) -> KartaStore {
        KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: intolerances),
            filterDraft: draft
        ))
    }

    private var clock: FixedClock {
        FixedClock(now: Date(timeIntervalSince1970: 1_800_000_000))
    }

    @MainActor
    @Test("Draft edits stay local until Show N recipes applies them at once")
    func draftAppliesAtOnce() throws {
        let store = makeStore()
        // The panel opens with the applied draft and edits it locally.
        var draft = store.state.filterDraft
        var panel = FilterPanelPresentation(
            draft: draft,
            safetyProfile: store.state.safetyProfile
        )
        draft = panel.nextDraft(after: .readyIn(30))
        panel = FilterPanelPresentation(
            draft: draft,
            safetyProfile: store.state.safetyProfile
        )
        draft = panel.nextDraft(after: .practical(.onePan))

        // Nothing reaches the feed while the draft is being edited.
        #expect(store.state.appliedFilterCount == 0)

        store.send(.filter(.apply(draft)))

        #expect(store.state.filterDraft.maxMinutes == 30)
        #expect(store.state.filterDraft.practicalTags == [.onePan])
        #expect(store.state.appliedFilterCount == 2)

        let recipes = try SeedResourceAdapter().loadRecipes()
        let feed = try #require(store.feed(recipes: recipes, clock: clock))
        // Only recipes that pass the applied draft are dealt.
        #expect(feed.recipes.allSatisfy {
            $0.totalMinutes <= 30 && $0.practicalTags.contains(.onePan)
        })
    }

    @MainActor
    @Test("Closing the panel without applying throws the draft away")
    func cancelDiscardsDraft() {
        let store = makeStore(
            draft: FilterDraft(maxMinutes: 45)
        )
        store.send(.filter(.cancel))
        #expect(store.state.filterDraft.maxMinutes == 45)
    }

    @MainActor
    @Test("Tapping an allergen saves it at once and Reset/Clear never touch it")
    func intoleranceSavedImmediately() throws {
        let store = makeStore()
        let panel = FilterPanelPresentation(
            draft: FilterDraft(),
            safetyProfile: store.state.safetyProfile
        )

        // The tap is committed through the store right away — no draft, no
        // paywall, and it survives any later draft decision.
        store.send(.filter(.setSafetyProfile(panel.nextSafetyProfile(toggling: .gluten))))
        #expect(store.state.safetyProfile.intolerances == [.gluten])
        #expect(
            FilterPanelPresentation(
                draft: FilterDraft(),
                safetyProfile: store.state.safetyProfile
            ).intoleranceNote(after: .gluten)
                == "Saved. Gluten is now hidden everywhere. Reset and Clear never touch it."
        )

        store.send(.filter(.apply(FilterDraft(maxMinutes: 20))))
        store.send(.filter(.reset))
        #expect(store.state.safetyProfile.intolerances == [.gluten])
        #expect(store.state.appliedFilterCount == 0)
        // Intolerancias never count toward the badge.
        #expect(store.state.appliedFilterCount == 0)
    }

    @MainActor
    @Test("A declared intolerance never shows a violating recipe in the feed")
    func intoleranceNeverViolated() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(intolerances: [.dairy])

        let feed = try #require(store.feed(recipes: recipes, clock: clock))
        #expect(!feed.recipes.isEmpty)
        #expect(feed.recipes.allSatisfy { recipe in
            if case let .reviewed(allergens) = recipe.allergenReview {
                return !allergens.contains(.dairy)
            }
            return false
        })

        // Even a draft that would otherwise match a dairy recipe cannot
        // smuggle it back.
        store.send(.filter(.apply(FilterDraft(maxMinutes: 20))))
        let filtered = try #require(store.feed(recipes: recipes, clock: clock))
        #expect(filtered.recipes.allSatisfy { recipe in
            if case let .reviewed(allergens) = recipe.allergenReview {
                return !allergens.contains(.dairy)
            }
            return false
        })
    }

    @MainActor
    @Test("The empty-filter state offers the panel and Clear keeps intolerances")
    func emptyForFilters() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(intolerances: [.dairy])
        store.send(.filter(.apply(FilterDraft(maxMinutes: 20, practicalTags: [.onePan]))))

        guard case let .noMatchForFilters(summary, keptIntolerances) = try #require(
            store.feedEmptyState(recipes: recipes, clock: clock)
        ) else {
            Issue.record("expected noMatchForFilters")
            return
        }
        #expect(summary == "No one-pan recipe is ready in 20 min.")
        #expect(keptIntolerances == "dairy stays hidden")

        // "Clear all filters" sends .filter(.reset); the Intolerancia stays.
        store.send(.filter(.reset))
        #expect(store.state.safetyProfile.intolerances == [.dairy])
        let feed = try #require(store.feed(recipes: recipes, clock: clock))
        #expect(!feed.isEmpty)
    }

    @MainActor
    @Test("The profile empty state wins when filters also match nothing")
    func emptyForProfile() throws {
        // The bundled catalog keeps two allergen-free recipes, so the profile
        // state needs a catalog where nothing reviewed fits the Intolerancias.
        let recipes = try SeedResourceAdapter().loadRecipes().filter {
            !["quick-chicken-curry", "lentil-stew"].contains($0.id)
        }
        let store = makeStore(intolerances: Set(Allergen.allCases))
        store.send(.filter(.apply(FilterDraft(maxMinutes: 20))))

        guard case let .noMatchForProfile(allergens) = try #require(
            store.feedEmptyState(recipes: recipes, clock: clock)
        ) else {
            Issue.record("expected noMatchForProfile")
            return
        }
        #expect(allergens == "dairy, egg, fish, gluten and nuts")
    }

    @MainActor
    @Test("A live draft count reads from the store, not from the view")
    func draftCountFromStore() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(intolerances: [.dairy])
        let draft = FilterPanelPresentation(
            draft: FilterDraft(maxMinutes: 30, practicalTags: [.onePan]),
            safetyProfile: store.state.safetyProfile
        ).nextDraft(after: .readyIn(30))

        let count = try #require(
            store.state.draftRecipeCount(
                for: .forYou,
                draft: draft,
                recipes: recipes,
                clock: clock
            )
        )
        // 25 min one-pan curry + 25 min one-pan stir-fry; the 35 min tortilla
        // and the 50 min lentil stew are out, dairy or no dairy.
        #expect(count == 2)
        #expect(FilterPanelPresentation.showRecipesLabel(count: count) == "Show 2 recipes")
        #expect(FilterPanelPresentation.showRecipesLabel(count: 1) == "Show 1 recipe")
    }
}
