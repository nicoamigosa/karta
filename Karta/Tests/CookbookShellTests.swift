import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Cookbook shell")
struct CookbookShellTests {

    @Test("The cookbook reopens on the last half, Por probar the first time")
    func reopeningHalf() {
        #expect(CookbookHalf.reopening(stored: nil) == .wantToTry)
        #expect(CookbookHalf.reopening(stored: "repertoire") == .repertoire)
        #expect(CookbookHalf.reopening(stored: "wantToTry") == .wantToTry)
        #expect(CookbookHalf.reopening(stored: "bogus") == .wantToTry)
    }

    @Test("Only a reverse opened in the cookbook closes and reopens on Undo")
    func unsaveOriginFlow() {
        #expect(UnsaveOrigin.cookbookReverse.closesReverse)
        #expect(UnsaveOrigin.cookbookReverse.undoReopensReverse)
        #expect(!UnsaveOrigin.feedReverse.closesReverse)
        #expect(!UnsaveOrigin.feedReverse.undoReopensReverse)
        #expect(!UnsaveOrigin.cookbookGrid.closesReverse)
        #expect(!UnsaveOrigin.cookbookGrid.undoReopensReverse)
    }

    @Test("A blocked save plays the cookbook-full sheet, a save the animation")
    func saveTapEffect() {
        #expect(SaveTap.effect(of: .saved) == .saved)
        #expect(SaveTap.effect(of: .alreadySaved) == .saved)
        #expect(SaveTap.effect(of: .blockedByCap(saved: 7, ceiling: 7)) == .cookbookFull)
        #expect(SaveTap.effect(of: nil) == .none)
    }

    @MainActor
    @Test("Save lands in Want to try, unsave removes it, Undo restores it")
    func saveUnsaveRoundTrip() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let store = KartaStore(state: KartaState(
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        store.send(.saveRecipe(recipe.id))
        #expect(store.cookbook.isSaved(recipe.id))
        #expect(SaveTap.effect(of: store.state.lastSaveResult) == .saved)
        #expect(store.cookbookPresentation(recipes: recipes)
            .wantToTry.map(\.recipeID) == [recipe.id])

        store.send(.unsaveRecipe(recipe.id))
        #expect(!store.cookbook.isSaved(recipe.id))
        #expect(store.state.pendingUnsave != nil)
        #expect(store.cookbookPresentation(recipes: recipes).wantToTry.isEmpty)

        store.send(.undoUnsave)
        #expect(store.cookbook.isSaved(recipe.id))
        #expect(store.state.pendingUnsave == nil)
        #expect(store.cookbookPresentation(recipes: recipes)
            .wantToTry.map(\.recipeID) == [recipe.id])
    }

    @MainActor
    @Test("A seventh save at the cap leaves the pill at Save and yields the sheet")
    func capBlocksSave() throws {
        let cookbook = Cookbook(
            savedIDs: (1...7).map { "recipe-\($0)" },
            saveCap: Cookbook.freeSaveCap
        )
        let store = KartaStore(state: KartaState(
            cookbook: cookbook,
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        store.send(.saveRecipe("recipe-8"))
        #expect(!store.cookbook.isSaved("recipe-8"))
        #expect(SaveTap.effect(of: store.state.lastSaveResult) == .cookbookFull)
        let full = try #require(store.blockedByCap)
        #expect(full.countLabel == "7 OF 7 SAVED")
    }
}
