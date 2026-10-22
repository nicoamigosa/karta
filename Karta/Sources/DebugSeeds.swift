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
        case "cooking-first", "cooking-timer", "cooking-step",
             "cooking-last", "cooking-answered", "cooking-timer-running",
             "cooking-timer-done", "cooking-finish", "cooking-shrunk",
             "cooking-scroll":
            seedCooking(name, into: store)
        default:
            break
        }
        return store
    }

    /// Cooking-session states (#101): enter the session and walk to the
    /// Paso (or the Cierre) that shows the signed-off board.
    @MainActor
    private static func seedCooking(_ name: String, into store: KartaStore) {
        let recipe: Recipe?
        if name == "cooking-shrunk" {
            recipe = Self.longPasoRecipe
        } else if name == "cooking-scroll" {
            recipe = Self.scrollingPasoRecipe
        } else {
            recipe = try? SeedResourceAdapter().loadRecipes()
                .first(where: { $0.id == "spanish-tortilla" })
        }
        guard let recipe else { return }
        store.send(.startCooking(
            recipe,
            startedAt: Date().timeIntervalSince1970
        ))
        let target: Int
        switch name {
        case "cooking-timer", "cooking-timer-running", "cooking-timer-done": target = 1
        case "cooking-step": target = 2
        case "cooking-last", "cooking-answered", "cooking-finish", "cooking-shrunk",
             "cooking-scroll":
            target = 3
        default: target = 0
        }
        while store.session?.currentIndex != target {
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        if name == "cooking-finish" || name == "cooking-answered" {
            // One more swipe past the last Paso lands on the Cierre.
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        if name == "cooking-answered" {
            store.send(.respond(.thumbsUp))
        }
        if name == "cooking-timer-running" {
            // Timer running on another Paso: start it on the timer step,
            // then view the step after it.
            store.send(.startTimer(now: Date().timeIntervalSince1970))
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        if name == "cooking-timer-done" {
            // Timer already fired on another Paso: start it in the past so
            // its segment shows the "Time's up" pill.
            store.send(.startTimer(now: Date().timeIntervalSince1970 - 800))
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
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
        case "cooking-first", "cooking-timer", "cooking-step",
             "cooking-last", "cooking-answered", "cooking-timer-running",
             "cooking-timer-done", "cooking-finish", "cooking-shrunk",
             "cooking-scroll":
            return KartaState(
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        default:
            return KartaState(safetyProfile: SafetyProfile(intolerances: []))
        }
    }

    /// Synthetic recipes a debug seed adds to the loaded catalog — never
    /// part of the seed data itself.
    static func extraRecipes() -> [Recipe] {
        switch ProcessInfo.processInfo.environment["KARTA_SEED"] {
        case "cooking-shrunk":
            return [longPasoRecipe]
        case "cooking-scroll":
            return [scrollingPasoRecipe]
        default:
            return []
        }
    }

    /// The `cooking-step-shrunk` board's Paso: a two-line Resumen, a
    /// three-line Detalle, six ingredient rows and a 40 min Temporizador,
    /// so the media window gives way toward 160 pt before the body scrolls.
    private static var longPasoRecipe: Recipe {
        let ingredients: [Ingredient] = [
            Ingredient(id: "lentils", name: "Brown lentils", quantity: "1 1/2 cups"),
            Ingredient(id: "chorizo", name: "Spanish chorizo", quantity: "1 link (about 4 oz)"),
            Ingredient(id: "carrots", name: "Nantes carrots", quantity: "2 medium"),
            Ingredient(id: "potatoes", name: "Yukon Gold potatoes", quantity: "2 medium"),
            Ingredient(id: "onion", name: "Yellow onion", quantity: "1 medium"),
            Ingredient(id: "paprika", name: "Sweet paprika", quantity: "1 tsp")
        ]
        return Recipe(
            id: "lentil-stew-long",
            name: "Lentil Stew",
            heroPhoto: .local("photos/spanish-tortilla"),
            totalMinutes: 55,
            difficulty: .easy,
            servings: 4,
            primaryCourse: .dinner,
            ingredients: ingredients,
            steps: [
                CookingStep(
                    detail: "Soften the onion and the carrots in the oil.",
                    summary: "Sauté the base",
                    ingredients: [
                        StepIngredient(ingredientID: "onion", quantity: "1 medium")
                    ]
                ),
                CookingStep(
                    detail: "Brown the chorizo so it releases its fat.",
                    summary: "Brown the chorizo",
                    ingredients: [
                        StepIngredient(ingredientID: "chorizo", quantity: "1 link (about 4 oz)")
                    ]
                ),
                CookingStep(
                    detail: "Add the paprika and the potatoes and stir well.",
                    summary: "Add paprika and potatoes",
                    ingredients: [
                        StepIngredient(ingredientID: "paprika", quantity: "1 tsp")
                    ]
                ),
                CookingStep(
                    detail: "Cover and simmer over low heat until the lentils are tender. Stir now and then so nothing sticks to the pot.",
                    summary: "Simmer until the lentils are tender",
                    ingredients: ingredients.map {
                        StepIngredient(ingredientID: $0.id, quantity: $0.quantity)
                    },
                    timerSeconds: 2400
                )
            ],
            allergenReview: .reviewed([])
        )
    }

    /// A Paso that overflows even with the media window at its 160 pt floor:
    /// nine ingredient rows so the signalled scroll (fade + chip + indicator)
    /// engages at the default text size.
    private static var scrollingPasoRecipe: Recipe {
        let extras: [Ingredient] = [
            Ingredient(id: "lentils", name: "Brown lentils", quantity: "1 1/2 cups"),
            Ingredient(id: "chorizo", name: "Spanish chorizo", quantity: "1 link (about 4 oz)"),
            Ingredient(id: "carrots", name: "Nantes carrots", quantity: "2 medium"),
            Ingredient(id: "potatoes", name: "Yukon Gold potatoes", quantity: "2 medium"),
            Ingredient(id: "onion", name: "Yellow onion", quantity: "1 medium"),
            Ingredient(id: "paprika", name: "Sweet paprika", quantity: "1 tsp"),
            Ingredient(id: "garlic", name: "Garlic cloves", quantity: "3"),
            Ingredient(id: "bay", name: "Bay leaves", quantity: "2"),
            Ingredient(id: "stock", name: "Chicken stock", quantity: "4 cups")
        ]
        return Recipe(
            id: "lentil-stew-scrolling",
            name: "Lentil Stew",
            heroPhoto: .local("photos/spanish-tortilla"),
            totalMinutes: 55,
            difficulty: .easy,
            servings: 4,
            primaryCourse: .dinner,
            ingredients: extras,
            steps: [
                CookingStep(
                    detail: "Soften the onion and the carrots in the oil.",
                    summary: "Sauté the base",
                    ingredients: [
                        StepIngredient(ingredientID: "onion", quantity: "1 medium")
                    ]
                ),
                CookingStep(
                    detail: "Brown the chorizo so it releases its fat.",
                    summary: "Brown the chorizo",
                    ingredients: [
                        StepIngredient(ingredientID: "chorizo", quantity: "1 link (about 4 oz)")
                    ]
                ),
                CookingStep(
                    detail: "Add the paprika and the potatoes and stir well.",
                    summary: "Add paprika and potatoes",
                    ingredients: [
                        StepIngredient(ingredientID: "paprika", quantity: "1 tsp")
                    ]
                ),
                CookingStep(
                    detail: "Cover and simmer over low heat until the lentils are tender. Stir now and then so nothing sticks to the pot.",
                    summary: "Simmer until the lentils are tender",
                    ingredients: extras.map {
                        StepIngredient(ingredientID: $0.id, quantity: $0.quantity)
                    },
                    timerSeconds: 2400
                )
            ],
            allergenReview: .reviewed([])
        )
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
