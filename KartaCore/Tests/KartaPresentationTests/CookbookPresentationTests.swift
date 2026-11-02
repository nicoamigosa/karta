import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Cookbook presentation")
struct CookbookPresentationTests {
    @Test("Saved recipe tags name only declared intolerances in a stable order", arguments: [
        (Set<Allergen>(), nil),
        ([.dairy], "Dairy"),
        ([.nuts, .dairy], "Dairy +1"),
        ([.nuts], "Nuts"),
    ] as [(Set<Allergen>, String?)])
    @MainActor
    func intoleranceTags(intolerances: Set<Allergen>, tag: String?) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["saved", "cooked", "missing", "unreviewed"]),
            onboarding: OnboardingState(intoleranceAnswer: .answered(intolerances), householdSize: 2),
            cookHistory: [CookEntry(recipeID: "cooked", date: Date(timeIntervalSince1970: 1))],
            safetyProfile: SafetyProfile(intolerances: intolerances),
            filterDraft: FilterDraft(maxMinutes: 5)
        ))
        let catalog = [
            recipe("saved", review: .reviewed([.dairy, .nuts])),
            recipe("cooked", review: .reviewed([.dairy, .nuts])),
            recipe("unreviewed", review: .unreviewed),
        ]

        let presentation = store.cookbookPresentation(recipes: catalog)

        #expect(presentation.wantToTry.map(\.recipeID) == ["saved"])
        #expect(presentation.repertoire.map(\.recipeID) == ["cooked"])
        #expect(presentation.wantToTry.first?.intoleranceTag == tag)
        #expect(presentation.repertoire.first?.intoleranceTag == tag)
    }

    @Test("The store projects both halves and their counts in saved order")
    @MainActor
    func rowsAndCountsFollowSavedOrder() {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["try-b", "inferred", "missing", "explicit", "unreviewed", "try-a"]),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            cookHistory: [
                CookEntry(recipeID: "explicit", date: Date(timeIntervalSince1970: 1)),
                CookEntry(recipeID: "inferred", date: Date(timeIntervalSince1970: 2), wasInferred: true),
                CookEntry(recipeID: "unsaved", date: Date(timeIntervalSince1970: 3)),
            ],
            safetyProfile: SafetyProfile(intolerances: []),
            filterDraft: FilterDraft(maxMinutes: 5)
        ))
        let catalog = [
            recipe("explicit"), recipe("try-a"), recipe("unsaved"),
            recipe("inferred"), recipe("try-b"), recipe("unreviewed", review: .unreviewed),
        ]

        let presentation = store.cookbookPresentation(recipes: catalog)

        #expect(presentation.repertoire.map(\.recipeID) == ["inferred", "explicit"])
        #expect(presentation.wantToTry.map(\.recipeID) == ["try-b", "try-a"])
        #expect(presentation.repertoireCount == 2)
        #expect(presentation.wantToTryCount == 2)
        #expect(presentation.wantToTry.first?.name == "Recipe try-b")
        #expect(presentation.wantToTry.first?.photo == .local("try-b"))
        #expect(presentation.wantToTry.first?.timeLabel == "35 MIN")
    }

    @Test("Cooking and saving again keep Repertorio membership and history", arguments: [false, true])
    @MainActor
    func cookingAndResavingPreserveRepertoire(wasInferred: Bool) {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])))
        let catalog = [recipe("cooked"), recipe("uncooked")]
        let entry = CookEntry(
            recipeID: "cooked", date: Date(timeIntervalSince1970: 1), wasInferred: wasInferred
        )

        let empty = store.cookbookPresentation(recipes: catalog)
        #expect(empty.repertoireCount == 0)
        #expect(empty.wantToTryCount == 0)

        store.send(.recordCook(entry))
        let unsaved = store.cookbookPresentation(recipes: catalog)
        #expect(unsaved.repertoire.isEmpty)
        #expect(unsaved.wantToTry.isEmpty)

        store.send(.saveRecipe("cooked"))
        store.send(.saveRecipe("uncooked"))
        let saved = store.cookbookPresentation(recipes: catalog)
        #expect(saved.repertoire.map(\.recipeID) == ["cooked"])
        #expect(saved.wantToTry.map(\.recipeID) == ["uncooked"])

        store.send(.unsaveRecipe("cooked"))
        let removed = store.cookbookPresentation(recipes: catalog)
        #expect(removed.repertoireCount == 0)
        #expect(removed.wantToTryCount == 1)
        #expect(store.state.cookHistory == [entry])

        store.send(.saveRecipe("cooked"))
        let restored = store.cookbookPresentation(recipes: catalog)
        #expect(restored.repertoire.map(\.recipeID) == ["cooked"])
        #expect(restored.repertoireCount == 1)
        #expect(restored.wantToTryCount == 1)
        #expect(store.state.cookHistory == [entry])

        store.send(.recordCook(CookEntry(recipeID: "uncooked", date: Date(timeIntervalSince1970: 2))))
        let allCooked = store.cookbookPresentation(recipes: catalog)
        #expect(allCooked.repertoire.map(\.recipeID) == ["uncooked", "cooked"])
        #expect(allCooked.repertoireCount == 2)
        #expect(allCooked.wantToTryCount == 0)
    }

    @Test("Free cupo links appear within two slots and above the normal ceiling", arguments: [
        (0, 7, nil), (4, 7, nil),
        (5, 7, "5 of 7 saved on the free plan"),
        (6, 7, "6 of 7 saved on the free plan"),
        (7, 7, "7 of 7 saved on the free plan"),
        (23, 23, "23 of 23 saved on the free plan"),
    ] as [(Int, Int, String?)])
    @MainActor
    func freeCupo(count: Int, ceiling: Int, expected: String?) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: ceiling),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        let line = store.cookbookPresentation(recipes: []).cupoLine
        #expect(line?.text == expected)
        #expect(line?.link == (expected == nil ? nil : .goUnlimited))
        #expect(line?.link?.title == (expected == nil ? nil : "Go unlimited"))
        #expect(store.showsGoPremium)
    }

    @Test("Cupo line names the reported plan and stays quiet while unknown", arguments: [
        (nil, 0, 7, "0 of 7 saved on the free plan", nil),
        (nil, 5, 7, "5 of 7 saved on the free plan", nil),
        (nil, 23, 23, "23 of 23 saved on the free plan", nil),
        (nil, 23, nil, nil, nil),
        (.premium, 0, 7, "Premium", .manage),
        (.premium, 23, 23, "Premium", .manage),
        (.trial(endsAt: Date(timeIntervalSince1970: 1_793_923_200)), 0, 7,
         "Free trial until Nov 6", .manage),
        (.trial(endsAt: Date(timeIntervalSince1970: 1_793_923_200)), 23, 23,
         "Free trial until Nov 6", .manage),
    ] as [(Entitlement?, Int, Int?, String?, CookbookPresentation.CupoLine.Link?)])
    @MainActor
    func planCupo(entitlement: Entitlement?, count: Int, ceiling: Int?, text: String?,
                  link: CookbookPresentation.CupoLine.Link?) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: ceiling),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        if let entitlement { store.send(.entitlementChanged(entitlement)) }
        let line = store.cookbookPresentation(recipes: [], timeZone: TimeZone(secondsFromGMT: 0)!).cupoLine
        #expect(line?.text == text)
        #expect(line?.link == link)
        #expect(line?.link?.title == (link == nil ? nil : "Manage"))
        #expect(!store.showsGoPremium)
    }

    @Test("Trial dates use the injected time zone", arguments: [
        (0, "Free trial until Nov 6"), (-8 * 60 * 60, "Free trial until Nov 5"),
    ])
    @MainActor
    func trialTimeZone(offset: Int, text: String) throws {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.entitlementChanged(.trial(endsAt: Date(timeIntervalSince1970: 1_793_923_200))))
        let zone = try #require(TimeZone(secondsFromGMT: offset))
        #expect(store.cookbookPresentation(recipes: [], timeZone: zone).cupoLine?.text == text)
    }

    @Test("Unsave toast and Undo preserve the Cookbook and cooking history", arguments: [
        (7, Optional(7), "Recipe r3"),
        (8, Optional(8), "Your cookbook now holds 7 recipes"),
        (23, Optional(23), "Your cookbook now holds 22 recipes"),
        (23, nil, "Recipe r3"),
    ] as [(Int, Int?, String)])
    @MainActor
    func unsaveToastAndUndo(count: Int, ceiling: Int?, secondLine: String) throws {
        let original = Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: ceiling)
        let history = [CookEntry(recipeID: "r3", date: Date(timeIntervalSince1970: 1))]
        let store = KartaStore(state: KartaState(
            cookbook: original,
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            cookHistory: history, safetyProfile: SafetyProfile(intolerances: [])
        ))
        #expect(store.unsaveToast(recipes: [recipe("r3")]) == nil)

        store.send(.unsaveRecipe("r3"))
        let toast = try #require(store.unsaveToast(recipes: [recipe("r3")]))
        #expect(toast.title == "Removed from cookbook")
        #expect(toast.secondLine == secondLine)
        #expect(toast.recipeID == "r3")
        #expect(!store.cookbook.isSaved("r3"))

        store.send(.undoUnsave)
        #expect(store.cookbook == original)
        #expect(store.state.cookHistory == history)
        #expect(store.unsaveToast(recipes: [recipe("r3")]) == nil)
        store.send(.undoUnsave)
        #expect(store.cookbook == original)
    }

    @Test("A cap-blocked save exposes the full sheet count", arguments: [
        (7, "7 OF 7 SAVED"), (23, "23 OF 23 SAVED"),
    ])
    @MainActor
    func blockedSaveCount(count: Int, label: String) throws {
        var cookbook = Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: nil)
        cookbook.downgradeToFree()
        let store = KartaStore(state: KartaState(
            cookbook: cookbook,
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        #expect(store.blockedByCap == nil)

        store.send(.saveRecipe("overflow"))
        let full = try #require(store.blockedByCap)
        #expect(full.savedCount == count)
        #expect(full.ceiling == count)
        #expect(full.countLabel == label)
        #expect(full.explanation == (count == 7
            ? "Free cookbooks hold 7 recipes. Go unlimited to keep every recipe you like."
            : "Your cookbook keeps all 23 recipes on the free plan. Go unlimited to add more."))
        #expect(store.cookbook == cookbook)
        #expect(store.state.lastSaveResult == .blockedByCap(saved: count, ceiling: count))

        store.send(.saveRecipe("r0"))
        #expect(store.state.lastSaveResult == .alreadySaved)
        #expect(store.blockedByCap == nil)
    }

    @Test("Undo cannot resurrect a removal after dismissal or a later save", arguments: [
        KartaAction.dismissUnsaveToast, .saveRecipe("new"),
    ])
    @MainActor
    func expiredUndoDoesNotRestore(action: KartaAction) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["r1", "r2"]),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.unsaveRecipe("r1"))
        store.send(action)
        let after = store.cookbook

        store.send(.undoUnsave)

        #expect(store.cookbook == after)
        #expect(!store.cookbook.isSaved("r1"))
        #expect(store.unsaveToast(recipes: [recipe("r1")]) == nil)
    }

    @Test("Selection spans both halves, toggles recipes, and Done clears it")
    @MainActor
    func selectionAcrossHalves() {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["cooked", "try"]),
            cookHistory: [CookEntry(recipeID: "cooked", date: Date(timeIntervalSince1970: 1))],
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        let catalog = [recipe("cooked"), recipe("try")]
        #expect(store.cookbookPresentation(recipes: catalog).canSelect)
        #expect(!store.cookbookPresentation(recipes: catalog).isSelecting)
        store.send(.beginCookbookSelection)
        let empty = store.cookbookPresentation(recipes: catalog)
        #expect(empty.isSelecting)
        #expect(empty.selectionBarText == "Select recipes")
        #expect(!empty.canRemoveSelection)

        store.send(.toggleCookbookSelection("cooked"))
        let repertoire = store.cookbookPresentation(recipes: catalog)
        #expect(repertoire.selectedRecipeIDs == ["cooked"])
        #expect(repertoire.selectionBarText == "1 selected")
        #expect(repertoire.canRemoveSelection)
        // The shell changes halves by choosing the other projected array.
        #expect(repertoire.repertoire.map(\.recipeID) == ["cooked"])
        #expect(store.cookbookPresentation(recipes: catalog).wantToTry.map(\.recipeID) == ["try"])
        store.send(.toggleCookbookSelection("try"))
        #expect(store.cookbookPresentation(recipes: catalog).selectionBarText == "2 selected")
        #expect(store.cookbookPresentation(recipes: catalog).selectedRecipeIDs == ["cooked", "try"])
        store.send(.toggleCookbookSelection("cooked"))
        #expect(store.cookbookPresentation(recipes: catalog).selectedRecipeIDs == ["try"])
        store.send(.endCookbookSelection)
        let done = store.cookbookPresentation(recipes: catalog)
        #expect(!done.isSelecting)
        #expect(done.selectedRecipeIDs.isEmpty)
        #expect(store.cookbook.savedIDs == ["cooked", "try"])
    }

    @Test("Remove selection shows one toast in saved order and Undo restores all slots", arguments: [
        (1, "Removed from cookbook", "Recipe r0"),
        (2, "2 recipes removed", "Recipe r0, Recipe r1"),
        (3, "3 recipes removed", "Recipe r0, Recipe r1, Recipe r2"),
        (5, "5 recipes removed", "Recipe r0, Recipe r1, Recipe r2 and 2 more"),
    ])
    @MainActor
    func removeSelectionToast(count: Int, title: String, names: String) throws {
        let ids = (0..<count).map { "r\($0)" }
        let original = Cookbook(savedIDs: ["first"] + ids + ["last"])
        let store = KartaStore(state: KartaState(
            cookbook: original, safetyProfile: SafetyProfile(intolerances: [])
        ))
        let catalog = ids.reversed().map { recipe($0) }
        store.send(.beginCookbookSelection)
        for id in ids.reversed() { store.send(.toggleCookbookSelection(id)) }
        store.send(.removeCookbookSelection)

        let toast = try #require(store.unsaveToast(recipes: catalog))
        #expect(toast.title == title)
        #expect(toast.secondLine == names)
        #expect(toast.recipeIDs == ids)
        #expect(store.cookbook.savedIDs == ["first", "last"])
        #expect(!store.cookbookPresentation(recipes: catalog).isSelecting)
        #expect(store.cookbookPresentation(recipes: catalog).selectedRecipeIDs.isEmpty)
        store.send(.undoUnsave)
        #expect(store.cookbook == original)
        #expect(store.unsaveToast(recipes: catalog) == nil)
        #expect(!store.cookbookPresentation(recipes: catalog).isSelecting)
    }

    @Test("Batch removal after downgrade lowers the ceiling to its floor and Undo restores it", arguments: [
        (8, 7), (10, 7), (23, 19),
    ])
    @MainActor
    func batchRemovalAfterDowngrade(count: Int, ceilingAfter: Int) throws {
        let ids = (0..<count).map { "r\($0)" }
        let history = [CookEntry(recipeID: "r1", date: Date(timeIntervalSince1970: 1))]
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ids, saveCap: nil), cookHistory: history,
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.premium))
        store.send(.entitlementChanged(.free))
        let original = store.cookbook
        store.send(.beginCookbookSelection)
        for id in ["r6", "r1", "r3", "r0"] { store.send(.toggleCookbookSelection(id)) }
        store.send(.removeCookbookSelection)

        let toast = try #require(store.unsaveToast(recipes: ids.map { recipe($0) }))
        #expect(toast.title == "4 recipes removed")
        #expect(toast.secondLine == "Your cookbook now holds \(ceilingAfter) recipes")
        #expect(store.cookbook.saveCap == ceilingAfter)
        #expect(store.cookbook.savedIDs.count == count - 4)
        #expect(store.state.userSnapshot.cookbook == store.cookbook)
        #expect(store.state.cookHistory == history)
        store.send(.undoUnsave)
        #expect(store.cookbook == original)
        #expect(store.cookbook.saveCap == count)
        #expect(store.state.cookHistory == history)
    }

    @Test("Saving again after batch removal returns explicit and inferred cooks to Repertorio", arguments: [false, true])
    @MainActor
    func batchRemovalKeepsCookedHistory(wasInferred: Bool) {
        let history = [CookEntry(recipeID: "cooked", date: Date(timeIntervalSince1970: 1), wasInferred: wasInferred)]
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ["cooked", "try"]), cookHistory: history,
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        let catalog = [recipe("cooked"), recipe("try")]
        store.send(.beginCookbookSelection)
        store.send(.toggleCookbookSelection("cooked"))
        store.send(.toggleCookbookSelection("try"))
        store.send(.removeCookbookSelection)
        #expect(store.cookbook.savedIDs.isEmpty)
        #expect(store.state.userSnapshot.cookHistory == history)
        store.send(.saveRecipe("cooked"))
        #expect(store.cookbookPresentation(recipes: catalog).repertoire.map(\.recipeID) == ["cooked"])
        #expect(store.cookbookPresentation(recipes: catalog).wantToTry.isEmpty)
        #expect(store.state.cookHistory == history)
    }

    @Test("Selection requires saved recipes and stays out of the persisted snapshot")
    @MainActor
    func selectionGuardsAndPersistence() {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        let catalog = [recipe("saved")]
        store.send(.beginCookbookSelection)
        #expect(!store.cookbookPresentation(recipes: catalog).canSelect)
        #expect(!store.cookbookPresentation(recipes: catalog).isSelecting)
        store.send(.saveRecipe("saved"))
        // A saved slot still belongs to the Cookbook if its catalogue entry is temporarily unavailable.
        #expect(store.cookbookPresentation(recipes: []).canSelect)
        store.send(.toggleCookbookSelection("saved"))
        #expect(store.cookbookPresentation(recipes: catalog).selectedRecipeIDs.isEmpty)
        store.send(.beginCookbookSelection)
        store.send(.toggleCookbookSelection("missing"))
        store.send(.removeCookbookSelection)
        #expect(store.cookbookPresentation(recipes: catalog).isSelecting)
        #expect(store.cookbookPresentation(recipes: catalog).selectedRecipeIDs.isEmpty)
        #expect(store.cookbook.savedIDs == ["saved"])
        #expect(store.unsaveToast(recipes: catalog) == nil)
        store.send(.toggleCookbookSelection("saved"))
        let restored = KartaStore(state: KartaState(snapshot: store.state.userSnapshot))
        #expect(restored.cookbook.savedIDs == ["saved"])
        #expect(!restored.cookbookPresentation(recipes: catalog).isSelecting)
        #expect(restored.cookbookPresentation(recipes: catalog).selectedRecipeIDs.isEmpty)
    }

    private func recipe(_ id: String, review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(
            id: id, name: "Recipe \(id)", heroPhoto: .local(id),
            totalMinutes: 35, difficulty: .easy, servings: 2, primaryCourse: .dinner,
            ingredients: [], steps: ["Cook"], allergenReview: review
        )
    }
}
