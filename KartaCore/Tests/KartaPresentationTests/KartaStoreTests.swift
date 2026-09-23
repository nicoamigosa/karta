import Foundation
import Observation
import Synchronization
import Testing
import KartaCore
import KartaPresentation

@Suite("Karta store")
struct KartaStoreTests {

    private var noIntolerances: SafetyProfile {
        SafetyProfile(intolerances: [])
    }

    @Test("A new presentation state starts at the For You root")
    func navigationStartsAtForYouRoot() {
        let state = KartaState(safetyProfile: noIntolerances)

        #expect(state.navigation.world == .forYou)
        #expect(state.navigation.routes.isEmpty)
        #expect(state.navigation.anchor(for: .forYou) == nil)
    }

    @Test("Navigation anchors are session-scoped")
    func navigationAnchorIsNotCarriedIntoNewState() {
        var previousState = KartaState(safetyProfile: noIntolerances)
        KartaReducer.reduce(
            &previousState,
            action: .setFeedAnchor(
                ScrollAnchor(recipeID: "recipe-4", relativeOffset: 0.25),
                world: .forYou
            )
        )

        let newState = KartaState(safetyProfile: noIntolerances)

        #expect(previousState.navigation.anchor(for: .forYou) != nil)
        #expect(newState.navigation.anchor(for: .forYou) == nil)
    }

    @Test("Opening a recipe and returning preserves the world's feed anchor")
    func detailBackPreservesFeedAnchor() {
        var state = KartaState(safetyProfile: noIntolerances)
        let anchor = ScrollAnchor(recipeID: "recipe-4", relativeOffset: 0.25)

        KartaReducer.reduce(
            &state,
            action: .setFeedAnchor(anchor, world: .forYou)
        )
        KartaReducer.reduce(
            &state,
            action: .pushRoute(.recipeDetail(recipeID: "recipe-4"))
        )
        #expect(state.navigation.routes == [.recipeDetail(recipeID: "recipe-4")])
        KartaReducer.reduce(&state, action: .popRoute)

        #expect(state.navigation.routes.isEmpty)
        #expect(state.navigation.anchor(for: .forYou) == anchor)
    }

    @Test("Switching worlds and returning preserves each world's anchor")
    func worldSwitchPreservesForYouAnchor() {
        var state = KartaState(safetyProfile: noIntolerances)
        let anchor = ScrollAnchor(recipeID: "recipe-4", relativeOffset: 0.25)
        let savedAnchor = ScrollAnchor(recipeID: "saved-2", relativeOffset: 0.75)

        KartaReducer.reduce(
            &state,
            action: .setFeedAnchor(anchor, world: .forYou)
        )
        KartaReducer.reduce(&state, action: .selectWorld(.saved))
        KartaReducer.reduce(
            &state,
            action: .setFeedAnchor(savedAnchor, world: .saved)
        )
        KartaReducer.reduce(&state, action: .selectWorld(.forYou))

        #expect(state.navigation.world == .forYou)
        #expect(state.navigation.anchor(for: .forYou) == anchor)
        #expect(state.navigation.anchor(for: .saved) == savedAnchor)
    }

    @Test("Changing feed filters discards the session anchors")
    func changingFiltersDiscardsAnchors() {
        var state = KartaState(safetyProfile: noIntolerances)
        let anchor = ScrollAnchor(recipeID: "recipe-4", relativeOffset: 0.25)
        KartaReducer.reduce(
            &state,
            action: .setFeedAnchor(anchor, world: .forYou)
        )

        KartaReducer.reduce(
            &state,
            action: .filter(.apply(FilterDraft(maxMinutes: 30)))
        )

        #expect(state.feedFilters == FeedFilters(intolerances: [], maxMinutes: 30))
        #expect(state.navigation.anchor(for: .forYou) == nil)
    }

