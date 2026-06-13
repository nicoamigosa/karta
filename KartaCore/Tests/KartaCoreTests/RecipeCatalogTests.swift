import Testing
import Foundation
@testable import KartaCore

@Suite("Seed recipe catalog")
struct RecipeCatalogTests {

    /// Issue #1 acceptance: the bundled seed catalog decodes into a non-empty
    /// set of recipes, each usable by a feed card and the cooking flow — so
    /// every recipe must carry at least one ingredient and at least one step.
    @Test("The seed catalog decodes into valid, fully-populated recipes")
    func seedCatalogIsValid() throws {
        let recipes = try RecipeCatalog.seed()

        #expect(!recipes.isEmpty)

        for recipe in recipes {
            #expect(!recipe.ingredients.isEmpty, "\(recipe.id) has no ingredients")
            #expect(!recipe.steps.isEmpty, "\(recipe.id) has no steps")
        }
    }

    /// Recipe ids identify recipes across saved/seen/cooked history, so a
    /// duplicate id in the seed would silently corrupt that bookkeeping.
    @Test("Seed recipe ids are unique")
    func seedIdsAreUnique() throws {
        let recipes = try RecipeCatalog.seed()
        let ids = Set(recipes.map(\.id))
        #expect(ids.count == recipes.count)
    }
}
