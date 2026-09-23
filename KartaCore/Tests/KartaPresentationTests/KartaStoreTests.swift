import Observation
import Synchronization
import Testing
import KartaCore
import KartaPresentation

@Suite("Karta store")
struct KartaStoreTests {

    @Test("A new presentation state starts at the For You root")
    func navigationStartsAtForYouRoot() {
        let state = KartaState()

        #expect(state.navigation.world == .forYou)
        #expect(state.navigation.routes.isEmpty)
        #expect(state.navigation.anchor(for: .forYou) == nil)
    }

    @Test("Navigation anchors are session-scoped")
    func navigationAnchorIsNotCarriedIntoNewState() {
        var previousState = KartaState()
        KartaReducer.reduce(
            &previousState,
            action: .setFeedAnchor(
                ScrollAnchor(recipeID: "recipe-4", relativeOffset: 0.25),
                world: .forYou
            )
        )

        let newState = KartaState()

        #expect(previousState.navigation.anchor(for: .forYou) != nil)
        #expect(newState.navigation.anchor(for: .forYou) == nil)
    }

    @Test("Opening a recipe and returning preserves the world's feed anchor")
    func detailBackPreservesFeedAnchor() {
        var state = KartaState()
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
        var state = KartaState()
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
        var state = KartaState()
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
        var state = KartaState()
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
        var state = KartaState()

        KartaReducer.reduce(&state, action: .saveRecipe("recipe-1"))

        #expect(state.cookbook.savedIDs == ["recipe-1"])
    }

    @Test("The pure reducer downgrades a cookbook without deleting saves")
    func reducerDowngradesCookbook() {
        var cookbook = Cookbook(saveCap: nil)
        for i in 0..<9 { #expect(cookbook.save("recipe-\(i)") == .saved) }
        var state = KartaState(cookbook: cookbook)

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
            tags: [],
            ingredients: [],
            steps: ["First step", "Second step"],
            allergenReview: .reviewed([])
        )
        var state = KartaState()

        KartaReducer.reduce(&state, action: .startCooking(recipe))
        KartaReducer.reduce(&state, action: .nextStep)

        #expect(state.session?.currentIndex == 1)
    }

    @MainActor
    @Test("The store applies an action through its public send entry point")
    func storeSendsSaveAction() {
        let store = KartaStore()

        store.send(.saveRecipe("recipe-1"))

        #expect(store.cookbook.savedIDs == ["recipe-1"])
        #expect(store.state.cookbook.savedIDs == ["recipe-1"])
    }

    @MainActor
    @Test("The store applies cooking actions through the same send entry point")
    func storeSendsCookingAction() {
        let store = KartaStore()

        store.send(.startCooking(recipe()))
        store.send(.nextStep)

        #expect(store.session?.currentIndex == 1)
    }

    @MainActor
    @Test("A value mutation through send invalidates an observation")
    func storeNotifiesObservers() {
        let store = KartaStore()
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
        let store = KartaStore(state: KartaState(session: recipe().cookingSession()))
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
        let store = KartaStore()
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
            tags: [],
            ingredients: [],
            steps: ["First step", "Second step"],
            allergenReview: .reviewed([])
        )
    }
}
