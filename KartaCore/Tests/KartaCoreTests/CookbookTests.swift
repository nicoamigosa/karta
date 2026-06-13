import Testing
@testable import KartaCore

/// The personal cookbook and the free-tier save cap, independent of UI.
@Suite("Cookbook — saving")
struct CookbookSavingTests {

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

    @Test("Unsaving removes the recipe")
    func unsaveRemoves() {
        var cookbook = Cookbook()
        cookbook.save("r1")

        cookbook.unsave("r1")
        #expect(cookbook.isSaved("r1") == false)
        #expect(cookbook.savedIDs.isEmpty)
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
}