    @Test("Applying a filter draft preserves the safety profile")
    func applyingFilterDraftPreservesSafetyProfile() {
        let profile = SafetyProfile(intolerances: [.dairy])
        var state = KartaState(safetyProfile: profile)

        KartaReducer.reduce(
            &state,
            action: .filter(.apply(FilterDraft(maxMinutes: 30)))
        )

        #expect(state.safetyProfile == profile)
        #expect(state.effectiveFeedFilters == FeedFilters(
            intolerances: [.dairy],
            maxMinutes: 30
        ))
    }

    @Test("Resetting filters preserves the safety profile")
    func resettingFiltersPreservesSafetyProfile() {
        let profile = SafetyProfile(intolerances: [.gluten, .nuts])
        var state = KartaState(
            safetyProfile: profile,
            filterDraft: FilterDraft(
                maxMinutes: 20,
                maxDifficulty: .medium,
                requireOnePan: true
            )
        )

        KartaReducer.reduce(&state, action: .filter(.reset))

        #expect(state.safetyProfile == profile)
        #expect(state.filterDraft == FilterDraft())
        #expect(state.effectiveFeedFilters == FeedFilters(
            intolerances: [.gluten, .nuts]
        ))
    }

    @Test("Cancelling filter editing leaves the applied safety profile unchanged")
    func cancellingFilterEditingPreservesSafetyProfile() {
        let profile = SafetyProfile(intolerances: [.dairy])
        var state = KartaState(
            safetyProfile: profile,
            filterDraft: FilterDraft(maxDifficulty: .hard)
        )
        let beforeCancel = state

        KartaReducer.reduce(&state, action: .filter(.cancel))

        #expect(state == beforeCancel)
        #expect(state.effectiveFeedFilters.intolerances == [.dairy])
    }

    @Test("Changing the safety profile preserves the filter draft")
    func changingSafetyProfilePreservesFilterDraft() {
        var state = KartaState(
            safetyProfile: SafetyProfile(intolerances: [.dairy]),
            filterDraft: FilterDraft(maxMinutes: 45, requireOnePan: true)
        )

        KartaReducer.reduce(
            &state,
            action: .filter(
                .setSafetyProfile(SafetyProfile(intolerances: [.gluten]))
            )
        )

        #expect(state.safetyProfile.intolerances == [.gluten])
        #expect(state.filterDraft == FilterDraft(maxMinutes: 45, requireOnePan: true))
        #expect(state.effectiveFeedFilters == FeedFilters(
            intolerances: [.gluten],
            maxMinutes: 45,
            requireOnePan: true
        ))
    }

    @Test("Switching worlds preserves the safety profile")
    func switchingWorldsPreservesSafetyProfile() {
        let profile = SafetyProfile(intolerances: [.dairy, .gluten])
        var state = KartaState(safetyProfile: profile)

        KartaReducer.reduce(&state, action: .selectWorld(.saved))
        KartaReducer.reduce(&state, action: .selectWorld(.leftovers))
        KartaReducer.reduce(&state, action: .selectWorld(.forYou))

        #expect(state.safetyProfile == profile)
        #expect(state.effectiveFeedFilters.intolerances == [.dairy, .gluten])
    }

    @Test("Editing intolerances is available on the free cookbook tier")
    func safetyProfileEditingIsNotPremiumGated() {
        var state = KartaState(
            cookbook: Cookbook(saveCap: Cookbook.freeSaveCap),
            safetyProfile: SafetyProfile(intolerances: [.dairy])
        )

        KartaReducer.reduce(
            &state,
            action: .filter(.setSafetyProfile(SafetyProfile(intolerances: [.nuts])))
        )

        #expect(state.cookbook.saveCap == Cookbook.freeSaveCap)
        #expect(state.safetyProfile.intolerances == [.nuts])
        #expect(state.effectiveFeedFilters.intolerances == [.nuts])
    }

    @Test("An anchor for a recipe absent from the feed resolves to the top")
    func staleAnchorResolvesToTop() {
        var state = KartaState(safetyProfile: noIntolerances)
        let currentAnchor = ScrollAnchor(recipeID: "recipe-1", relativeOffset: 0.25)
        KartaReducer.reduce(
            &state,
            action: .setFeedAnchor(currentAnchor, world: .forYou)
        )
        #expect(state.navigation.anchor(for: .forYou, in: [recipe()]) == currentAnchor)

        KartaReducer.reduce(
            &state,
            action: .setFeedAnchor(
                ScrollAnchor(recipeID: "missing", relativeOffset: 0.25),
                world: .forYou
            )
        )

        #expect(state.navigation.anchor(for: .forYou, in: [recipe()]) == nil)
    }

    @Test("The save action is applied by the pure reducer")
    func reducerSavesRecipe() {
        var state = KartaState(safetyProfile: noIntolerances)

        KartaReducer.reduce(&state, action: .saveRecipe("recipe-1"))

        #expect(state.cookbook.savedIDs == ["recipe-1"])
    }

    @Test("The pure reducer downgrades a cookbook without deleting saves")
    func reducerDowngradesCookbook() {
        var cookbook = Cookbook(saveCap: nil)
        for i in 0..<9 { #expect(cookbook.save("recipe-\(i)") == .saved) }
        var state = KartaState(cookbook: cookbook, safetyProfile: noIntolerances)

        KartaReducer.reduce(&state, action: .downgradeCookbookToFree)

        #expect(state.cookbook.savedIDs.count == 9)
        #expect(state.cookbook.saveCap == 9)
        #expect(state.cookbook.save("overflow") == .blockedByCap)
    }

    @Test("The pure reducer advances a started cooking session")
    func reducerAdvancesCookingSession() {
        let recipe = Recipe(
            id: "recipe-1",
            name: "Recipe",
            heroPhotoURL: "recipe.jpg",
            totalMinutes: 10,
            difficulty: .easy,
            servings: 4,
            tags: [],
            ingredients: [],
            steps: ["First step", "Second step"],
            allergenReview: .reviewed([])
        )
        var state = KartaState(safetyProfile: noIntolerances)

        KartaReducer.reduce(&state, action: .startCooking(recipe))
        KartaReducer.reduce(&state, action: .nextStep)

        #expect(state.session?.currentIndex == 1)
    }

    @MainActor
    @Test("The store applies an action through its public send entry point")
    func storeSendsSaveAction() {
        let store = KartaStore(state: KartaState(safetyProfile: noIntolerances))

        store.send(.saveRecipe("recipe-1"))

        #expect(store.cookbook.savedIDs == ["recipe-1"])
        #expect(store.state.cookbook.savedIDs == ["recipe-1"])
    }

    @MainActor
    @Test("Calibration through the store does not save a recipe")
    func storeCalibratesWithoutSaving() {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(householdSize: 2),
            safetyProfile: noIntolerances
        ))

        for index in 0..<20 {
            store.send(.onboarding(.tapCalibration("recipe-\(index)")))
        }
        store.send(.saveRecipe("real-save"))

        #expect(store.state.onboarding.calibration.likedIDs.count == 20)
        #expect(store.cookbook.savedIDs == ["real-save"])
        #expect(store.cookbook.isAtCap == false)
    }

    @MainActor
    @Test("Answering onboarding updates the store safety profile")
    func storeAnswersIntolerances() {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [.dairy])
        ))

        store.send(.onboarding(.answerIntolerances([])))

        #expect(store.state.onboarding.profile?.intolerances.isEmpty == true)
        #expect(store.state.safetyProfile.intolerances.isEmpty)
    }

    @MainActor
    @Test("The store's calibrated onboarding state changes its feed order")
    func storeCalibrationFeedsRanking() throws {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 2
            ),
            safetyProfile: noIntolerances
        ))
        store.send(.onboarding(.tapCalibration("low")))

        let feed = try #require(store.feed(
            recipes: [
                rankingRecipe("top", popularity: 90),
                rankingRecipe("low", popularity: 10),
            ],
            views: [],
            recentWindow: 7 * 24 * 60 * 60,
            clock: StoreTestClock(now: Date(timeIntervalSince1970: 1_000_000))
        ))

        #expect(feed.newRecipes.map(\.id) == ["low", "top"])
    }

    @MainActor
    @Test("The feed uses the active safety profile after onboarding")
    func feedUsesUpdatedSafetyProfileAfterOnboarding() throws {
        let store = KartaStore(state: KartaState(safetyProfile: noIntolerances))
        store.send(.onboarding(.answerIntolerances([])))
        store.send(.onboarding(.setHouseholdSize(2)))
        store.send(.filter(.setSafetyProfile(SafetyProfile(intolerances: [.dairy]))))

        let feed = try #require(store.feed(
            recipes: [
                allergenRecipe("safe", allergens: []),
                allergenRecipe("dairy", allergens: [.dairy]),
            ],
            views: [],
            recentWindow: 7 * 24 * 60 * 60,
            clock: StoreTestClock(now: Date(timeIntervalSince1970: 1_000_000))
        ))

        #expect(feed.newRecipes.map(\.id) == ["safe"])
    }

    @MainActor
    @Test("The store applies cooking actions through the same send entry point")
    func storeSendsCookingAction() {
        let store = KartaStore(state: KartaState(safetyProfile: noIntolerances))

        store.send(.startCooking(recipe()))
        store.send(.nextStep)

        #expect(store.session?.currentIndex == 1)
    }

    @MainActor
    @Test("A value mutation through send invalidates an observation")
    func storeNotifiesObservers() {
        let store = KartaStore(state: KartaState(safetyProfile: noIntolerances))
        let changes = Mutex(0)

        withObservationTracking {
            _ = store.cookbook.savedIDs
        } onChange: {
            changes.withLock { $0 += 1 }
        }

        store.send(.saveRecipe("recipe-1"))

        #expect(changes.withLock { $0 } == 1)
    }

    @MainActor
    @Test("A session mutation through send invalidates an observation")
    func storeNotifiesSessionObservers() {
        let store = KartaStore(state: KartaState(
            session: recipe().cookingSession(),
            safetyProfile: noIntolerances
        ))
        let changes = Mutex(0)

        withObservationTracking {
            _ = store.session?.currentIndex
        } onChange: {
            changes.withLock { $0 += 1 }
        }

        store.send(.nextStep)

        #expect(changes.withLock { $0 } == 1)
    }

    @MainActor
    @Test("State and actions can be handed to an external task as values")
    func valuesAreSendable() async {
        let store = KartaStore(state: KartaState(safetyProfile: noIntolerances))
        store.send(.saveRecipe("recipe-1"))
        let state = store.state
        let action: KartaStore.Action = .unsaveRecipe("recipe-1")

        let wasSaved = await Task.detached {
            switch action {
            case let .unsaveRecipe(id):
                return state.cookbook.isSaved(id)
            default:
                return false
            }
        }.value

        #expect(wasSaved)
    }

    private func recipe() -> Recipe {
        Recipe(
            id: "recipe-1",
            name: "Recipe",
            heroPhotoURL: "recipe.jpg",
            totalMinutes: 10,
            difficulty: .easy,
            servings: 4,
            tags: [],
            ingredients: [],
            steps: ["First step", "Second step"],
            allergenReview: .reviewed([])
        )
    }

    private func rankingRecipe(_ id: String, popularity: Int) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: 10,
            difficulty: .easy,
            servings: 2,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["Cook"],
            allergenReview: .reviewed([]),
            popularity: popularity
        )
    }

    private func allergenRecipe(_ id: String, allergens: Set<Allergen>) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: 10,
            difficulty: .easy,
            servings: 2,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["Cook"],
            allergenReview: .reviewed(allergens)
        )
    }
}

private struct StoreTestClock: KartaClock {
    let now: Date
}
