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

                    Button {
                        store.send(.startCooking(
                            recipe,
                            startedAt: Date().timeIntervalSince1970
                        ))
                    } label: {
                        HStack(spacing: KartaDesign.space.ctaGap) {
                            Text("Start cooking")
                                .font(KartaDesign.FontToken.ctaLabel())
                            Image(systemName: "arrow.right")
                                .font(.system(
                                    size: KartaDesign.space.ctaGlyph,
                                    weight: .bold
                                ))
                        }
                        .foregroundStyle(KartaDesign.ColorToken.card)
                        .frame(maxWidth: .infinity)
                        .frame(height: KartaDesign.space.ctaHeight)
                        .background {
                            RoundedRectangle(
                                cornerRadius: KartaDesign.radius.cta,
                                style: .continuous
                            )
                            .fill(KartaDesign.ColorToken.brandEdge)
                            .offset(y: KartaDesign.space.ctaEdge)
                            RoundedRectangle(
                                cornerRadius: KartaDesign.radius.cta,
                                style: .continuous
                            )
                            .fill(KartaDesign.ColorToken.brand)
                        }
                        .shadow(
                            color: KartaDesign.ColorToken.buttonShadow,
                            radius: KartaDesign.elevation.buttonShadowRadius,
                            y: KartaDesign.elevation.buttonShadowY
                        )
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
                        .font(.system(
                            size: KartaDesign.space.reverseCloseGlyph,
                            weight: .bold
                        ))
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .frame(
                            width: KartaDesign.space.reverseButtonHit,
                            height: KartaDesign.space.reverseButtonHit
                        )
                        .reverseChrome(circle: true)
                }
                .accessibilityLabel("Back to feed")

                Spacer()

                Button {
                    store.send(isSaved ? .unsaveRecipe(recipe.id) : .saveRecipe(recipe.id))
                } label: {
                    HStack(spacing: KartaDesign.space.saveIconGap) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: KartaDesign.space.saveGlyph))
                        Text(isSaved ? "Saved" : "Save")
                            .font(KartaDesign.FontToken.button())
                    }
                    .foregroundStyle(
                        saveBlocked
                            ? KartaDesign.ColorToken.inkMuted
                            : KartaDesign.ColorToken.ink
                    )
                    .padding(.horizontal, KartaDesign.space.saveButtonX)
                    .frame(height: KartaDesign.space.reverseButtonHit)
                    .reverseChrome(circle: false)
                }
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
                    ? KartaDesign.FontToken.stepText()
                    : KartaDesign.FontToken.rowName())
                .foregroundStyle(ingredient.isOptional
                    ? KartaDesign.ColorToken.inkMuted
                    : KartaDesign.ColorToken.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            LeaderLine(dashed: ingredient.isOptional)

            Text(ingredient.isOptional
                ? "\(ingredient.quantity) · optional"
                : ingredient.quantity)
                .font(ingredient.isOptional
                    ? KartaDesign.FontToken.rowQuantity().italic()
                    : KartaDesign.FontToken.rowQuantity())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .lineLimit(1)
                .fixedSize()
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
            .frame(minWidth: KartaDesign.space.leaderMin)
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
        HStack(alignment: .top, spacing: KartaDesign.space.chipGap) {
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

            FlowLayout(spacing: 0, rowSpacing: KartaDesign.space.stepLeading) {
                ForEach(Array(step.summary.split(
                    separator: " ",
                    omittingEmptySubsequences: true
                ).enumerated()), id: \.offset) { _, word in
                    Text(String(word) + " ")
                        .font(KartaDesign.FontToken.stepText())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                }

                if step.timerSeconds != nil || step.clipID != nil {
                    HStack(spacing: KartaDesign.space.rankGap) {
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

/// A row of word views plus cue chips that wraps like text: the cues follow
/// the last word on the same line when they fit, or start the next line.
private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y + (rowHeight == 0 ? 0 : (rowHeight - size.height) / 2)),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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

/// The tactile pill/circle chrome of the mock's ✕ and Save buttons: card fill,
/// 1 pt `line` border and a solid 2 pt `buttonEdge` bottom rim.
private struct ReverseChrome: ViewModifier {
    let circle: Bool

    func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if circle {
                        Circle()
                            .fill(KartaDesign.ColorToken.buttonEdge)
                            .offset(y: KartaDesign.space.reverseButtonEdge)
                        Circle().fill(KartaDesign.ColorToken.card)
                        Circle().strokeBorder(
                            KartaDesign.ColorToken.line,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                    } else {
                        Capsule()
                            .fill(KartaDesign.ColorToken.buttonEdge)
                            .offset(y: KartaDesign.space.reverseButtonEdge)
                        Capsule().fill(KartaDesign.ColorToken.card)
                        Capsule().strokeBorder(
                            KartaDesign.ColorToken.line,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                    }
                }
            }
            .contentShape(circle ? AnyShape(Circle()) : AnyShape(Capsule()))
    }
}

private extension View {
    func reverseChrome(circle: Bool) -> some View {
        modifier(ReverseChrome(circle: circle))
    }
}
