import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

/// The shell's shopping flows, exercised through the same seams the views
/// send and render (`docs/shopping-list-contract.md`): the store carries
/// `recipes` and a clock like the app, so the shopping actions reduce.
@MainActor
@Suite("Shopping list shell")
struct ShoppingListShellTests {

    private struct FixedClock: KartaClock {
        var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    }

    /// The store the app builds: recipes + clock, like `DebugSeeds.store()`.
    private func makeStore(
        safetyProfile: SafetyProfile = SafetyProfile(intolerances: [])
    ) -> (store: KartaStore, recipes: [Recipe]) {
        let recipes = DebugSeeds.shellRecipes()
        let store = KartaStore(
            state: KartaState(safetyProfile: safetyProfile),
            recipes: recipes,
            clock: FixedClock()
        )
        return (store, recipes)
    }

    /// Saves `recipe` (premium) and returns it; seeds the cookbook.
    private func savedRecipe(
        _ store: KartaStore,
        from recipes: [Recipe],
        premium: Bool = true
    ) -> Recipe {
        if premium {
            store.send(.entitlementChanged(.premium))
        }
        let recipe = recipes[0]
        store.send(.saveRecipe(recipe.id))
        return recipe
    }

    @Test("Add sheet opens, unticking rows changes the count, confirm toasts")
    func addSheetFlow() {
        let (store, recipes) = makeStore()
        let recipe = savedRecipe(store, from: recipes)

        store.send(.shopping(.openAdd(recipe.id)))
        let sheet = try! #require(store.state.shoppingSheet)
        #expect(sheet.title == "Add to your list")
        #expect(sheet.subtitle == "Untick what you already have.")
        #expect(sheet.canConfirm)

        let keys = sheet.rows.map(\.ingredient.purchaseKey)
        // Pantry basics start unticked with their hint drawn.
        for row in sheet.rows where !sheet.selectedKeys.contains(row.ingredient.purchaseKey) {
            #expect(row.hint != nil)
        }
        // Unticking one more shrinks the button's count.
        let chosen = keys.first { sheet.selectedKeys.contains($0) }!
        let before = sheet.buttonTitle
        store.send(.shopping(.toggleChoice(chosen)))
        #expect(store.state.shoppingSheet!.buttonTitle != before)

        store.send(.shopping(.confirm))
        #expect(store.state.shoppingSheet == nil)
        #expect(store.state.shoppingList.contains(recipe.id))
        let toast = try! #require(store.state.shoppingToast)
        #expect(toast.action?.title == "See list")
    }

    @Test("The first toast's dismissal asks once, never twice")
    func asksAutoAddOnce() {
        let (store, recipes) = makeStore()
        let first = savedRecipe(store, from: recipes)
        store.send(.shopping(.openAdd(first.id)))
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingToast != nil)

        store.send(.shopping(.dismissToast))
        #expect(store.state.showsAutoAddQuestion)
        #expect(store.state.shoppingToast == nil)

        store.send(.shopping(.answerAutoAdd(false)))
        #expect(!store.state.addRecipesAsSaved)

