import Testing
@testable import KartaCore

/// The personal cookbook and the free-tier save cap, independent of UI.
@Suite("Cookbook — saving")
struct CookbookSavingTests {

    private func recipe(_ id: String, review: AllergenReview) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "",
            totalMinutes: 10,
            difficulty: .easy,
            servings: 4,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["s"],
            allergenReview: review
        )
    }

    @Test("Saving a recipe adds it to the cookbook")
    func saveAddsRecipe() {
        var cookbook = Cookbook()

        #expect(cookbook.save("r1") == .saved)
        #expect(cookbook.isSaved("r1"))
        #expect(cookbook.savedIDs == ["r1"])
    }

    @Test("Saving an already-saved recipe is idempotent")
    func saveIsIdempotent() {
        var cookbook = Cookbook()
        cookbook.save("r1")

        #expect(cookbook.save("r1") == .alreadySaved)
        #expect(cookbook.savedIDs == ["r1"])
    }

    @Test("Restoring duplicate recipe IDs keeps one copy in saved order")
    func restoringDeduplicatesSavedIDs() {
        let cookbook = Cookbook(savedIDs: ["r1", "r2", "r1", "r3", "r2"])

        #expect(cookbook.savedIDs == ["r1", "r2", "r3"])
    }

    @Test("The cap counts distinct restored recipes")
    func restoredDuplicatesDoNotConsumeDistinctRecipeCap() {
        var cookbook = Cookbook(savedIDs: Array(repeating: "r1", count: Cookbook.freeSaveCap))

        #expect(cookbook.save("r2") == .saved)
        #expect(cookbook.savedIDs == ["r1", "r2"])
    }

    @Test("Unsaving removes the recipe")
    func unsaveRemoves() {
        var cookbook = Cookbook()
        cookbook.save("r1")

        cookbook.unsave("r1")
        #expect(cookbook.isSaved("r1") == false)
        #expect(cookbook.savedIDs.isEmpty)
    }

    @Test("Restoring a cookbook omits unreviewed recipes")
    func restoringOmitsUnreviewedRecipes() {
        let cookbook = Cookbook(savedIDs: ["reviewed", "unreviewed"])
        let catalog = [
            recipe("reviewed", review: .reviewed([])),
            recipe("unreviewed", review: .unreviewed),
        ]

        let restored = cookbook.recipes(from: catalog)

        #expect(restored.map(\.id) == ["reviewed"])
    }

    @Test("A profile safety change hides an unsafe save without deleting it")
    func safetyChangeHidesButDoesNotDelete() {
        var cookbook = Cookbook()
        cookbook.save("safe")
        cookbook.save("dairy")
        let catalog = [
            recipe("safe", review: .reviewed([])),
            recipe("dairy", review: .reviewed([.dairy])),
        ]

        let visible = cookbook.recipes(
            from: catalog,
            filters: FeedFilters(intolerances: [.dairy])
        )

        #expect(visible.map(\.id) == ["safe"])
        #expect(cookbook.savedIDs == ["safe", "dairy"])
        #expect(cookbook.isSaved("dairy"))
    }
}

/// The free-tier save cap of 7 — the upgrade-invitation boundary.
@Suite("Cookbook — free-tier cap")
struct CookbookCapTests {

    private func filled(_ count: Int) -> Cookbook {
        var c = Cookbook()
        for i in 0..<count { c.save("r\(i)") }
        return c
    }

    @Test("A negative save cap is rejected")
    func negativeSaveCapIsRejected() async {
        await #expect(processExitsWith: .failure) {
            _ = Cookbook(saveCap: -1)
        }
    }

    @Test("The 8th save is blocked at the cap")
    func eighthSaveBlocked() {
        var cookbook = filled(Cookbook.freeSaveCap) // 7 saved
        #expect(cookbook.savedIDs.count == 7)
        #expect(cookbook.isAtCap)

        #expect(cookbook.save("overflow") == .blockedByCap)
        #expect(cookbook.isSaved("overflow") == false)
        #expect(cookbook.savedIDs.count == 7)
    }

    @Test("Unsaving frees a slot so a new save succeeds")
    func unsaveFreesSlot() {
        var cookbook = filled(Cookbook.freeSaveCap)

        cookbook.unsave("r0")
        #expect(cookbook.isAtCap == false)
        #expect(cookbook.save("overflow") == .saved)
        #expect(cookbook.savedIDs.count == 7)
    }

    @Test("An unlimited cookbook never blocks")
    func unlimitedNeverBlocks() {
        var cookbook = Cookbook(saveCap: nil)
        for i in 0..<50 { #expect(cookbook.save("r\(i)") == .saved) }
        #expect(cookbook.isAtCap == false)
    }

    @Test("Downgrading keeps every premium save and fixes the ceiling at its size")
    func downgradeKeepsPremiumSaves() {
        var cookbook = Cookbook(saveCap: nil)
        for i in 0..<23 { #expect(cookbook.save("r\(i)") == .saved) }

        cookbook.downgradeToFree()

        #expect(cookbook.savedIDs.count == 23)
        #expect(cookbook.saveCap == 23)
        #expect(cookbook.save("overflow") == .blockedByCap)
    }

    @Test("A downgraded cookbook keeps its existing recipes openable")
    func downgradedRecipesRemainOpenable() {
        var cookbook = Cookbook(saveCap: nil)
        for i in 0..<9 { #expect(cookbook.save("r\(i)") == .saved) }
        cookbook.downgradeToFree()
        let catalog = (0..<9).map {
            Recipe(
                id: "r\($0)", name: "r\($0)", heroPhotoURL: "", totalMinutes: 10,
                difficulty: .easy, servings: 4, tags: [], ingredients: [], steps: ["s"],
                allergenReview: .reviewed([])
            )
        }

        #expect(cookbook.recipes(from: catalog).map(\.id) == [
            "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8",
        ])
    }

    @Test("Deleting lowers the ceiling without freeing a slot above seven")
    func deletingLowersCeilingToFreeFloor() {
        var cookbook = Cookbook(saveCap: nil)
        for i in 0..<9 { #expect(cookbook.save("r\(i)") == .saved) }
        cookbook.downgradeToFree()

        cookbook.unsave("r0")
        #expect(cookbook.saveCap == 8)
        #expect(cookbook.save("r9") == .blockedByCap)

        cookbook.unsave("r1")
        #expect(cookbook.saveCap == Cookbook.freeSaveCap)
        #expect(cookbook.save("r9") == .blockedByCap)

        cookbook.unsave("r2")
        #expect(cookbook.saveCap == Cookbook.freeSaveCap)
        #expect(cookbook.save("r9") == .saved)
    }

    @Test("Unsaving a missing recipe does not lower the ceiling")
    func unsavingMissingRecipePreservesCeiling() {
        var cookbook = Cookbook(savedIDs: ["r1"], saveCap: 23)

        cookbook.unsave("missing")

        #expect(cookbook.savedIDs == ["r1"])
        #expect(cookbook.saveCap == 23)
    }
}
