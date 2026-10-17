import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Cooking session shell")
struct CookingSessionTests {
    private struct FixedClock: KartaClock {
        let now: Date
    }

    @Test("Gestures map to next / previous / exit")
    func gestureDecisions() {
        let threshold = KartaDesign.cooking.swipeThreshold

        // Swipe right advances.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 60, height: 4),
            predictedTranslation: CGSize(width: threshold, height: 0)
        ) == .next)

        // Swipe left goes back.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: -60, height: 4),
            predictedTranslation: CGSize(width: -threshold, height: 0)
        ) == .previous)

        // Swipe down exits.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 6, height: 80),
            predictedTranslation: CGSize(width: 0, height: threshold)
        ) == .exit)

        // Swipe up does nothing.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 0, height: -90),
            predictedTranslation: CGSize(width: 0, height: -threshold)
        ) == nil)

        // Sub-threshold gestures do nothing.
        #expect(CookingGestureDecision.command(
            translation: CGSize(width: 30, height: 30),
            predictedTranslation: CGSize(width: 39, height: 0)
        ) == nil)
    }

    @Test("Taps: right half advances, left half goes back")
    func tapDecisions() {
        #expect(CookingTapDecision.command(locationX: 300, width: 390) == .next)
        #expect(CookingTapDecision.command(locationX: 60, width: 390) == .previous)
        #expect(CookingTapDecision.command(locationX: 10, width: 0) == nil)
    }

    @MainActor
    @Test("Each Paso resolves its own ingredient names and step quantities")
    func stepIngredientsResolve() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first { !$0.steps.isEmpty })
        let step = try #require(recipe.steps.first { !$0.ingredients.isEmpty })

        let rows = CookingStepIngredients.rows(
            for: step,
            in: recipe,
            intolerances: []
        )

        #expect(rows.count == step.ingredients.count)
        for (row, reference) in zip(rows, step.ingredients) {
            let ingredient = try #require(
                recipe.ingredients.first { $0.id == reference.ingredientID }
            )
            #expect(row.name == ingredient.name)
            #expect(!row.name.isEmpty)
            #expect(row.quantity == reference.quantity)
            #expect(!row.quantity.isEmpty)
        }
    }

    @MainActor
    @Test("A dairy intolerance hides the optional ingredient from the Paso")
    func stepIngredientsRespectIntolerances() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let intolerances: Set<Allergen> = [.dairy]

        // A seed recipe with an optional dairy ingredient (e.g. the curry's
        // Greek yogurt), and a hand-built Paso that references it — one that
        // could never reach the screen through visibleSteps, to prove the row
        // projection itself applies the filter.
        var foundDairyOptional = false
        for recipe in recipes {
            for optional in recipe.ingredients where optional.isOptional
                && !optional.allergens.isDisjoint(with: intolerances) {
                foundDairyOptional = true
                let step = CookingStep(
                    text: "Finish",
                    ingredients: [StepIngredient(
                        ingredientID: optional.id,
                        quantity: optional.quantity
                    )]
                )

                let filtered = CookingStepIngredients.rows(
                    for: step,
                    in: recipe,
                    intolerances: intolerances
                )
                #expect(filtered.isEmpty)

                let unfiltered = CookingStepIngredients.rows(
                    for: step,
                    in: recipe,
                    intolerances: []
                )
                #expect(unfiltered.map(\.name) == [optional.name])
            }
        }
        #expect(foundDairyOptional)
    }

    @MainActor
    @Test("Arriving at the last Paso only reports the inference action")
    func stepArrivalActions() {
        let timed = CookingStep(text: "Simmer", timerSeconds: 600)
        let actions = CookingStepArrival.actions(
            for: timed,
            isLastStep: true,
            now: 1000
        )

        #expect(actions.count == 1)
        guard case let .inferProbablyCooked(inferNow) = actions[0] else {
            Issue.record("Expected only .inferProbablyCooked")
            return
        }
        #expect(inferNow == 1000)

        // A timer declaration never starts the timer on arrival.
        #expect(CookingStepArrival.actions(
            for: timed,
            isLastStep: false,
            now: 1000
        ).isEmpty)

        #expect(CookingStepArrival.actions(
            for: CookingStep(text: "Stir"),
            isLastStep: false,
            now: 0
        ).isEmpty)
    }

    @MainActor
    @Test("Start → advance → last step → response emits the cooked event")
    func successEventEmission() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        // Entered cooking mode.
        let startedAt = now.timeIntervalSince1970
        store.send(.startCooking(recipe, startedAt: startedAt))
        var session = try #require(store.session)
        #expect(session.recipeID == recipe.id)
        #expect(session.currentIndex == 0)
        #expect(session.cookedEvent == nil)

        // Walked to the last step.
        while !session.isOnLastStep {
            store.send(.nextStep(now: Date().timeIntervalSince1970))
            session = try #require(store.session)
        }
        #expect(session.showsOutcomePrompt)

        // Prompt response emits the explicit cooked event.
        store.send(.respond(.thumbsUp))
        let event = try #require(store.session?.cookedEvent)
        #expect(event.recipeID == recipe.id)
        #expect(event.outcome == .thumbsUp)
        #expect(!event.wasInferred)

        // Exiting is terminal.
        store.send(.exitCooking)
        #expect(store.session?.isExited == true)
        #expect(CookingRoute.recipe(for: store.session, in: recipes) == nil)
    }

    @MainActor
    @Test("The photo outcome emits the cooked event too")
    func photoOutcome() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        store.send(.startCooking(recipe, startedAt: now.timeIntervalSince1970))
        while store.session?.isOnLastStep == false {
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        }
        store.send(.respond(.photo))

        let event = try #require(store.session?.cookedEvent)
        #expect(event.outcome == .photo)
        #expect(!event.wasInferred)
    }

    @MainActor
    @Test("The overlay resolves the running session's recipe")
    func cookingRoute() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first)
        let session = recipe.cookingSession()

        #expect(CookingRoute.recipe(for: session, in: recipes) == recipe)
        #expect(CookingRoute.recipe(for: nil, in: recipes) == nil)

        var exited = session
        exited.exit()
        #expect(CookingRoute.recipe(for: exited, in: recipes) == nil)

        var other = CookingSession(
            recipeID: "not-in-the-catalog",
            steps: [CookingStep(text: "Step")]
        )
        #expect(CookingRoute.recipe(for: other, in: recipes) == nil)
        other.exit()
        #expect(CookingRoute.recipe(for: other, in: recipes) == nil)
    }
}
