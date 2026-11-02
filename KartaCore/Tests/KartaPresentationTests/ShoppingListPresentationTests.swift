import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Shopping list presentation")
struct ShoppingListPresentationTests {
    struct Clock: KartaClock { let now: Date }
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("The add sheet defaults exclude pantry basics and explicit recent leftovers")
    @MainActor
    func sheetDefaults() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let tortilla = try #require(recipes.first { $0.id == "spanish-tortilla" })
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: [tortilla.id]),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            cookHistory: [CookEntry(recipeID: "lentil-stew", date: now)],
            safetyProfile: SafetyProfile(intolerances: [])), recipes: recipes, clock: Clock(now: now))
        store.send(.entitlementChanged(.premium))
        store.send(.shopping(.openAdd(tortilla.id)))
        let sheet = try #require(store.state.shoppingSheet)
        #expect(sheet.rows.map(\.ingredient.purchaseKey) == ["yukon-gold-potato", "large-egg", "yellow-onion", "extra-virgin-olive-oil", "kosher-salt"])
        #expect(sheet.selectedKeys == ["large-egg"])
        #expect(sheet.rows.first?.hint == "Left from your Lentil Stew")
        #expect(sheet.buttonTitle == "Add 1 to list")
        store.send(.shopping(.dismissSheet))
        #expect(store.state.shoppingList.entries.isEmpty)
    }
    @Test("Confirm, tick, clear and Undo preserve the recipe and bought rows")
    @MainActor
    func shoppingLifecycle() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(recipes)
        store.send(.shopping(.openAdd("spanish-tortilla")))
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingToast?.title == "Added to your list")
        #expect(store.state.shoppingToast?.secondLine == "3 items · Spanish Tortilla")
        #expect(store.state.shoppingPresentation.badge == 3)
        #expect(store.state.shoppingPresentation.countLabel == "1 recipe · 3 to buy")
        for key in ["yukon-gold-potato", "large-egg", "yellow-onion"] { store.send(.shopping(.toggleRow(key))) }
        #expect(store.state.shoppingPresentation.gotIt.count == 3)
        #expect(store.state.shoppingPresentation.badge == nil)
        #expect(store.state.shoppingPresentation.countLabel == "1 recipe · 0 left to buy")
        store.send(.shopping(.toggleRow("yellow-onion")))
        #expect(store.state.shoppingPresentation.badge == 1)
        store.send(.shopping(.toggleRow("yellow-onion")))
        store.send(.shopping(.doneShopping))
        #expect(store.state.shoppingPresentation.isEmpty)
        #expect(store.state.shoppingToast?.title == "3 items cleared")
        store.send(.shopping(.undo))
        #expect(store.state.shoppingPresentation.gotIt.count == 3)
        #expect(store.state.shoppingList.entries.map(\.recipeID) == ["spanish-tortilla"])
    }


    @Test("The first add asks once after its toast, then saving automatically offers Review")
    @MainActor
    func autoAddAndReverse() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let tortilla = try #require(recipes.first { $0.id == "spanish-tortilla" })
        let store = makeStore(recipes)
        #expect(!store.state.addRecipesAsSaved)
        #expect(store.reversePresentation(for: tortilla)?.pillTitle == "Add to list")
        store.send(.shopping(.openAdd(tortilla.id)))
        store.send(.shopping(.confirm))
        #expect(store.reversePresentation(for: tortilla)?.pillTitle == "On your list")
        #expect(!store.state.showsAutoAddQuestion)
        store.send(.shopping(.dismissToast))
        #expect(store.state.showsAutoAddQuestion)
        #expect(store.state.hasAskedAutoAdd)
        store.send(.shopping(.answerAutoAdd(true)))
        #expect(store.state.addRecipesAsSaved)
        store.send(.shopping(.removeRecipe(tortilla.id)))
        store.send(.unsaveRecipe(tortilla.id))
        #expect(store.reversePresentation(for: tortilla)?.pillTitle == "Save")
        store.send(.saveRecipe(tortilla.id))
        #expect(store.state.shoppingToast?.title == "Saved · 3 items on your list")
        #expect(store.state.shoppingToast?.secondLine == "Yukon Gold potatoes, Large eggs and Yellow onion. You have the rest.")
        #expect(store.state.shoppingToast?.action == .review(tortilla.id))
        store.send(.shopping(.review(tortilla.id)))
        #expect(store.state.shoppingSheet?.buttonTitle == "Update list")
        #expect(store.state.shoppingSheet?.selectedKeys.count == 3)
        store.send(.shopping(.dismissSheet))
        store.send(.shopping(.dismissToast))
        #expect(!store.state.showsAutoAddQuestion)
        store.send(.unsaveRecipe(tortilla.id))
        #expect(store.state.shoppingList.contains(tortilla.id))
    }

    @Test("Free invitations grow into the paywall; downgrade retains a usable list")
    @MainActor
    func downgrade() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(recipes)
        store.send(.shopping(.openAdd("spanish-tortilla")))
        store.send(.shopping(.confirm))
        store.send(.shopping(.setAutoAdd(true)))
        store.send(.entitlementChanged(.free))
        #expect(!store.state.addRecipesAsSaved)
        #expect(store.state.shoppingPresentation.badge == nil)
        #expect(!store.state.shoppingPresentation.showsAutoAddSwitch)
        store.send(.shopping(.openList))
        #expect(store.state.showsShoppingList)
        store.send(.shopping(.toggleRow("large-egg")))
        store.send(.shopping(.doneShopping))
        #expect(store.state.shoppingList.rows.count == 2)
        store.send(.shopping(.openAdd("lentil-stew")))
        #expect(store.state.showsShoppingInvitation)
        #expect(store.state.shoppingSheet == nil)
        store.send(.shopping(.seePlans([])))
        #expect(store.state.paywall?.entry == .shoppingList)
        #expect(store.state.shoppingEntryIsPresented)
        store.send(.paywall(.close))
        #expect(!store.state.shoppingEntryIsPresented)
        store.send(.shopping(.removeRecipe("spanish-tortilla")))
        store.send(.shopping(.openList))
        #expect(store.state.showsShoppingInvitation)
    }

    @Test("Snapshots retain shares, ticks and both settings when a recipe leaves the catalogue")
    @MainActor
    func persistence() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(recipes)
        store.send(.shopping(.openAdd("spanish-tortilla")))
        store.send(.shopping(.confirm))
        store.send(.shopping(.toggleRow("large-egg")))
        store.send(.shopping(.setAutoAdd(true)))
        let snapshot = store.state.userSnapshot
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded(), now: now.timeIntervalSince1970, catalog: []).snapshot)
        #expect(restored == snapshot)
        #expect(restored.shoppingList.rows.map(\.name) == ["Yukon Gold potatoes", "Yellow onion", "Large eggs"])
        let relaunched = KartaStore(state: KartaState(snapshot: restored), recipes: [], clock: Clock(now: now))
        #expect(relaunched.state.shoppingPresentation.gotIt.map(\.purchaseKey) == ["large-egg"])
        #expect(relaunched.state.addRecipesAsSaved)
        #expect(relaunched.state.hasAskedAutoAdd)
        #expect(relaunched.state.shoppingToast == nil)
        relaunched.send(.entitlementChanged(.free))
        #expect(!relaunched.state.addRecipesAsSaved)
        relaunched.send(.shopping(.doneShopping))
        #expect(relaunched.state.shoppingList.rows.count == 2)
        let old = Data(#"{"version":1,"profile":{"intolerances":[],"householdSize":2}}"#.utf8)
        let legacy = try #require(UserSnapshot.restore(from: old).snapshot)
        #expect(legacy.shoppingList.entries.isEmpty)
        #expect(!legacy.addRecipesAsSaved)
        #expect(!legacy.hasAskedAutoAdd)
    }

    @Test("An add draft cannot add a recipe removed from the Cookbook while the sheet was open")
    @MainActor
    func staleSheet() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(recipes)
        store.send(.shopping(.openAdd("spanish-tortilla")))
        store.send(.unsaveRecipe("spanish-tortilla"))
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingList.entries.isEmpty)
        #expect(store.state.shoppingToast == nil)
    }

    @Test("Review replaces the current shares and supports Undo even when nothing remains")
    @MainActor
    func reviewUpdate() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(recipes)
        store.send(.shopping(.openAdd("spanish-tortilla")))
        store.send(.shopping(.confirm))
        store.send(.shopping(.toggleRow("large-egg")))
        let before = store.state.shoppingList
        store.send(.shopping(.review("spanish-tortilla")))
        store.send(.shopping(.toggleChoice("large-egg")))
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingList.rows.map(\.purchaseKey) == ["yukon-gold-potato", "yellow-onion"])
        #expect(store.state.shoppingToast?.action == .undo)
        store.send(.shopping(.undo))
        #expect(store.state.shoppingList == before)
        store.send(.shopping(.review("spanish-tortilla")))
        for key in ["yukon-gold-potato", "yellow-onion", "large-egg"] { store.send(.shopping(.toggleChoice(key))) }
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingPresentation.isEmpty)
        #expect(store.state.shoppingToast?.title == "Removed from your list")
        store.send(.shopping(.undo))
        #expect(store.state.shoppingList == before)
    }

    @Test("Every optional ingredient stays off the sheet and list for every intolerance", arguments: Allergen.allCases)
    @MainActor
    func optionalSafety(allergen: Allergen) throws {
        let required = try Ingredient(id: "onion", name: "Yellow onion", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "yellow-onion", aisle: .produce)
        let optional = try Ingredient(id: "optional", name: "Optional garnish", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "garnish", aisle: .produce, isOptional: true, allergens: [allergen])
        let safeOptional = try Ingredient(id: "basil", name: "Basil", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "basil", aisle: .produce, isOptional: true)
        let recipe = Recipe(id: "safe", name: "Safe", heroPhoto: .local("test"), totalMinutes: 10, difficulty: .easy,
            servings: 2, primaryCourse: .dinner, ingredients: [required, optional, safeOptional], steps: ["Cook"], allergenReview: .reviewed([]))
        let store = KartaStore(state: KartaState(cookbook: Cookbook(savedIDs: [recipe.id]),
            onboarding: OnboardingState(intoleranceAnswer: .answered([allergen]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [allergen])), recipes: [recipe], clock: Clock(now: now))
        store.send(.entitlementChanged(.premium))
        store.send(.shopping(.openAdd(recipe.id)))
        #expect(store.state.shoppingSheet?.rows.map(\.ingredient.id) == ["onion"])
        store.send(.shopping(.toggleChoice("garnish")))
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingList.rows.map(\.purchaseKey) == ["yellow-onion"])
        store.send(.entitlementChanged(.free))
        #expect(store.reversePresentation(for: recipe)?.ingredients.map(\.id) == ["onion", "basil"])
    }

    @Test("Nothing to add is disabled, and an automatic save with all ingredients left over adds nothing")
    @MainActor
    func nothingToBuy() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore(recipes)
        store.send(.recordCook(CookEntry(recipeID: "spanish-tortilla", date: now)))
        store.send(.shopping(.openAdd("spanish-tortilla")))
        #expect(store.state.shoppingSheet?.buttonTitle == "Nothing to add")
        #expect(store.state.shoppingSheet?.canConfirm == false)
        store.send(.shopping(.confirm))
        #expect(store.state.shoppingList.entries.isEmpty)
        store.send(.shopping(.dismissSheet))
        store.send(.shopping(.setAutoAdd(true)))
        store.send(.unsaveRecipe("spanish-tortilla"))
        store.send(.saveRecipe("spanish-tortilla"))
        #expect(store.state.shoppingToast?.title == "Saved · nothing to buy")
        #expect(store.state.shoppingToast?.action == nil)
        #expect(store.state.shoppingList.entries.isEmpty)
        #expect(!store.state.hasAskedAutoAdd)
    }

    @Test("Automatic adding respects the same allergen-review boundary as the manual sheet")
    @MainActor
    func unreviewedAutomaticSave() throws {
        let ingredient = try Ingredient(id: "onion", name: "Yellow onion", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "yellow-onion", aisle: .produce)
        let recipe = Recipe(id: "unreviewed", name: "Unreviewed", heroPhoto: .local("test"), totalMinutes: 10,
            difficulty: .easy, servings: 2, primaryCourse: .dinner, ingredients: [ingredient], steps: ["Cook"], allergenReview: .unreviewed)
        let store = makeStore([recipe])
        store.send(.shopping(.setAutoAdd(true)))
        store.send(.shopping(.openAdd(recipe.id)))
        #expect(store.state.shoppingSheet == nil)
        store.send(.unsaveRecipe(recipe.id))
        store.send(.saveRecipe(recipe.id))
        #expect(store.state.shoppingList.entries.isEmpty)
        #expect(store.state.shoppingToast == nil)
    }
    @MainActor
    func makeStore(_ recipes: [Recipe]) -> KartaStore {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: recipes.map(\.id)),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])), recipes: recipes, clock: Clock(now: now))
        store.send(.entitlementChanged(.premium))
        return store
    }

}
