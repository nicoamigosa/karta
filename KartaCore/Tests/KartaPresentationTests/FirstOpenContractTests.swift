import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("First open contract")
struct FirstOpenContractTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var clock: FirstOpenClock { FirstOpenClock(now: now) }

    private func recipe(_ id: String, allergens: Set<Allergen> = [], minutes: Int = 15) -> Recipe {
        Recipe(id: id, name: id, heroPhoto: .local("test"), totalMinutes: minutes,
               difficulty: .easy, servings: 4, primaryCourse: .dinner,
               ingredients: [Ingredient(name: "Rice", quantity: "1 cup")],
               steps: ["Cook"], allergenReview: .reviewed(allergens))
    }

    @Test("No recent cooks is not a filter-empty failure in Leftovers")
    func noRecentLeftovers() {
        let state = KartaState(safetyProfile: SafetyProfile(intolerances: []))
        #expect(state.leftoversEmptyState(recipes: [recipe("safe")], clock: clock) == .none)
    }

    @MainActor
    @Test("Only an enabled first-run submission resets the feed, even when safety stays the same")
    func submissionAnchors() {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        let anchor = ScrollAnchor(recipeID: "safe", relativeOffset: 0)
        store.send(.onboarding(.setMine))
        store.send(.setFeedAnchor(anchor, world: .forYou))
        store.send(.onboarding(.showMyCards))
        #expect(store.state.navigation.anchor(for: .forYou) == anchor)
        for allergen in Allergen.allCases {
            store.send(.onboarding(.toggleFirstRunAllergen(allergen)))
        }
        store.send(.onboarding(.chooseFirstRunHousehold(2)))
        store.send(.onboarding(.showMyCards))
        #expect(store.state.navigation.anchor(for: .forYou) == nil)
        store.send(.setFeedAnchor(anchor, world: .forYou))
        store.send(.onboarding(.showMyCards))
        #expect(store.state.navigation.anchor(for: .forYou) == anchor)
    }

    @Test("A catalog without safe-deck recipes names all five allergens in both Mundos")
    func noSafeDeckRecipe() {
        let state = KartaState(safetyProfile: SafetyProfile(intolerances: []))
        let catalog = [recipe("dairy", allergens: [.dairy])]
        let expected = FeedEmptyState.noMatchForProfile(allergens: "dairy, egg, fish, gluten and nuts")
        #expect(state.feedEmptyState(recipes: catalog, clock: clock) == expected)
        #expect(state.leftoversEmptyState(recipes: catalog, clock: clock) == expected)
    }

    @Test("Tour skips, Reduce Motion and answered cold launches follow the signed stops")
    func tourVariants() {
        for skipWorld in [false, true] {
            var state = OnboardingState()
            state.reduce(.coldLaunch(reduceMotion: false))
            #expect(state.tourStop?.title == "Your cookbook")
            #expect(state.tourStop?.line == "What you save lives here.")
            #expect(state.tourStop?.progress == "1 OF 3")
            #expect(state.tourStop?.delay == 1.2)
            if skipWorld {
                state.reduce(.tourDelayElapsed)
                #expect(state.tourStop?.title == "For You or Leftovers")
                #expect(state.tourStop?.line == "Switch decks here.")
                #expect(state.tourStop?.progress == "2 OF 3")
            }
            state.reduce(.tourTap)
            #expect(state.tourStop == .filters)
            #expect(state.tourStop?.progress == "3 OF 3")
            #expect(state.tourStop?.delay == nil)
            #expect(state.pulsesFilter)
            #expect(state.tourSkipLine == nil)
            #expect(!state.canShowEntryNudge)
            state.reduce(.tourTap)
            #expect(state.canShowEntryNudge)
        }
        var reduced = OnboardingState()
        reduced.reduce(.coldLaunch(reduceMotion: true))
        #expect(reduced.tourStop == .filters)
        #expect(!reduced.pulsesFilter)
        reduced.reduce(.answerIntolerances([]))
        reduced.reduce(.coldLaunch(reduceMotion: false))
        #expect(reduced.tourStop == nil)
        #expect(reduced.banner == nil)
        reduced.reduce(.filterButtonTapped)
        #expect(reduced.panel == .full)
    }

    @Test("The first-run copy describes all three answer states and 5+ means five")
    func firstRunCopy() {
        var state = OnboardingState()
        #expect(state.banner?.line == "Free of all five allergens until you tell us yours.")
        #expect(state.banner?.actionLabel == "Set mine")
        state.reduce(state.banner!.action)
        #expect(state.firstRunPanel.title == "Two quick questions")
        #expect(state.firstRunPanel.subtitle == "Change them anytime in Filters.")
        #expect(state.firstRunPanel.actionLabel == "Show my cards")
        #expect(state.firstRunPanel.controls.cookingFor.map(\.isOn) == [false, false, false, false, false])
        #expect(state.firstRunPanel.controls.cookingFor.map(\.label) == ["1", "2", "3", "4", "5+"])
        state.reduce(.toggleFirstRunAllergen(.dairy))
        state.reduce(.toggleFirstRunAllergen(.egg))
        state.reduce(.toggleFirstRunAllergen(.nuts))
        #expect(state.firstRunPanel.intoleranceLine ==
                "Dairy, Egg and Nuts will never show up. Change it anytime here.")
        state.reduce(.toggleFirstRunAllergen(.nuts))
        #expect(state.firstRunPanel.intoleranceLine ==
                "Dairy and Egg will never show up. Change it anytime here.")
        state.reduce(.toggleFirstRunAllergen(.egg))
        state.reduce(.toggleFirstRunAllergen(.dairy))
        state.reduce(.chooseFirstRunHousehold(5))
        #expect(state.firstRunPanel.intoleranceLine ==
                "Nothing hidden: you eat all five. Change it anytime here.")
        state.reduce(.showMyCards)
        #expect(state.profile == OnboardingProfile(intolerances: [], householdSize: 5))
    }

    @MainActor
    @Test("Full-panel Hogar saves immediately without changing filters, badge, N or Intolerancias")
    func fullPanelHousehold() throws {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(intoleranceAnswer: .answered([.dairy]), householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [.dairy]),
            filterDraft: FilterDraft(maxMinutes: 20)))
        store.send(.filter(.setSafetyProfile(SafetyProfile(intolerances: [.egg]))))
        let catalog = [recipe("fast"), recipe("slow", minutes: 45)]
        let beforeCount = store.state.draftRecipeCount(
            for: .forYou, draft: store.state.filterDraft, recipes: catalog, clock: clock)
        let anchor = ScrollAnchor(recipeID: "fast", relativeOffset: 0)
        store.send(.setFeedAnchor(anchor, world: .forYou))
        for size in 1...5 {
            store.send(.onboarding(.setHouseholdSize(size)))
            #expect(store.state.userSnapshot.profile?.householdSize == size)
            #expect(store.state.userSnapshot.profile?.intolerances == [.egg])
            #expect(store.state.appliedFilterCount == 1)
            #expect(store.state.filterDraft == FilterDraft(maxMinutes: 20))
            #expect(store.state.draftRecipeCount(for: .forYou, draft: store.state.filterDraft,
                                                 recipes: catalog, clock: clock) == beforeCount)
            #expect(store.state.navigation.anchor(for: .forYou) == anchor)
        }
        store.send(.filter(.reset))
        store.send(.filter(.apply(FilterDraft())))
        #expect(store.state.onboarding.householdSize == 5)
        #expect(store.state.appliedFilterCount == 0)
        let panel = FilterPanelPresentation(draft: store.state.filterDraft,
                                           safetyProfile: store.state.safetyProfile,
                                           householdSize: store.state.onboarding.householdSize)
        #expect(panel.householdLine == "Saved as you tap. Every size still shows up.")
        #expect(panel.cookingFor.map(\.isOn) == [false, false, false, false, true])
        let restored = try #require(UserSnapshot.restore(from: store.state.userSnapshot.encoded()).snapshot)
        #expect(restored.profile?.householdSize == 5)
    }

    @MainActor
    @Test("Unanswered users can open, save and cook the Baraja segura")
    func useSafeDeck() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        let safe = recipe("safe")
        #expect(store.cardPresentation(for: safe) != nil)
        #expect(store.reversePresentation(for: safe) != nil)
        for allergen in Allergen.allCases {
            let unsafe = recipe(allergen.rawValue, allergens: [allergen])
            #expect(store.cardPresentation(for: unsafe) == nil)
            #expect(store.reversePresentation(for: unsafe) == nil)
        }
        store.send(.recordOpen(recipeID: safe.id, at: now))
        store.send(.saveRecipe(safe.id))
        store.send(.startCooking(safe, startedAt: now.timeIntervalSince1970))
        store.send(.nextStep(now: now.timeIntervalSince1970 + 10))
        store.send(.respond(.thumbsUp))
        #expect(store.state.cookHistory.count == 1)
        #expect(store.state.userSnapshot.profile == nil)
        #expect(store.state.cookbook.isSaved("safe"))
    }

    @MainActor
    @Test("An unanswered store round-trips its actions and legacy JSON without pending answers")
    func storeSnapshot() throws {
        let legacy = Data(#"{"version":1,"profile":{"intolerances":[],"householdSize":2},"tasteCalibration":{"likedIDs":["old","old"],"unknown":{"enabled":true,"note":"keep"}}}"#.utf8)
        let old = try #require(UserSnapshot.restore(from: legacy).snapshot)
        let store = KartaStore(state: KartaState(snapshot: UserSnapshot(
            profile: nil, legacyPayload: old.legacyPayload)))
        store.send(.onboarding(.coldLaunch(reduceMotion: false)))
        store.send(.saveRecipe("safe"))
        store.send(.recordView(recipeID: "safe", at: now))
        store.send(.recordOpen(recipeID: "safe", at: now))
        store.send(.recordCook(CookEntry(recipeID: "safe", date: now)))
        store.send(.onboarding(.setMine))
        store.send(.onboarding(.toggleFirstRunAllergen(.dairy)))
        store.send(.onboarding(.chooseFirstRunHousehold(2)))
        let data = try store.state.userSnapshot.encoded()
        let snapshot = try #require(UserSnapshot.restore(from: data).snapshot)
        #expect(snapshot.profile == nil)
        #expect(snapshot.cookbook.savedIDs == ["safe"])
        #expect(snapshot.viewHistory.entries.count == 1)
        #expect(snapshot.viewHistory.openings.count == 1)
        #expect(snapshot.cookHistory.count == 1)
        #expect(snapshot.legacyPayload == old.legacyPayload)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let original = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        #expect((json["tasteCalibration"] as? NSDictionary) == (original["tasteCalibration"] as? NSDictionary))
        var resumed = KartaState(snapshot: snapshot)
        #expect(resumed.onboarding.firstRunPanel.householdSize == nil)
        #expect(resumed.onboarding.firstRunPanel.intolerances.isEmpty)
        KartaReducer.reduce(&resumed, action: .onboarding(.coldLaunch(reduceMotion: false)))
        #expect(resumed.onboarding.tourStop == .filters)
    }

    @Test("Unanswered and every answered profile are safe in both Mundos, with filters on top")
    func everyProfileInBothWorlds() throws {
        let allergens = Allergen.allCases
        let subsets = (0..<(1 << allergens.count)).map { mask in
            Set(allergens.enumerated().compactMap { index, allergen in
                mask & (1 << index) == 0 ? nil : allergen
            })
        }
        let catalog = subsets.enumerated().map {
            recipe("r\($0.offset)", allergens: $0.element, minutes: $0.offset % 2 == 0 ? 15 : 45)
        } + [recipe("source")]
        let answers: [IntoleranceAnswer] = [.unanswered] + subsets.map { .answered($0) }
        for answer in answers {
            for minutes in [nil, 20] as [Int?] {
                let state = KartaState(
                    onboarding: OnboardingState(intoleranceAnswer: answer, householdSize: 2),
                    cookHistory: [CookEntry(recipeID: "source", date: now)],
                    safetyProfile: SafetyProfile(intolerances: {
                        if case let .answered(value) = answer { return value }
                        return []
                    }()),
                    filterDraft: FilterDraft(maxMinutes: minutes))
                let forbidden: Set<Allergen> = if case let .answered(value) = answer {
                    value
                } else { Set(allergens) }
                let expected = Set(subsets.enumerated().compactMap { index, contains in
                    contains.isDisjoint(with: forbidden) && (minutes == nil || index % 2 == 0)
                        ? "r\(index)" : nil
                })
                let feed = try #require(state.feed(recipes: catalog, clock: clock))
                #expect(Set(feed.recipes.map(\.id)) == expected.union(["source"]))
                #expect(Set(state.leftoversFeed(recipes: catalog, clock: clock).recipes.map(\.id)) == expected)
            }
        }
    }
}

private struct FirstOpenClock: KartaClock {
    let now: Date
}
