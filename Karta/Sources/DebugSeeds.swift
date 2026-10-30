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
             "cooking-timer-paused",
             "cooking-timer-done", "cooking-finish", "cooking-shrunk",
             "cooking-scroll", "cooking-timer-twins", "cooking-overflow-twins",
             "cooking-t1-running", "cooking-t1-paused",
             "cooking-t1-done", "cooking-alarms-off":
            seedCooking(name, into: store)
        default:
            break
        }
        return store
    }

    /// Whether the seed asks the feed to open with the Mundo menu already
    /// down (#8's `feed-world-menu.png` board): menu openness is shell state,
    /// not store state, so it cannot ride `KartaState`.
    static var opensMundoMenu: Bool {
        ProcessInfo.processInfo.environment["KARTA_SEED"] == "world-menu"
    }

    /// Whether the seed asks the feed to open with the filter panel already
    /// down (#6's `feed-filters*.png` boards): panel openness is shell state,
    /// like the Mundo menu's.
    static var opensFilterPanel: Bool {
        ["filters-open", "filters-intolerance"]
            .contains(ProcessInfo.processInfo.environment["KARTA_SEED"])
    }

    /// The allergen the panel reports as just saved (`filters-intolerance`,
    /// board `feed-filters-intolerance.png`): the confirmation line is view
    /// state, so the seed supplies it directly.
    static var panelIntoleranceNote: Allergen? {
        ProcessInfo.processInfo.environment["KARTA_SEED"] == "filters-intolerance"
            ? .gluten
            : nil
    }

    /// The draft the panel opens with when the seed draws one (`filters-open`,
    /// board `feed-filters.png`): 30 min + one-pan edited but not yet applied,
    /// so the badge stays off and the feed below is unfiltered.
    static var panelInitialDraft: FilterDraft? {
        ProcessInfo.processInfo.environment["KARTA_SEED"] == "filters-open"
            ? FilterDraft(maxMinutes: 30, practicalTags: [.onePan])
            : nil
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
        } else if name == "cooking-timer-twins" {
            recipe = Self.timerTwinsRecipe
        } else if name == "cooking-overflow-twins" {
            recipe = Self.overflowTwinsRecipe
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
        case "cooking-timer", "cooking-timer-running", "cooking-timer-paused",
             "cooking-timer-done", "cooking-t1-running", "cooking-t1-paused",
             "cooking-t1-done", "cooking-alarms-off": target = 1
        case "cooking-timer-twins", "cooking-overflow-twins": target = 1
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
        if name == "cooking-timer-paused" {
            // Timer paused on another Paso: start it, pause it, then view
            // the step after it so its segment shows the paused pill.
            let now = Date().timeIntervalSince1970
            store.send(.startTimer(now: now))
            store.send(.pauseTimer(now: now + 225))
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        if name == "cooking-timer-done" {
            // Timer already fired on another Paso: start it in the past so
            // its segment shows the "Time's up" pill.
            store.send(.startTimer(now: Date().timeIntervalSince1970 - 800))
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        if name == "cooking-t1-running" {
            store.send(.startTimer(now: Date().timeIntervalSince1970))
        }
        if name == "cooking-t1-paused" {
            let now = Date().timeIntervalSince1970
            store.send(.startTimer(now: now))
            store.send(.pauseTimer(now: now + 225))
        }
        if name == "cooking-t1-done" {
            store.send(.startTimer(now: Date().timeIntervalSince1970 - 800))
        }
        if name == "cooking-alarms-off" {
            // The first start was denied: the store shows the one-time
            // "Alarms are off" sheet while the Temporizador still runs.
            store.send(.startTimer(now: Date().timeIntervalSince1970))
            store.send(.alarmPermissionDenied)
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
        case "filters-applied":
            // Two applied filters, for the badge on the filter button
            // (board `feed-filters-applied.png`): the badge counts the time
            // cap and the one Practical tag, never an Intolerancia.
            return KartaState(
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: []),
                filterDraft: FilterDraft(maxMinutes: 30, practicalTags: [.onePan])
            )
        case "filters-open":
            // The panel editing an unapplied 30 min + one-pan draft over the
            // unfiltered feed, dairy already declared (board
            // `feed-filters.png`): nothing is applied, so the badge stays
            // off; the draft itself comes from `panelInitialDraft`.
            return KartaState(
                onboarding: Self.onboarded(intolerances: [.dairy]),
                safetyProfile: SafetyProfile(intolerances: [.dairy])
            )
        case "filters-intolerance":
            // Right after adding Gluten as an Intolerancia (board
            // `feed-filters-intolerance.png`): all-Any draft, the confirmation
            // line comes from `panelIntoleranceNote`.
            return KartaState(
                onboarding: Self.onboarded(intolerances: [.dairy, .gluten]),
                safetyProfile: SafetyProfile(intolerances: [.dairy, .gluten])
            )
        case "empty-filters":
            // 20 min + one-pan leaves nothing, but the dairy Intolerancia
            // alone would leave some (board `feed-empty-filters.png`).
            return KartaState(
                onboarding: Self.onboarded(intolerances: [.dairy]),
                safetyProfile: SafetyProfile(intolerances: [.dairy]),
                filterDraft: FilterDraft(maxMinutes: 20, practicalTags: [.onePan])
            )
        case "intolerance-applied":
            // Gluten declared: the deck's top Cards are the recipes the
            // profile still allows; nothing containing gluten remains.
            return KartaState(
                onboarding: Self.onboarded(intolerances: [.gluten]),
                safetyProfile: SafetyProfile(intolerances: [.gluten])
            )
        case "empty-profile":
            // Every Intolerancia declared: no catalog recipe survives, with
            // or without filters (board `feed-empty-profile.png`).
            return KartaState(
                onboarding: Self.onboarded(intolerances: Set(Allergen.allCases)),
                safetyProfile: SafetyProfile(intolerances: Set(Allergen.allCases))
            )
        case "leftovers":
            // The Leftovers Mundo open on its placeholder until #9 lands.
            return KartaState(
                onboarding: Self.onboarded(),
                navigation: AppNavigationState(world: .leftovers),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        case "world-menu":
            return KartaState(
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        case "cooking-first", "cooking-timer", "cooking-step",
             "cooking-last", "cooking-answered", "cooking-timer-running",
             "cooking-timer-paused",
             "cooking-timer-done", "cooking-finish", "cooking-shrunk",
             "cooking-scroll", "cooking-timer-twins", "cooking-overflow-twins",
             "cooking-t1-running", "cooking-t1-paused",
             "cooking-t1-done", "cooking-alarms-off":
            return KartaState(
                onboarding: Self.onboarded(),
                safetyProfile: SafetyProfile(intolerances: [])
            )
        default:
            return KartaState(safetyProfile: SafetyProfile(intolerances: []))
        }
    }

    /// Seed ids a debug seed removes from the loaded catalog: the
    /// `feed-empty-profile` board only shows when nothing reviewed is free of
    /// the declared Intolerancias, and the bundled catalog always keeps two
    /// allergen-free recipes.
    static var droppedRecipeIDs: Set<String> {
        switch ProcessInfo.processInfo.environment["KARTA_SEED"] {
        case "empty-profile":
            return ["quick-chicken-curry", "lentil-stew"]
        default:
            return []
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
        case "cooking-timer-twins":
            return [timerTwinsRecipe]
        case "cooking-overflow-twins":
            return [overflowTwinsRecipe]
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

    /// Two consecutive Pasos that declare the same Temporizador and measure
    /// the same (#123): at AX sizes the scrolled bottom zone must re-measure
    /// on the second Paso even though its height matches the first's.
    private static var timerTwinsRecipe: Recipe {
        let ingredients: [Ingredient] = [
            Ingredient(id: "rice", name: "Bomba rice", quantity: "2 cups"),
            Ingredient(id: "stock", name: "Chicken stock", quantity: "4 cups"),
            Ingredient(id: "saffron", name: "Saffron threads", quantity: "1 pinch")
        ]
        let stepIngredients = ingredients.map {
            StepIngredient(ingredientID: $0.id, quantity: $0.quantity)
        }
        return Recipe(
            id: "saffron-rice-timer-twins",
            name: "Saffron Rice",
            heroPhoto: .local("photos/spanish-tortilla"),
            totalMinutes: 40,
            difficulty: .easy,
            servings: 4,
            primaryCourse: .dinner,
            ingredients: ingredients,
            steps: [
                CookingStep(
                    detail: "Warm the stock with the saffron.",
                    summary: "Warm the stock",
                    ingredients: [
                        StepIngredient(ingredientID: "stock", quantity: "4 cups"),
                        StepIngredient(ingredientID: "saffron", quantity: "1 pinch")
                    ]
                ),
                CookingStep(
                    detail: "Simmer the rice over low heat, uncovered.",
                    summary: "Simmer the rice",
                    ingredients: stepIngredients,
                    timerSeconds: 1200
                ),
                CookingStep(
                    detail: "Simmer the rice over low heat, uncovered.",
                    summary: "Simmer the rice",
                    ingredients: stepIngredients,
                    timerSeconds: 1200
                ),
                CookingStep(
                    detail: "Rest off the heat, covered, before serving.",
                    summary: "Rest the rice",
                    ingredients: [
                        StepIngredient(ingredientID: "rice", quantity: "2 cups")
                    ]
                )
            ],
            allergenReview: .reviewed([])
        )
    }

    /// Two consecutive Pasos that overflow identically (#123): the same nine
    /// rows land at the same positions, so the *N more ingredients* chip must
    /// read the same count on both.
    private static var overflowTwinsRecipe: Recipe {
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
        let twinRows = extras.map {
            StepIngredient(ingredientID: $0.id, quantity: $0.quantity)
        }
        return Recipe(
            id: "lentil-stew-overflow-twins",
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
                    detail: "Cover and simmer over low heat until the lentils are tender. Stir now and then so nothing sticks to the pot.",
                    summary: "Simmer until the lentils are tender",
                    ingredients: twinRows
                ),
                CookingStep(
                    detail: "Cover and simmer over low heat until the lentils are tender. Stir now and then so nothing sticks to the pot.",
                    summary: "Simmer until the lentils are tender",
                    ingredients: twinRows
                ),
                CookingStep(
                    detail: "Season and serve with bread.",
                    summary: "Season and serve",
                    ingredients: [
                        StepIngredient(ingredientID: "paprika", quantity: "1 tsp")
                    ]
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
