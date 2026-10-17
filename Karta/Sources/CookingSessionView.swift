import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// Cooking mode: the Sesión de cocina. Renders the active `CookingSession`
/// from the store — one self-contained Paso at a time, with its own
/// ingredients and quantities — and reports shell events (gestures, prompt
/// responses, step arrivals) back as store actions. No rules live here:
/// transitions, clamping, the cooked event and the probably-cooked inference
/// are all decided by `CookingSession`.
struct CookingSessionView: View {
    let session: CookingSession
    let recipe: Recipe
    let store: KartaStore

    private var suit: SuitTokens {
        KartaDesign.suit(recipe.primaryCourse)
    }

    private var step: CookingStep? {
        session.currentStep
    }

    private var intolerances: Set<Allergen> {
        store.state.safetyProfile.intolerances
    }

    var body: some View {
        ZStack {
            suit.back.ignoresSafeArea()

            VStack(alignment: .leading, spacing: KartaDesign.space.cardGap) {
                header

                if let step {
                    stepContent(step)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(locationX: location.x)
                        }
                }

                outcomeBar
            }
            .padding(.horizontal, KartaDesign.space.screenX)
            .padding(.top, KartaDesign.space.screenX)
            .padding(.bottom, KartaDesign.space.cardBottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KartaDesign.ColorToken.card)
        }
        .foregroundStyle(KartaDesign.ColorToken.ink)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            reportStepArrival()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: session.currentIndex) { _, _ in
            reportStepArrival()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Step \(session.currentIndex + 1) of \(session.steps.count)")
                .font(KartaDesign.FontToken.rankUnit())
                .tracking(KartaDesign.type.rankUnitTracking)
            Spacer(minLength: KartaDesign.space.cardGap)
            Text(recipe.primaryCourse.rawValue)
                .font(KartaDesign.FontToken.suitLabel())
        }
        .foregroundStyle(KartaDesign.ColorToken.ink)
    }

    private func stepContent(_ step: CookingStep) -> some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.onboardingGap) {
            let rows = CookingStepIngredients.rows(
                for: step,
                in: recipe,
                intolerances: intolerances
            )
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: KartaDesign.cooking.ingredientGap) {
                    Text("For this step")
                        .font(KartaDesign.FontToken.rankUnit())
                        .tracking(KartaDesign.type.rankUnitTracking)
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)

                    ForEach(rows, id: \.name) { row in
                        HStack(alignment: .firstTextBaseline, spacing: KartaDesign.space.chipGap) {
                            Text(row.name)
                                .font(KartaDesign.FontToken.cookIngredient())
                                .foregroundStyle(row.isOptional
                                    ? KartaDesign.ColorToken.inkMuted
                                    : KartaDesign.ColorToken.ink)
                            Spacer(minLength: KartaDesign.space.cardGap)
                            Text(row.isOptional ? "\(row.quantity) · optional" : row.quantity)
                                .font(KartaDesign.FontToken.cookQuantity())
                                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(KartaDesign.space.cardX)
                .background(
                    KartaDesign.ColorToken.paper,
                    in: RoundedRectangle(
                        cornerRadius: KartaDesign.radius.photo,
                        style: .continuous
                    )
                )
            }

            Text(step.text)
                .font(KartaDesign.FontToken.cookStep())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)

            if step.isOptional {
                Text("Optional step")
                    .font(KartaDesign.FontToken.stepCue())
                    .foregroundStyle(suit.chipInk)
                    .padding(.vertical, KartaDesign.space.stepCueY)
                    .padding(.horizontal, KartaDesign.space.rankGap * 2)
                    .background(
                        suit.chip,
                        in: RoundedRectangle(
                            cornerRadius: KartaDesign.radius.cue,
                            style: .continuous
                        )
                    )
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var outcomeBar: some View {
        if session.showsOutcomePrompt {
            VStack(spacing: KartaDesign.space.cardGap) {
                Text("How did it turn out?")
                    .font(KartaDesign.FontToken.cookOutcome())
                    .foregroundStyle(KartaDesign.ColorToken.ink)

                HStack(spacing: KartaDesign.cooking.outcomeGap) {
                    outcomeButton(outcome: .thumbsUp, label: "👍", help: "It turned out well")
                    outcomeButton(outcome: .thumbsDown, label: "👎", help: "It did not turn out well")
                    outcomeButton(outcome: .photo, label: "📷", help: "Share a photo")
                }
            }
            .frame(maxWidth: .infinity)
        } else if session.cookedEvent != nil {
            Text("Cooked. Swipe down to finish.")
                .font(KartaDesign.FontToken.hint())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .frame(maxWidth: .infinity)
        } else {
            Text("Swipe right for next step · swipe down to exit")
                .font(KartaDesign.FontToken.hint())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .frame(maxWidth: .infinity)
        }
    }

    private func outcomeButton(
        outcome: CookOutcome,
        label: String,
        help: String
    ) -> some View {
        Button {
            store.send(.respond(outcome))
        } label: {
            Text(label)
                .font(.system(size: KartaDesign.cooking.outcomeGlyph))
                .frame(
                    width: KartaDesign.cooking.outcomeHit,
                    height: KartaDesign.cooking.outcomeHit
                )
                .background {
                    Circle()
                        .fill(KartaDesign.ColorToken.buttonEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Circle().fill(KartaDesign.ColorToken.card)
                    Circle().strokeBorder(
                        KartaDesign.ColorToken.line,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
                }
        }
        .accessibilityLabel(help)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: KartaDesign.cooking.dragMinimumDistance)
            .onEnded { value in
                guard let command = CookingGestureDecision.command(
                    translation: value.translation,
                    predictedTranslation: value.predictedEndTranslation
                ) else { return }
                send(command)
            }
    }

    private func handleTap(locationX: CGFloat) {
        guard let command = CookingTapDecision.command(
            locationX: locationX,
            width: UIScreen.main.bounds.width - 2 * KartaDesign.space.screenX
        ) else { return }
        send(command)
    }

    private func send(_ command: CookingCommand) {
        switch command {
        case .next:
            store.send(.nextStep(now: Date().timeIntervalSince1970))
        case .previous:
            store.send(.previousStep)
        case .exit:
            store.send(.exitCooking)
        }
    }

    /// Report the Paso settling on screen: on the last one, let the session
    /// itself decide whether the journey already counts as a probable cook.
    private func reportStepArrival() {
        guard let step = session.currentStep else { return }
        for action in CookingStepArrival.actions(
            for: step,
            isLastStep: session.isOnLastStep,
            now: Date().timeIntervalSince1970
        ) {
            store.send(action)
        }
    }
}