        // Second add: no second question, and the switch stays off.
        let second = recipes[1]
        store.send(.saveRecipe(second.id))
        store.send(.shopping(.openAdd(second.id)))
        store.send(.shopping(.confirm))
        store.send(.shopping(.dismissToast))
        #expect(!store.state.showsAutoAddQuestion)
    }

    @Test("Yes turns the switch on; saves land on the list with a Review toast")
    func autoAdd() {
        let (store, recipes) = makeStore()
        let recipe = recipes[2]
        store.send(.entitlementChanged(.premium))
        store.send(.shopping(.setAutoAdd(true)))
        #expect(store.state.addRecipesAsSaved)

        store.send(.saveRecipe(recipe.id))
        #expect(store.state.shoppingList.contains(recipe.id))
        let toast = try! #require(store.state.shoppingToast)
        guard case let .review(id)? = toast.action else {
            Issue.record("expected a Review action, got \(String(describing: toast.action))")
            return
        }
        #expect(id == recipe.id)

        store.send(.shopping(.review(recipe.id)))
        #expect(store.state.shoppingSheet?.isReview == true)
    }

    @Test("The switch is premium: the free plan can't turn it on")
    func autoAddFree() {
        let (store, _) = makeStore()
        store.send(.entitlementChanged(.free))
        store.send(.shopping(.setAutoAdd(true)))
        #expect(!store.state.addRecipesAsSaved)
        #expect(store.state.showsShoppingInvitation)
    }

    @Test("The pill saves, adds to the list, removes it — never unsaves")
    func pillNeverUnsaves() {
        let (store, recipes) = makeStore()
        let recipe = savedRecipe(store, from: recipes)
        let presentation = try! #require(store.reversePresentation(for: recipe))

        #expect(presentation.isSaved)
        #expect(presentation.pillTitle == "Add to list")
        store.send(presentation.pillAction)
        #expect(store.state.shoppingSheet != nil)
        #expect(store.state.cookbook.isSaved(recipe.id))

        store.send(.shopping(.confirm))
        #expect(store.reversePresentation(for: recipe)?.pillTitle == "On your list")

        store.send(store.reversePresentation(for: recipe)!.pillAction)
        #expect(!store.state.shoppingList.contains(recipe.id))
        #expect(store.state.cookbook.isSaved(recipe.id))
        // Removing from the list leaves an Undo trail.
        #expect(store.state.shoppingToast?.action?.title == "Undo")
    }

    @Test("Rows tick into Got it; Done shopping clears them with Undo")
    func tickAndDone() {
        let (store, recipes) = makeStore()
        let recipe = savedRecipe(store, from: recipes)
        store.send(.shopping(.openAdd(recipe.id)))
        store.send(.shopping(.confirm))
        store.send(.shopping(.dismissToast))
        store.send(.shopping(.answerAutoAdd(false)))

        let presentation = store.state.shoppingPresentation
        #expect(!presentation.isEmpty)
        #expect(presentation.gotIt.isEmpty)
        #expect(!presentation.canFinishShopping)

        let key = presentation.groups[0].rows[0].purchaseKey
        store.send(.shopping(.toggleRow(key)))
        let afterTick = store.state.shoppingPresentation
        #expect(afterTick.gotIt.count == 1)
        #expect(afterTick.gotItTitle == "Got it · 1")
        #expect(afterTick.canFinishShopping)

        store.send(.shopping(.doneShopping))
        #expect(store.state.shoppingPresentation.gotIt.isEmpty)
        #expect(store.state.shoppingToast?.action?.title == "Undo")

        store.send(.shopping(.undo))
        #expect(store.state.shoppingPresentation.gotIt.count == 1)
    }

    @Test("A chip ✕ removes the recipe with Undo; Undo returns it")
    func chipRemoveUndo() {
        let (store, recipes) = makeStore()
        let recipe = savedRecipe(store, from: recipes)
        store.send(.shopping(.openAdd(recipe.id)))
        store.send(.shopping(.confirm))

        #expect(store.state.shoppingPresentation.recipes.map(\.recipeID) == [recipe.id])
        store.send(.shopping(.removeRecipe(recipe.id)))
        #expect(!store.state.shoppingList.contains(recipe.id))
        #expect(store.state.shoppingToast?.action?.title == "Undo")

        store.send(.shopping(.undo))
        #expect(store.state.shoppingList.contains(recipe.id))
    }

    @Test("The list door: openList shows it, closeList returns to the cookbook")
    func listDoor() {
        let (store, recipes) = makeStore()
        let recipe = savedRecipe(store, from: recipes)
        store.send(.shopping(.openAdd(recipe.id)))
        store.send(.shopping(.confirm))

        store.send(.shopping(.openList))
        #expect(store.state.showsShoppingList)
        store.send(.shopping(.closeList))
        #expect(!store.state.showsShoppingList)
    }

    @Test("The free plan sees the invitation; See plans grows into the paywall")
    func freeInvitationToPaywall() {
        let (store, recipes) = makeStore()
        store.send(.entitlementChanged(.free))
        let recipe = recipes[0]
        store.send(.saveRecipe(recipe.id))

        // Add to list on free opens the invitation, not the sheet.
        store.send(.shopping(.openAdd(recipe.id)))
        #expect(store.state.shoppingSheet == nil)
        #expect(store.state.showsShoppingInvitation)
        #expect(store.state.shoppingEntryIsPresented)

        store.send(.shopping(.seePlans(DebugSeeds.PremiumSeeds.plans)))
        #expect(store.state.paywall != nil)
        #expect(!store.state.showsShoppingInvitation)
        #expect(store.state.shoppingEntryIsPresented)

        store.send(.paywall(.close))
        store.send(.shopping(.dismissInvitation))
        #expect(!store.state.shoppingEntryIsPresented)

        // The list button on free with an empty list lands on the same sheet.
        store.send(.shopping(.openList))
        #expect(store.state.showsShoppingInvitation)
        #expect(!store.state.showsShoppingList)
        store.send(.shopping(.dismissInvitation))
    }

    @Test("Ticks and the switch survive a relaunch via the snapshot")
    func persistsAcrossLaunches() throws {
        let (store, recipes) = makeStore()
        store.send(.entitlementChanged(.premium))
        store.send(.shopping(.setAutoAdd(true)))
        let recipe = savedRecipe(store, from: recipes)
        store.send(.shopping(.openAdd(recipe.id)))
        store.send(.shopping(.confirm))
        store.send(.shopping(.toggleRow(
            store.state.shoppingPresentation.groups[0].rows[0].purchaseKey
        )))

        let snapshot = store.state.userSnapshot
        let relaunched = KartaStore(
            state: KartaState(snapshot: snapshot),
            recipes: recipes,
            clock: FixedClock()
        )
        #expect(relaunched.state.shoppingList.contains(recipe.id))
        #expect(relaunched.state.addRecipesAsSaved)
        #expect(relaunched.state.shoppingPresentation.gotIt.count == 1)
    }

    @Test("Downgrading keeps the list usable and drops the switch")
    func downgradeKeepsList() {
        let (store, recipes) = makeStore()
        let recipe = savedRecipe(store, from: recipes)
        store.send(.shopping(.setAutoAdd(true)))
        store.send(.shopping(.openAdd(recipe.id)))
        store.send(.shopping(.confirm))

        store.send(.entitlementChanged(.free))
        #expect(!store.state.addRecipesAsSaved)
        #expect(store.state.shoppingList.contains(recipe.id))
        #expect(!store.state.shoppingPresentation.showsAutoAddSwitch)

        // The retained list still opens; the tick still works.
        store.send(.shopping(.openList))
        #expect(store.state.showsShoppingList)
        let key = store.state.shoppingPresentation.groups[0].rows[0].purchaseKey
        store.send(.shopping(.toggleRow(key)))
        #expect(store.state.shoppingPresentation.gotIt.count == 1)
    }

    @Test("Select → pick cards → Remove drops them all and Undo restores")
    func selectionRemoveUndo() {
        let (store, recipes) = makeStore()
        store.send(.entitlementChanged(.premium))
        for recipe in recipes.prefix(2) {
            store.send(.saveRecipe(recipe.id))
        }
        var presentation = store.cookbookPresentation(recipes: recipes)
        #expect(presentation.canSelect)
        #expect(!presentation.isSelecting)

        store.send(.beginCookbookSelection)
        presentation = store.cookbookPresentation(recipes: recipes)
        #expect(presentation.isSelecting)
        #expect(presentation.selectionBarText == "Select recipes")

        for recipe in recipes.prefix(2) {
            store.send(.toggleCookbookSelection(recipe.id))
        }
        presentation = store.cookbookPresentation(recipes: recipes)
        #expect(presentation.selectedRecipeIDs.count == 2)
        #expect(presentation.selectionBarText == "2 selected")
        #expect(presentation.canRemoveSelection)

        store.send(.removeCookbookSelection)
        #expect(!store.state.isSelectingCookbook)
        for recipe in recipes.prefix(2) {
            #expect(!store.cookbook.isSaved(recipe.id))
        }
        #expect(store.unsaveToast(recipes: recipes)?.title == "2 recipes removed")

        store.send(.undoUnsave)
        for recipe in recipes.prefix(2) {
            #expect(store.cookbook.isSaved(recipe.id))
        }
    }

    @Test("Done keeps the switch position and exits selection with no removal")
    func selectionDone() {
        let (store, recipes) = makeStore()
        store.send(.entitlementChanged(.premium))
        let recipe = savedRecipe(store, from: recipes)

        store.send(.beginCookbookSelection)
        store.send(.toggleCookbookSelection(recipe.id))
        store.send(.endCookbookSelection)

        #expect(!store.state.isSelectingCookbook)
        #expect(store.state.selectedCookbookRecipeIDs.isEmpty)
        #expect(store.cookbook.isSaved(recipe.id))
    }
}
