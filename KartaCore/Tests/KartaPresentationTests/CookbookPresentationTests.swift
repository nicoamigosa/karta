import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Cookbook presentation")
struct CookbookPresentationTests {
    @Test("The store projects both halves and their counts in saved order")
    @MainActor
    func rowsAndCountsFollowSavedOrder() {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["try-b", "inferred", "missing", "explicit", "unreviewed", "try-a"]),
            cookHistory: [
                CookEntry(recipeID: "explicit", date: Date(timeIntervalSince1970: 1)),
                CookEntry(recipeID: "inferred", date: Date(timeIntervalSince1970: 2), wasInferred: true),
                CookEntry(recipeID: "unsaved", date: Date(timeIntervalSince1970: 3)),
            ],
            safetyProfile: SafetyProfile(intolerances: []),
            filterDraft: FilterDraft(maxMinutes: 5)
        ))
        let catalog = [
            recipe("explicit"), recipe("try-a"), recipe("unsaved"),
            recipe("inferred"), recipe("try-b"), recipe("unreviewed", review: .unreviewed),
        ]

        let presentation = store.cookbookPresentation(recipes: catalog)

        #expect(presentation.repertoire.map(\.recipeID) == ["inferred", "explicit"])
        #expect(presentation.wantToTry.map(\.recipeID) == ["try-b", "try-a"])
        #expect(presentation.repertoireCount == 2)
        #expect(presentation.wantToTryCount == 2)
        #expect(presentation.wantToTry.first?.name == "Recipe try-b")
        #expect(presentation.wantToTry.first?.photo == .local("try-b"))
        #expect(presentation.wantToTry.first?.timeLabel == "35 MIN")
    }

    @Test("Cooking and saving again keep Repertorio membership and history", arguments: [false, true])
    @MainActor
    func cookingAndResavingPreserveRepertoire(wasInferred: Bool) {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        let catalog = [recipe("cooked"), recipe("uncooked")]
        let entry = CookEntry(
            recipeID: "cooked", date: Date(timeIntervalSince1970: 1), wasInferred: wasInferred
        )

        let empty = store.cookbookPresentation(recipes: catalog)
        #expect(empty.repertoireCount == 0)
        #expect(empty.wantToTryCount == 0)

        store.send(.recordCook(entry))
        let unsaved = store.cookbookPresentation(recipes: catalog)
        #expect(unsaved.repertoire.isEmpty)
        #expect(unsaved.wantToTry.isEmpty)

        store.send(.saveRecipe("cooked"))
        store.send(.saveRecipe("uncooked"))
        let saved = store.cookbookPresentation(recipes: catalog)
        #expect(saved.repertoire.map(\.recipeID) == ["cooked"])
        #expect(saved.wantToTry.map(\.recipeID) == ["uncooked"])

        store.send(.unsaveRecipe("cooked"))
        let removed = store.cookbookPresentation(recipes: catalog)
        #expect(removed.repertoireCount == 0)
        #expect(removed.wantToTryCount == 1)
        #expect(store.state.cookHistory == [entry])

        store.send(.saveRecipe("cooked"))
        let restored = store.cookbookPresentation(recipes: catalog)
        #expect(restored.repertoire.map(\.recipeID) == ["cooked"])
        #expect(restored.repertoireCount == 1)
        #expect(restored.wantToTryCount == 1)
        #expect(store.state.cookHistory == [entry])

        store.send(.recordCook(CookEntry(recipeID: "uncooked", date: Date(timeIntervalSince1970: 2))))
        let allCooked = store.cookbookPresentation(recipes: catalog)
        #expect(allCooked.repertoire.map(\.recipeID) == ["uncooked", "cooked"])
        #expect(allCooked.repertoireCount == 2)
        #expect(allCooked.wantToTryCount == 0)
    }

    private func recipe(_ id: String, review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(
            id: id, name: "Recipe \(id)", heroPhoto: .local(id),
            totalMinutes: 35, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [], steps: ["Cook"], allergenReview: review
        )
    }
}
