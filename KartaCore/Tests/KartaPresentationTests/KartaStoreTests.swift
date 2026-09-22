import Observation
import Synchronization
import Testing
import KartaCore
import KartaPresentation

@Suite("Karta store")
struct KartaStoreTests {

    @Test("The save action is applied by the pure reducer")
    func reducerSavesRecipe() {
        var state = KartaState()

        KartaReducer.reduce(&state, action: .saveRecipe("recipe-1"))

        #expect(state.cookbook.savedIDs == ["recipe-1"])
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
