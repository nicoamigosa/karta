import Foundation
import KartaCore
import KartaPresentation

/// Debug entry points for screenshotting signed-off states that no UI flow
/// can reach yet (review comment on #7: "arranque de depuración"). Enabled by
/// launching with `KARTA_SEED=<name>` in the environment; production launches
/// ignore it entirely. All state comes through `KartaStore`/`KartaState` —
/// no rules live here.
enum DebugSeeds {
    @MainActor
    static func store() -> KartaStore {
        guard let name = ProcessInfo.processInfo.environment["KARTA_SEED"] else {
            return KartaStore(state: KartaState(
                safetyProfile: SafetyProfile(intolerances: [])
            ))
        }
        let store = KartaStore(state: state(for: name))
        switch name {
        case "undo-ceiling":
            // Premium downgrade: a >7 ceiling dropping to the free floor, so
            // the Undo toast shows "Your cookbook now holds N recipes".
            store.send(.downgradeCookbookToFree)
            store.send(.unsaveRecipe("banana-pancakes"))
            store.send(.pushRoute(.recipeDetail(recipeID: "banana-pancakes")))
        case "intolerance":
            store.send(.pushRoute(.recipeDetail(recipeID: "banana-pancakes")))
        case "cookbook-full":
            // 7/7 saved; the reverse of an unsaved recipe is open so tapping
            // Save hits the cap and shows the sheet.
            store.send(.pushRoute(.recipeDetail(recipeID: "pesto-pasta")))
        case "undo-grid":
            // Plain removal inside the cookbook: toast names the recipe.
            store.send(.unsaveRecipe("caesar-salad"))
        default:
            break
        }
        return store
    }

    private static func state(for name: String) -> KartaState {
        switch name {
        case "repertoire":
            return KartaState(
                cookbook: Cookbook(savedIDs: [
                    "banana-pancakes", "caesar-salad", "spanish-tortilla",
                    "pesto-pasta", "lentil-stew"
                ]),
                onboarding: Self.onboarded(),
                cookHistory: [
                    CookEntry(recipeID: "banana-pancakes", date: Date()),
                    CookEntry(recipeID: "caesar-salad", date: Date()),
                    CookEntry(recipeID: "spanish-tortilla", date: Date())
                ],
                safetyProfile: SafetyProfile(intolerances: [])
            )
        case "empty-want-to-try":
            return KartaState(
                cookbook: Cookbook(savedIDs: [
                    "banana-pancakes", "caesar-salad", "spanish-tortilla"
                ]),
                onboarding: Self.onboarded(),
                cookHistory: [
                    CookEntry(recipeID: "banana-pancakes", date: Date()),
                    CookEntry(recipeID: "caesar-salad", date: Date()),
                    CookEntry(recipeID: "spanish-tortilla", date: Date())
                ],
                safetyProfile: SafetyProfile(intolerances: [])
            )
        case "intolerance":
            // Saved before a dairy intolerance existed: flagged, never hidden.
            return KartaState(
                cookbook: Cookbook(savedIDs: ["banana-pancakes", "lentil-stew"]),
                onboarding: Self.onboarded(intolerances: [.dairy]),
                safetyProfile: SafetyProfile(intolerances: [.dairy])
            )
        case "cookbook-full":
            return KartaState(
                cookbook: Cookbook(savedIDs: [
                    "banana-pancakes", "caesar-salad", "spanish-tortilla",
                    "lentil-stew", "quick-chicken-curry",
                    "vegetable-noodle-stir-fry", "baked-salmon-with-lemon"
                ]),
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        case "undo-grid":
            return KartaState(
                cookbook: Cookbook(savedIDs: [
                    "banana-pancakes", "caesar-salad", "spanish-tortilla",
                    "pesto-pasta", "lentil-stew"
                ]),
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        case "undo-ceiling":
            return KartaState(
                cookbook: Cookbook(
                    savedIDs: [
                        "banana-pancakes", "caesar-salad", "spanish-tortilla",
                        "pesto-pasta", "lentil-stew", "quick-chicken-curry",
                        "vegetable-noodle-stir-fry", "baked-salmon-with-lemon"
                    ],
                    saveCap: nil
                ),
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        default:
            return KartaState(safetyProfile: SafetyProfile(intolerances: []))
        }
    }

    private static func onboarded(
        intolerances: Set<Allergen> = []
    ) -> OnboardingState {
        OnboardingState(
            intoleranceAnswer: .answered(intolerances),
            householdSize: 2
        )
    }
}
