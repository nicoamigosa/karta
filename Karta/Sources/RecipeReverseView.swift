import SwiftUI
import KartaCore
import KartaPresentation

/// The reverse of a Card: the Apertura. Renders what
/// `KartaStore.reversePresentation` projects — ingredients with verbatim
/// quantities and editor step summaries — so no filtering or formatting rules
/// live in the view.
struct RecipeReverseView: View {
    let recipe: Recipe
    let presentation: RecipeReversePresentation
    let manifest: MediaAssetManifest
    let store: KartaStore

    private var suit: SuitTokens {
        KartaDesign.suit(recipe.primaryCourse)
    }

    private var isSaved: Bool {
        store.cookbook.isSaved(recipe.id)
    }

    private var saveBlocked: Bool {
        !isSaved && store.cookbook.isAtCap
    }

    var body: some View {
        ZStack {
            suit.back.ignoresSafeArea()

            CardRelief(edgeColors: KartaDesign.ColorToken.cardEdges) {
                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(alignment: .leading, spacing: KartaDesign.space.cardGap) {
                            titleRow
                            ingredientsSection
                            stepsSection
                        }
                        .padding(.top, KartaDesign.space.cardGap)
                    }

                    TactileButton("Start cooking  →") {
                        store.send(.startCooking(
                            recipe,
                            startedAt: Date().timeIntervalSince1970
                        ))
                    }
                    .padding(.top, KartaDesign.space.cardGap)
                }
                .padding(.top, KartaDesign.space.cardTop)
                .padding(.horizontal, KartaDesign.space.cardX)
                .padding(.bottom, KartaDesign.space.cardBottom)
            }
            .padding(.horizontal, KartaDesign.space.reverseCardX)
            .padding(.vertical, KartaDesign.space.reverseCardY)
        }
    }

    private var header: some View {
        ZStack {
            Text(recipe.primaryCourse.rawValue)
                .font(KartaDesign.FontToken.suitLabel())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .frame(maxWidth: .infinity)

            HStack {
                Button {
                    store.send(.popRoute)
                } label: {
                    Image(systemName: "xmark")
                        .font(KartaDesign.FontToken.button())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .frame(
                            width: KartaDesign.space.reverseButtonHit,
                            height: KartaDesign.space.reverseButtonHit
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back to feed")

                Spacer()

                Button(isSaved ? "Saved" : "Save") {
                    store.send(isSaved ? .unsaveRecipe(recipe.id) : .saveRecipe(recipe.id))
                }
                .font(KartaDesign.FontToken.button())
                .foregroundStyle(
                    saveBlocked
                        ? KartaDesign.ColorToken.inkMuted
                        : KartaDesign.ColorToken.ink
                )
                .disabled(saveBlocked)
                .accessibilityHint(
                    saveBlocked ? "Your cookbook is full" : "Saves the recipe to your cookbook"
                )
            }
        }
        .frame(height: KartaDesign.space.reverseButtonHit)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: KartaDesign.space.cardGap) {
            RecipePhoto(reference: recipe.heroPhoto, manifest: manifest)
                .frame(
                    width: KartaDesign.space.reversePhotoEdge,
                    height: KartaDesign.space.reversePhotoEdge
                )
                .clipShape(RoundedRectangle(
                    cornerRadius: KartaDesign.radius.photo,
                    style: .continuous
                ))

            VStack(alignment: .leading, spacing: KartaDesign.space.rankGap) {
                Text(recipe.name)
                    .font(KartaDesign.FontToken.cardTitle())
                    .tracking(KartaDesign.type.cardTitleTracking)
                if let card = store.cardPresentation(for: recipe) {
                    Text("\(card.servingsLabel) · \(card.difficultyLabel.capitalized)")
                        .font(KartaDesign.FontToken.body())
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(KartaDesign.ColorToken.ink)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.reverseRowGap) {
            SectionLabel("You'll need")
            ForEach(presentation.ingredients, id: \.id) { ingredient in
                IngredientRow(ingredient: ingredient)
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.reverseRowGap) {
            SectionLabel("How to")
            ForEach(presentation.steps, id: \.number) { step in
                StepRow(step: step, suit: suit)
            }
        }
    }
}

private struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(KartaDesign.FontToken.rankUnit())
            .tracking(KartaDesign.type.rankUnitTracking)
            .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            .padding(.top, KartaDesign.space.cardGap)
    }
}

private struct IngredientRow: View {
    let ingredient: Ingredient

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: KartaDesign.space.rankGap) {
            Text(ingredient.name)
                .font(ingredient.isOptional
                    ? KartaDesign.FontToken.body()
                    : KartaDesign.FontToken.body().weight(.bold))
                .foregroundStyle(ingredient.isOptional
                    ? KartaDesign.ColorToken.inkMuted
                    : KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)

            LeaderLine(dashed: ingredient.isOptional)

            Text(ingredient.isOptional
                ? "\(ingredient.quantity) · optional"
                : ingredient.quantity)
                .font(ingredient.isOptional
                    ? KartaDesign.FontToken.body().italic()
                    : KartaDesign.FontToken.body())
                .foregroundStyle(ingredient.isOptional
                    ? KartaDesign.ColorToken.inkMuted
                    : KartaDesign.ColorToken.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LeaderLine: View {
    let dashed: Bool

    var body: some View {
        LineShape()
            .stroke(
                KartaDesign.ColorToken.inkMuted,
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: dashed ? [3, 3] : [1, 3]
                )
            )
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .offset(y: -2)
            .accessibilityHidden(true)
    }
}

private struct LineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct StepRow: View {
    let step: RecipeReverseStepPresentation
    let suit: SuitTokens

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: KartaDesign.space.chipGap) {
            Text("\(step.number)")
                .font(KartaDesign.FontToken.hint())
                .foregroundStyle(suit.chipInk)
                .frame(
                    width: KartaDesign.space.stepDisc,
                    height: KartaDesign.space.stepDisc
                )
                .background(
                    suit.chip,
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: KartaDesign.space.rankGap) {
                Text(step.summary)
                    .font(KartaDesign.FontToken.body())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if step.timerSeconds != nil || step.clipID != nil {
                    HStack(spacing: KartaDesign.space.chipGap) {
                        if let timerSeconds = step.timerSeconds {
                            StepCue(label: DurationText.format(seconds: timerSeconds), suit: suit)
                        }
                        if step.clipID != nil {
                            StepCue(label: "clip", systemImage: "play.rectangle", suit: suit)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StepCue: View {
    let label: String
    var systemImage: String?
    let suit: SuitTokens

    var body: some View {
        HStack(spacing: KartaDesign.space.rankGap) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(label)
        }
        .font(KartaDesign.FontToken.hint())
        .foregroundStyle(suit.chipInk)
        .padding(.vertical, KartaDesign.space.stepCueY)
        .padding(.horizontal, KartaDesign.space.chipX)
        .background(
            suit.chip,
            in: RoundedRectangle(
                cornerRadius: KartaDesign.radius.chip,
                style: .continuous
            )
        )
    }
}
