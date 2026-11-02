import Foundation
import Testing
import KartaCore

@Suite("Shopping list")
struct ShoppingListTests {
    func recipe(_ id: String, name: String? = nil, ingredients: [Ingredient]? = nil) throws -> Recipe {
        Recipe(id: id, name: name ?? id, heroPhoto: .local("test"), totalMinutes: 10,
               difficulty: .easy, servings: 2, primaryCourse: .dinner,
               ingredients: try ingredients ?? [Ingredient(
                id: "onion", name: "Yellow onion", structuredQuantity: .measured(IngredientAmount("1"), unit: .medium),
                purchaseKey: "yellow-onion", aisle: .produce)],
               steps: ["s"], allergenReview: .reviewed([]))
    }

    @Test("Two recipes share one Produce row with their summed quantities")
    func sharedRow() throws {
        var list = ShoppingList()
        list.update(recipe: try recipe("a"), purchaseKeys: ["yellow-onion"], intolerances: [])
        list.update(recipe: try recipe("b"), purchaseKeys: ["yellow-onion"], intolerances: [])
        let row = try #require(list.rows.first)
        #expect(row.name == "Yellow onion")
        #expect(row.total == "2 medium")
        #expect(row.recipeNames == "a · b")
        #expect(row.aisle == .produce)
        #expect(list.rows.count == 1)
    }
    @Test("Leftovers compares purchase keys and excludes pantry basics and optional shares")
    func leftoverPurchaseKeys() throws {
        let onion = try Ingredient(id: "onion", name: "Different onion wording", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "yellow-onion", aisle: .produce)
        let salt = try Ingredient(id: "salt", name: "Salt", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "kosher-salt", aisle: .spices)
        let optional = try Ingredient(id: "basil", name: "Basil", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: "basil", aisle: .produce, isOptional: true)
        let cooked = try recipe("cooked", ingredients: [onion, salt, optional])
        let reuse = try recipe("reuse")
        let basic = try recipe("basic", ingredients: [salt])
        let garnish = try recipe("garnish", ingredients: [optional])
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = LeftoversQuery.suggestions(recipes: [cooked, basic, garnish, reuse],
            cooks: [CookEntry(recipeID: "cooked", date: now)], recentWindow: PurchasePolicy.leftoversWindow,
            clock: Clock(now: now), filters: FeedFilters())
        #expect(result.map(\.id) == ["reuse"])
    }

    @Test("Aisles have fixed order and removing one recipe subtracts only its shares")
    func orderingAndRemoval() throws {
        let ingredients = try Aisle.allCases.reversed().map { aisle in
            Ingredient(id: aisle.rawValue, name: aisle.rawValue,
                       structuredQuantity: .measured(try IngredientAmount("1")),
                       purchaseKey: aisle.rawValue, aisle: aisle)
        }
        let first = try recipe("first", ingredients: ingredients)
        let second = try recipe("second", ingredients: [Ingredient(
            id: "another", name: "Second name", structuredQuantity: .measured(IngredientAmount("2")),
            purchaseKey: "produce", aisle: .produce)])
        var list = ShoppingList()
        list.update(recipe: first, purchaseKeys: Set(ingredients.map(\.purchaseKey)), intolerances: [])
        list.update(recipe: second, purchaseKeys: ["produce"], intolerances: [])
        #expect(list.rows.map(\.aisle) == [.produce, .meatAndFish, .dairyAndEggs, .bakery, .pantry, .spices, .frozen, .other])
        #expect(list.rows.first?.name == "produce")
        #expect(list.rows.first?.total == "3")
        list.toggle("produce")
        let before = list
        let removal = list.removeRecipe("first")
        let receipt = try #require(removal)
        #expect(list.rows.count == 1)
        #expect(list.rows.first?.name == "Second name")
        #expect(list.rows.first?.total == "2")
        #expect(list.rows.first?.recipeNames == "second")
        #expect(list.rows.first?.isTicked == true)
        list.undo(receipt)
        #expect(list == before)
    }

    @Test("Only explicit cooks inside the inclusive seven-day window supply purchase keys", arguments: [
        (-604_801.0, false, false), (-604_800, false, true), (0, false, true),
        (1, false, false), (0, true, false),
    ])
    func leftoversWindow(offset: Double, inferred: Bool, supplies: Bool) throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let names = PurchasePolicy.leftovers(recipes: [try recipe("cooked")],
            cooks: [CookEntry(recipeID: "cooked", date: now.addingTimeInterval(offset), wasInferred: inferred)], now: now)
        #expect(names["yellow-onion"] == (supplies ? "cooked" : nil))
    }

    @Test("An overflowing total keeps exact shares and still omits approximate weights")
    func overflowingTotal() throws {
        let ingredient = try Ingredient(id: "oil", name: "Oil", structuredQuantity: .measured(
            IngredientAmount("9223372036854775807"), approximateWeight: "about 1 lb"), purchaseKey: "oil", aisle: .pantry)
        var list = ShoppingList()
        list.update(recipe: try recipe("a", ingredients: [ingredient]), purchaseKeys: ["oil"], intolerances: [])
        list.update(recipe: try recipe("b", ingredients: [ingredient]), purchaseKeys: ["oil"], intolerances: [])
        #expect(list.rows.first?.total == "9223372036854775807 + 9223372036854775807")
    }
    struct Clock: KartaClock { let now: Date }

}
