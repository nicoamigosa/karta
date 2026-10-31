import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Sixth save toast")
struct SaveToastTests {
    @Test("Only the sixth free save raises the signed toast", arguments: [4, 5, 6])
    @MainActor
    func freeSave(count: Int) throws {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<count).map { "r\($0)" }),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("new"))
        #expect(store.state.lastSaveResult == .saved)
        if count == 5 {
            let toast = try #require(store.state.pendingSaveToast)
            #expect(toast.title == "Saved to your cookbook")
            #expect(toast.secondLine == "1 spot left on the free plan")
            #expect(toast.action == .seePlans)
            #expect(toast.action.title == "See plans")
            #expect(toast.recipeID == "new")
            #expect(store.state.hasShownSaveToast)
        } else {
            #expect(store.state.pendingSaveToast == nil)
            #expect(!store.state.hasShownSaveToast)
        }
    }
    @Test("A later toast action clears the invitation without allowing it again", arguments: [
        KartaAction.dismissSaveToast, .saveRecipe("seventh"), .saveRecipe("new"),
        .unsaveRecipe("new"), .unsaveRecipe("missing"), .undoUnsave,
        .entitlementChanged(.premium),
    ])
    @MainActor
    func oneShot(action: KartaAction) throws {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<5).map { "r\($0)" }),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("new"))
        #expect(store.state.pendingSaveToast != nil)
        // Repeating the entitlement report leaves all transient state intact.
        let before = store.state
        store.send(.entitlementChanged(.free))
        #expect(store.state == before)
        store.send(action)
        #expect(store.state.pendingSaveToast == nil)
        #expect(store.state.hasShownSaveToast)
        store.send(.entitlementChanged(.premium))
        store.send(.entitlementChanged(.free))
        store.send(.unsaveRecipe("new"))
        store.send(.unsaveRecipe("seventh"))
        store.send(.saveRecipe("later-sixth"))
        #expect(store.cookbook.savedIDs.count == 6)
        #expect(store.state.pendingSaveToast == nil)
        store.send(.unsaveRecipe("later-sixth"))
        store.send(.saveRecipe("later-sixth"))
        #expect(store.state.pendingSaveToast == nil)
    }

    @Test("Persisting while the toast is visible prevents another invitation after launch")
    @MainActor
    func snapshotRoundTrip() throws {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<5).map { "r\($0)" }),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("sixth"))
        let snapshot = UserSnapshot(
            profile: OnboardingProfile(intolerances: [], householdSize: 2),
            cookbook: store.cookbook, hasShownSaveToast: store.state.hasShownSaveToast
        )
        let data = try snapshot.encoded()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["hasShownSaveToast"] as? Bool == true)
        let restored = try #require(UserSnapshot.restore(from: data).snapshot)
        #expect(restored == snapshot)
        #expect(restored.hasShownSaveToast)
        let relaunched = KartaStore(state: KartaState(
            cookbook: restored.cookbook,
            safetyProfile: SafetyProfile(intolerances: restored.profile.intolerances),
            hasShownSaveToast: restored.hasShownSaveToast
        ))
        #expect(relaunched.state.pendingSaveToast == nil)
        relaunched.send(.entitlementChanged(.free))
        relaunched.send(.unsaveRecipe("sixth"))
        relaunched.send(.saveRecipe("sixth"))
        #expect(relaunched.state.pendingSaveToast == nil)
    }

    @Test("A version 1 snapshot without the flag allows the sixth-save toast")
    @MainActor
    func legacySnapshot() throws {
        let data = Data(#"""
        {"version":1,"profile":{"intolerances":[],"householdSize":2},
         "cookbook":{"savedIDs":["r0","r1","r2","r3","r4"],"saveCap":7}}
        """#.utf8)
        let snapshot = try #require(UserSnapshot.restore(from: data).snapshot)
        #expect(!snapshot.hasShownSaveToast)
        let restored = try #require(UserSnapshot.restore(from: snapshot.encoded()).snapshot)
        #expect(!restored.hasShownSaveToast)
        let store = KartaStore(state: KartaState(
            cookbook: restored.cookbook,
            safetyProfile: SafetyProfile(intolerances: restored.profile.intolerances),
            hasShownSaveToast: restored.hasShownSaveToast
        ))
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("sixth"))
        #expect(store.state.pendingSaveToast?.recipeID == "sixth")
    }

    @Test("Trial, premium and unknown saves never raise or consume the invitation", arguments: [
        Optional<Entitlement>.none, .some(.premium),
        .some(.trial(endsAt: Date(timeIntervalSince1970: 1_800_000_000))),
    ])
    @MainActor
    func otherEntitlements(entitlement: Entitlement?) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<4).map { "r\($0)" }),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        if let entitlement { store.send(.entitlementChanged(entitlement)) }
        for id in ["fifth", "sixth", "seventh"] {
            store.send(.saveRecipe(id))
            #expect(store.state.lastSaveResult == .saved)
            #expect(store.state.pendingSaveToast == nil)
            #expect(!store.state.hasShownSaveToast)
        }
        store.send(.entitlementChanged(.free))
        #expect(store.state.pendingSaveToast == nil)
        store.send(.unsaveRecipe("seventh"))
        store.send(.unsaveRecipe("sixth"))
        store.send(.saveRecipe("sixth"))
        #expect(store.state.pendingSaveToast?.recipeID == "sixth")
    }

    @Test("Duplicate and blocked saves never consume the invitation", arguments: [5, 6, 7])
    @MainActor
    func unsuccessfulSaves(count: Int) {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<count).map { "r\($0)" }),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        store.send(.saveRecipe("r0"))
        #expect(store.state.lastSaveResult == .alreadySaved)
        #expect(store.state.pendingSaveToast == nil)
        #expect(!store.state.hasShownSaveToast)
        if count == 7 {
            store.send(.saveRecipe("eighth"))
            #expect(store.state.lastSaveResult == .blockedByCap(saved: 7, ceiling: 7))
            #expect(store.state.pendingSaveToast == nil)
            #expect(!store.state.hasShownSaveToast)
        }
    }

}
