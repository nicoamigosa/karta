import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Entitlement")
struct EntitlementTests {
    @Test("Trial and premium lift the cupo without losing saves", arguments: [
        Entitlement.trial(endsAt: Date(timeIntervalSince1970: 1_794_009_600)), .premium,
    ])
    @MainActor
    func liftsCupo(entitlement: Entitlement) {
        let ids = (0..<7).map { "r\($0)" }
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ids), safetyProfile: SafetyProfile(intolerances: [])
        ))
        #expect(store.state.entitlement == nil)
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("eighth"))
        #expect(store.state.lastSaveResult == .blockedByCap(saved: 7, ceiling: 7))

        store.send(.entitlementChanged(entitlement))
        #expect(store.cookbook.savedIDs == ids)
        #expect(store.cookbook.saveCap == nil)
        #expect(store.blockedByCap == nil)
        store.send(.saveRecipe("eighth"))
        #expect(store.state.lastSaveResult == .saved)
        #expect(store.cookbook.savedIDs == ids + ["eighth"])
        let before = store.state
        store.send(.entitlementChanged(entitlement))
        #expect(store.state == before)
    }

    @Test("Repeated plan round trips preserve saves and follow ADR 0007", arguments: [
        (0, 7), (5, 7), (7, 7), (8, 8), (23, 23),
    ])
    @MainActor
    func roundTrips(count: Int, freeCeiling: Int) {
        let ids = (0..<count).map { "r\($0)" }
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ids, saveCap: nil),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        let plans: [Entitlement] = [
            .free, .trial(endsAt: Date(timeIntervalSince1970: 1_793_923_200)),
            .free, .premium, .free, .premium, .free,
        ]
        for plan in plans {
            store.send(.entitlementChanged(plan))
            #expect(store.cookbook.savedIDs == ids)
            #expect(store.cookbook.saveCap == (plan == .free ? freeCeiling : nil))
            #expect(store.showsGoPremium == (plan == .free))
            if count >= 5, plan == .free {
                #expect(store.cookbookPresentation(recipes: []).cupoLine?.link == .goUnlimited)
            }
            let before = store.state
            store.send(.entitlementChanged(plan))
            #expect(store.state == before)
        }
        if count > 7 {
            store.send(.unsaveRecipe("r0"))
            #expect(store.cookbook.saveCap == count - 1)
            store.send(.saveRecipe("new"))
            #expect(store.state.lastSaveResult == .blockedByCap(saved: count - 1, ceiling: count - 1))
            store.send(.entitlementChanged(.premium))
            store.send(.saveRecipe("new"))
            #expect(store.state.lastSaveResult == .saved)
            store.send(.entitlementChanged(.free))
            #expect(store.cookbook.saveCap == count)
            #expect(store.cookbook.savedIDs == Array(ids.dropFirst()) + ["new"])
        }
    }

    @Test("Free at the cap can edit Intolerancias, apply every filter, and cook")
    @MainActor
    func freeAtCapStillCooks() throws {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<7).map { "r\($0)" }),
            onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("eighth"))
        #expect(store.state.lastSaveResult == .blockedByCap(saved: 7, ceiling: 7))
        store.send(.filter(.setSafetyProfile(SafetyProfile(intolerances: [.dairy]))))
        let draft = FilterDraft(
            maxMinutes: 20, maxDifficulty: .easy, diet: .vegan,
            practicalTags: [.onePan, .oven, .makeAhead, .shareable]
        )
        store.send(.filter(.apply(draft)))
        #expect(store.state.safetyProfile.intolerances == [.dairy])
        #expect(store.state.filterDraft == draft)
        let safe = Recipe(
            id: "safe", name: "Safe", heroPhoto: .local("safe"), totalMinutes: 15,
            difficulty: .easy, servings: 2, primaryCourse: .dinner,
            diets: [.vegan], practicalTags: [.onePan, .oven, .makeAhead, .shareable],
            ingredients: [], steps: ["Cook"], allergenReview: .reviewed([])
        )
        let unsafe = Recipe(
            id: "unsafe", name: "Unsafe", heroPhoto: .local("unsafe"), totalMinutes: 15,
            difficulty: .easy, servings: 2, primaryCourse: .dinner,
            diets: [.vegan], practicalTags: [.onePan, .oven, .makeAhead, .shareable],
            ingredients: [], steps: ["Cook"], allergenReview: .reviewed([.dairy])
        )
        let feed = try #require(store.feed(recipes: [safe, unsafe], clock: EntitlementTestClock()))
        #expect(feed.recipes.map(\.id) == ["safe"])
        #expect(store.cardPresentation(for: unsafe) == nil)
        #expect(store.reversePresentation(for: safe) != nil)
        store.send(.startCooking(safe, startedAt: 0))
        #expect(store.session?.recipeID == "safe")
        store.send(.nextStep(now: 900))
        #expect(store.session?.isOnFinish == true)
        #expect(store.cookbook.savedIDs.count == 7)
    }

    @Test("A launch restores only the ceiling and waits for an App Store report", arguments: [
        Optional(7), Optional(23), nil,
    ])
    @MainActor
    func launchDoesNotRestoreEntitlement(ceiling: Int?) throws {
        let ids = (0..<7).map { "r\($0)" }
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: ids), safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.premium))
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookbook: Cookbook(savedIDs: store.cookbook.savedIDs, saveCap: ceiling)
        )
        let data = try snapshot.encoded()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["entitlement"] == nil)
        let restored = try #require(UserSnapshot.restore(from: data).snapshot)
        let relaunched = KartaStore(state: KartaState(
            cookbook: restored.cookbook,
            safetyProfile: SafetyProfile(intolerances: restored.profile.intolerances)
        ))
        #expect(relaunched.state.entitlement == nil)
        #expect(!relaunched.showsGoPremium)
        #expect(relaunched.cookbook.saveCap == ceiling)
        #expect(relaunched.cookbook.savedIDs == ids)
        #expect(relaunched.cookbookPresentation(recipes: []).cupoLine?.link == nil)
        relaunched.send(.saveRecipe("eighth"))
        if ceiling == 7 {
            #expect(relaunched.state.lastSaveResult == .blockedByCap(saved: 7, ceiling: 7))
        } else {
            #expect(relaunched.state.lastSaveResult == .saved)
        }
        relaunched.send(.entitlementChanged(.free))
        #expect(relaunched.cookbook.saveCap == (ceiling == nil ? 8 : ceiling))
    }
}

private struct EntitlementTestClock: KartaClock {
    var now: Date { Date(timeIntervalSince1970: 0) }
}
