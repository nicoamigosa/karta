import Foundation
import Testing
import KartaCore

@Suite("Ingredient quantities")
struct IngredientQuantityTests {
    @Test("The reverse renders a measured quantity with its approximate weight")
    func reverseQuantity() throws {
        let quantity = IngredientQuantity.measured(
            try IngredientAmount("4"), unit: .medium, approximateWeight: "about 1 1/2 lb"
        )
        #expect(quantity.text == "4 medium (about 1 1/2 lb)")
    }

    @Test("Quantities add within a unit without converting between units")
    func totals() throws {
        let quantities: [IngredientQuantity] = [
            .measured(try IngredientAmount("1"), unit: .medium),
            .measured(try IngredientAmount("1"), unit: .medium),
        ]
        #expect(try IngredientQuantity.total(quantities) == "2 medium")
    }

    @Test("Totals retain a form only when every share agrees and drop approximate weights")
    func totalForms() throws {
        let half = try IngredientAmount("1/2")
        #expect(try IngredientQuantity.total([
            .measured(half, unit: .cup, form: .packed, approximateWeight: "about 2 oz"),
            .measured(half, unit: .cup, form: .packed),
        ]) == "1 cup packed")
    }

    @Test("Measured parts precede unmeasured wording even when the wording arrives first")
    func measuredFirst() throws {
        #expect(try IngredientQuantity.total([
            .unmeasured(.forFrying), .measured(try IngredientAmount("1/2"), unit: .cup),
        ]) == "1/2 cup + as needed for frying")
    }

    @Test("Identical unmeasured wordings appear once")
    func unmeasuredOnce() throws {
        #expect(try IngredientQuantity.total([
            .unmeasured(.toTaste), .unmeasured(.toTaste), .unmeasured(.toTaste),
        ]) == "to taste")
    }

    @Test("Different units keep their input order and never convert")
    func distinctUnits() throws {
        #expect(try IngredientQuantity.total([
            .measured(try IngredientAmount("1"), unit: .tbsp),
            .measured(try IngredientAmount("1/4"), unit: .cup),
        ]) == "1 tbsp + 1/4 cup")
        #expect(try IngredientQuantity.total([
            .unmeasured(.toTaste), .measured(try IngredientAmount("1"), unit: .lb),
            .measured(try IngredientAmount("16"), unit: .oz), .unmeasured(.pinch),
            .measured(try IngredientAmount("1"), unit: .lb), .unmeasured(.toTaste),
        ]) == "2 lb + 16 oz + to taste + a pinch")
    }

    @Test("Fractions add exactly and render as reduced mixed numbers")
    func exactFractions() throws {
        #expect(try IngredientQuantity.total([
            .measured(try IngredientAmount("1/3"), unit: .cup),
            .measured(try IngredientAmount("1/6"), unit: .cup),
        ]) == "1/2 cup")
        #expect(try IngredientQuantity.total([
            .measured(try IngredientAmount("1 1/2"), unit: .cup),
            .measured(try IngredientAmount("3/4"), unit: .cup),
        ]) == "2 1/4 cups")
        #expect(try IngredientAmount("2/6").text == "1/3")
        #expect(try IngredientAmount("4/3").text == "1 1/3")
    }

    @Test("A form is dropped if any share differs or has no form")
    func differingForms() throws {
        let half = try IngredientAmount("1/2")
        #expect(try IngredientQuantity.total([
            .measured(half, unit: .cup, form: .packed), .measured(half, unit: .cup),
        ]) == "1 cup")
        #expect(try IngredientQuantity.total([
            .measured(half, unit: .cup, form: .grated),
            .measured(half, unit: .cup, form: .shaved),
        ]) == "1 cup")
        #expect(try IngredientQuantity.total([
            .measured(half, unit: .cup, form: .packed), .unmeasured(.toTaste),
        ]) == "1/2 cup + to taste")
    }

    @Test("Bare counts add together and remain separate from a piece unit")
    func bareCounts() throws {
        let one = try IngredientAmount("1")
        #expect(try IngredientQuantity.total([
            .measured(one), .measured(one, unit: .piece), .measured(one),
        ]) == "2 + 1 piece")
        #expect(try IngredientQuantity.total([]) == "")
    }

    @Test("A total exceeding integer capacity fails instead of wrapping")
    func overflow() throws {
        let maximum = try IngredientAmount(String(Int.max))
        #expect(throws: RecipeDecodingError.self) { try maximum.adding(IngredientAmount("1")) }
    }

    @Test("The reverse renders every closed unit with American plurals", arguments: [
        ("cup", "2 cups"), ("tbsp", "2 tbsp"), ("tsp", "2 tsp"), ("oz", "2 oz"), ("lb", "2 lb"),
        ("fl oz", "2 fl oz"), ("small", "2 small"), ("medium", "2 medium"), ("large", "2 large"),
        ("clove", "2 cloves"), ("head", "2 heads"), ("slice", "2 slices"), ("link", "2 links"),
        ("sprig", "2 sprigs"), ("can", "2 cans"), ("piece", "2 pieces"),
    ])
    func unitText(unit: String, expected: String) throws {
        let json = try JSONSerialization.data(withJSONObject: ["amount": "2", "unit": unit])
        let quantity = try JSONDecoder().decode(IngredientQuantity.self, from: json)
        #expect(quantity.text == expected)
        #expect(try JSONDecoder().decode(IngredientQuantity.self, from: JSONEncoder().encode(quantity)) == quantity)
    }

    @Test("The reverse renders every closed unmeasured wording", arguments: [
        "to taste", "as needed for frying", "a pinch", "a few sprigs",
    ])
    func unmeasuredText(wording: String) throws {
        let json = try JSONSerialization.data(withJSONObject: ["unmeasured": wording])
        let quantity = try JSONDecoder().decode(IngredientQuantity.self, from: json)
        #expect(quantity.text == wording)
        #expect(try JSONDecoder().decode(IngredientQuantity.self, from: JSONEncoder().encode(quantity)) == quantity)
    }

    @Test("Pasillos follow the shopping order")
    func aisleOrder() {
        #expect(Aisle.allCases.map(\.rawValue) == [
            "produce", "meat-and-fish", "dairy-and-eggs", "bakery", "pantry", "spices", "frozen", "other",
        ])
        #expect([Aisle.other, .pantry, .produce, .bakery, .frozen, .meatAndFish, .spices, .dairyAndEggs].sorted() == Aisle.allCases)
    }
}
