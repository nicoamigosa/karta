import Foundation
import Testing
import KartaCore

@Suite("Leftovers contract")
struct LeftoversContractTests {
    @Test("Each pantry category is excluded by purchase key despite different ingredient names", arguments: [
        "kosher-salt", "black-pepper", "extra-virgin-olive-oil", "all-purpose-flour", "granulated-sugar", "active-dry-yeast",
    ])
    func pantryDoesNotMatch(key: String) throws {
        let sourceIngredient = try Ingredient(id: "source", name: "One name", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: key, aisle: .pantry)
        let targetIngredient = try Ingredient(id: "target", name: "Another name", structuredQuantity: .measured(IngredientAmount("1")), purchaseKey: key, aisle: .pantry)
        let source = leftoverRecipe("source", ingredients: [sourceIngredient])
        let target = leftoverRecipe("target", ingredients: [targetIngredient])
        #expect(LeftoversQuery.suggestions(recipes: [source, target], cooks: [CookEntry(recipeID: source.id, date: leftoverNow)],
            recentWindow: PurchasePolicy.leftoversWindow, clock: LeftoverClock(), filters: FeedFilters()).isEmpty)
    }

    @Test("Shared purchase keys retain recipe order and all explicit sources, newest first")
    func reuseSources() throws {
        func ingredient(_ id: String, _ key: String) throws -> Ingredient {
            try Ingredient(id: id, name: id, structuredQuantity: .measured(IngredientAmount("1")),
                           purchaseKey: key, aisle: .produce)
        }
        let first = try leftoverRecipe("first", ingredients: [ingredient("yellow onion", "onion"), ingredient("salt", "salt")])
        let second = try leftoverRecipe("second", ingredients: [ingredient("sweet onion", "onion")])
        let target = try leftoverRecipe("target", ingredients: [ingredient("sea salt", "salt"), ingredient("onion diced", "onion")])
        let reuse = PurchasePolicy.reusedIngredients(in: target, recipes: [first, second, target], cooks: [
            CookEntry(recipeID: "first", date: leftoverNow.addingTimeInterval(-100)),
            CookEntry(recipeID: "second", date: leftoverNow),
            CookEntry(recipeID: "first", date: leftoverNow.addingTimeInterval(-200)),
        ], now: leftoverNow)
        #expect(reuse.map(\.ingredient.id) == ["onion diced"])
        #expect(reuse[0].sources.map(\.recipeID) == ["second", "first"])
        #expect(PurchasePolicy.leftovers(recipes: [first, second], cooks: [
            CookEntry(recipeID: "first", date: leftoverNow)
        ], now: leftoverNow) == ["onion": "first"])
    }

    @Test("Inferred cooks cannot supply leftovers and cannot be offered inside the window")
    func inferredExclusion() {
        let recipes = [leftoverRecipe("source"), leftoverRecipe("inferred"), leftoverRecipe("offered")]
        let result = LeftoversQuery.suggestions(
            recipes: recipes,
            cooks: [CookEntry(recipeID: "source", date: leftoverNow),
                    CookEntry(recipeID: "inferred", date: leftoverNow, wasInferred: true)],
            recentWindow: PurchasePolicy.leftoversWindow, clock: LeftoverClock(), filters: FeedFilters())
        #expect(result.map(\.id) == ["offered"])
    }
}

struct LeftoverClock: KartaClock { var now: Date { leftoverNow } }
let leftoverNow = Date(timeIntervalSince1970: 1_800_000_000)
func leftoverRecipe(_ id: String, ingredients: [Ingredient]? = nil, servings: Int = 4) -> Recipe {
    Recipe(id: id, name: id, heroPhoto: .local("test"), totalMinutes: 10, difficulty: .easy,
           servings: servings, primaryCourse: .dinner,
           ingredients: ingredients ?? [Ingredient(name: "onion", quantity: "1")],
           steps: ["Cook"], allergenReview: .reviewed([]))
}
