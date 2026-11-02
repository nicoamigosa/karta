import Testing
import KartaCore
import KartaPresentation

@Suite("Seed quantities")
struct SeedQuantityTests {
    // Captured from the editor-approved seed before the ADR 0017 migration.
    @Test("Every generated reverse quantity preserves the original seed text")
    func reverseTextIsUnchanged() throws {
        let expected: [String: [String]] = [
            "spanish-tortilla": ["4 medium (about 1 1/2 lb)", "5", "1 medium", "as needed for frying", "to taste"],
            "quick-chicken-curry": ["1 lb", "3/4 cup", "2 tbsp", "1 medium", "2 cups cooked", "2 tbsp"],
            "caesar-salad": ["1 head", "2 slices", "1/2 cup shaved", "1/4 cup"],
            "pesto-pasta": ["12 oz", "1 cup packed", "1/3 cup grated", "1/4 cup", "1/4 cup", "to taste"],
            "lentil-stew": ["1 1/2 cups", "1 link (about 4 oz)", "2 medium", "2 medium", "1 medium", "1 tsp"],
            "baked-salmon-with-lemon": ["2 (about 6 oz each)", "1", "a few sprigs", "2 tbsp", "to taste"],
            "banana-pancakes": ["2", "2", "1 1/4 cups", "3/4 cup", "1 tsp"],
            "vegetable-noodle-stir-fry": ["8 oz", "1 head", "1", "1", "1/4 cup"],
        ]
        let recipes = try SeedResourceAdapter().loadRecipes()
        #expect(Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0.ingredients.map(\.quantity)) }) == expected)
    }
}
