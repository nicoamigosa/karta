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

    @Test("Cupo count appears only within two slots of a finite ceiling", arguments: [
        (4, 7, nil),
        (5, 7, "5 of 7 saved on the free plan"),
        (6, 7, "6 of 7 saved on the free plan"),
        (7, 7, "7 of 7 saved on the free plan"),
        (23, 23, "23 of 23 saved on the free plan"),
        (5, nil, nil), (7, nil, nil), (23, nil, nil),
    ] as [(Int, Int?, String?)])
    func cupoCount(count: Int, ceiling: Int?, expected: String?) {
        let state = KartaState(
            cookbook: Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: ceiling),
            safetyProfile: SafetyProfile(intolerances: [])
        )

        #expect(state.cookbookPresentation(recipes: []).cupoCountLine == expected)
    }

    @Test("Unsave toast and Undo preserve the Cookbook and cooking history", arguments: [
        (7, Optional(7), "Recipe r3"),
        (8, Optional(8), "Your cookbook now holds 7 recipes"),
        (23, Optional(23), "Your cookbook now holds 22 recipes"),
        (23, nil, "Recipe r3"),
    ] as [(Int, Int?, String)])
    @MainActor
    func unsaveToastAndUndo(count: Int, ceiling: Int?, secondLine: String) throws {
        let original = Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: ceiling)
        let history = [CookEntry(recipeID: "r3", date: Date(timeIntervalSince1970: 1))]
        let store = KartaStore(state: KartaState(
            cookbook: original, cookHistory: history, safetyProfile: SafetyProfile(intolerances: [])
        ))
        #expect(store.unsaveToast(recipes: [recipe("r3")]) == nil)

        store.send(.unsaveRecipe("r3"))
        let toast = try #require(store.unsaveToast(recipes: [recipe("r3")]))
        #expect(toast.title == "Removed from cookbook")
        #expect(toast.secondLine == secondLine)
        #expect(toast.recipeID == "r3")
        #expect(!store.cookbook.isSaved("r3"))

        store.send(.undoUnsave)
        #expect(store.cookbook == original)
        #expect(store.state.cookHistory == history)
        #expect(store.unsaveToast(recipes: [recipe("r3")]) == nil)
        store.send(.undoUnsave)
        #expect(store.cookbook == original)
    }

    @Test("A cap-blocked save exposes the full sheet count", arguments: [
        (7, "7 OF 7 SAVED"), (23, "23 OF 23 SAVED"),
    ])
    @MainActor
    func blockedSaveCount(count: Int, label: String) throws {
        var cookbook = Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: nil)
        cookbook.downgradeToFree()
        let store = KartaStore(state: KartaState(
            cookbook: cookbook, safetyProfile: SafetyProfile(intolerances: [])
        ))
        #expect(store.blockedByCap == nil)

        store.send(.saveRecipe("overflow"))
        let full = try #require(store.blockedByCap)
        #expect(full.savedCount == count)
        #expect(full.ceiling == count)
        #expect(full.countLabel == label)
        #expect(store.cookbook == cookbook)
        #expect(store.state.lastSaveResult == .blockedByCap(saved: count, ceiling: count))

        store.send(.saveRecipe("r0"))
        #expect(store.state.lastSaveResult == .alreadySaved)
        #expect(store.blockedByCap == nil)
    }

    @Test("Undo cannot resurrect a removal after dismissal or a later save", arguments: [
        KartaAction.dismissUnsaveToast, .saveRecipe("new"),
    ])
    @MainActor
    func expiredUndoDoesNotRestore(action: KartaAction) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["r1", "r2"]),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.unsaveRecipe("r1"))
        store.send(action)
        let after = store.cookbook

        store.send(.undoUnsave)

        #expect(store.cookbook == after)
        #expect(!store.cookbook.isSaved("r1"))
        #expect(store.unsaveToast(recipes: [recipe("r1")]) == nil)
    }

    private func recipe(_ id: String, review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(
            id: id, name: "Recipe \(id)", heroPhoto: .local(id),
            totalMinutes: 35, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [], steps: ["Cook"], allergenReview: review
        )
    }
}
