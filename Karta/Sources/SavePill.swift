import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// The recipe-box glyph shared by the Save pill, the cookbook door and the
/// empty states: a box with a lid and a slot — or a check once saved.
/// Drawn by hand because the save animation opens the lid and drops a small
/// card inside; no SF Symbol offers that.
struct CookbookBoxGlyph: View {
    /// 0 → lid closed, 1 → lid fully open.
    var lidOpen: CGFloat = 0
    /// Shows a small suit-coloured card dropping into the box (save animation).
    var droppingCardColor: Color?
    /// 0 → hidden, 1 → fully dropped into the box.
    var cardProgress: CGFloat = 0
    /// Draws the check inside the box instead of the slot.
    var checked = false
    /// Stroke trim of the check, for the draw-in end of the animation.
    var checkTrim: CGFloat = 1
    var ink: Color = KartaDesign.ColorToken.ink

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let stroke = side * 0.11
            let boxWidth = side * 0.66
            let boxHeight = side * 0.52
            let lidWidth = side * 0.34
            let lidHeight = side * 0.22

            ZStack {
                // The dropping card, falling in front of the open lid.
                if let droppingCardColor, cardProgress > 0 {
                    RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                        .fill(droppingCardColor)
                        .frame(width: side * 0.4, height: side * 0.3)
                        .offset(y: -side * 0.55 + cardProgress * side * 0.75)
                        .opacity(cardProgress < 0.05 ? 0 : 1)
                }

                RoundedRectangle(cornerRadius: side * 0.15, style: .continuous)
                    .stroke(ink, lineWidth: stroke)
                    .frame(width: boxWidth, height: boxHeight)
                    .offset(y: side * 0.18)
                    .overlay {
                        if checked {
                            CheckMark()
                                .trim(from: 0, to: checkTrim)
                                .stroke(ink, style: StrokeStyle(
                                    lineWidth: stroke,
                                    lineCap: .round,
                                    lineJoin: .round
                                ))
                                .frame(width: side * 0.3, height: side * 0.24)
                                .offset(y: side * 0.18)
                        } else {
                            Capsule()
                                .fill(ink)
                                .frame(width: side * 0.2, height: stroke * 0.9)
                                .offset(y: side * 0.1)
                        }
                    }

                // The lid is a small arch joined to the top of the box, as on
                // the signed-off boards; opening pivots it up on its hinge.
                RoundedRectangle(cornerRadius: side * 0.08, style: .continuous)
                    .stroke(ink, lineWidth: stroke)
                    .frame(width: lidWidth, height: lidHeight)
                    .offset(y: -side * 0.14)
                    .rotationEffect(
                        .degrees(-70 * lidOpen),
                        anchor: .leading
                    )
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// The pill on a Card's reverse (`docs/design/karta-v1.md` → *Save pill*,
/// *The shopping list* → *Adding a recipe*): unsaved it reads **Save** and
/// plays the into-the-box animation; saved it tints to the suit's `chip`
/// colours and becomes the way to the list — **Add to list** (list icon)
/// or **On your list** (check). It never unsaves: it renders
/// `RecipeReversePresentation.pillTitle` and sends `pillAction`.
struct SavePill: View {
    let recipe: Recipe
    let presentation: RecipeReversePresentation
    let store: KartaStore
    let onCookbookFull: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lidOpen: CGFloat = 0
    @State private var cardProgress: CGFloat = 0
    @State private var checkTrim: CGFloat = 0
    @State private var animating = false
    @State private var bump = false
    /// Set inside the bump so the pill tints to Saved with the spring, not
    /// after it — the spec's "tints to the saved state with a 1.07 bump".
    @State private var tintApplied = false

    private var suit: SuitTokens {
        KartaDesign.suit(recipe.primaryCourse)
    }

    private var isSaved: Bool {
        presentation.isSaved
    }

    private var tinted: Bool {
        isSaved && (tintApplied || !animating)
    }

    var body: some View {
        Button {
            if isSaved {
                // pillAction: openAdd or removeRecipe — never an unsave.
                store.send(presentation.pillAction)
            } else {
                save()
            }
        } label: {
            HStack(spacing: KartaDesign.space.saveIconGap) {
                if tinted {
                    savedGlyph
                        .frame(
                            width: KartaDesign.space.saveGlyph,
                            height: KartaDesign.space.saveGlyph
                        )
                } else {
                    CookbookBoxGlyph(
                        lidOpen: lidOpen,
                        droppingCardColor: suit.back,
                        cardProgress: cardProgress,
                        checked: false,
                        ink: KartaDesign.ColorToken.ink
                    )
                    .frame(
                        width: KartaDesign.space.saveGlyph,
                        height: KartaDesign.space.saveGlyph
                    )
                }

                Text(tinted ? presentation.pillTitle : "Save")
                    .font(KartaDesign.FontToken.button())
            }
            .foregroundStyle(tinted ? suit.chipInk : KartaDesign.ColorToken.ink)
            .padding(.horizontal, KartaDesign.space.saveButtonX)
            .frame(height: KartaDesign.space.reverseButtonHit)
            .background {
                Capsule()
                    .fill(tinted ? suit.chipEdge : KartaDesign.ColorToken.buttonEdge)
                    .offset(y: KartaDesign.space.reverseButtonEdge)
                Capsule()
                    .fill(tinted ? suit.chip : KartaDesign.ColorToken.card)
                Capsule()
                    .strokeBorder(
                        tinted ? suit.chip : KartaDesign.ColorToken.line,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
            }
            .contentShape(Capsule())
            .scaleEffect(bump ? KartaDesign.save.bumpScale : 1)
        }
        .disabled(animating)
        .accessibilityLabel(tinted ? presentation.pillTitle : "Save")
        .accessibilityHint(
            tinted
                ? (presentation.isOnList
                    ? "Takes the recipe off your shopping list"
                    : "Adds the recipe to your shopping list")
                : "Saves the recipe to your cookbook"
        )
    }

    /// The 16 pt icon inside the tinted pill: a check once the recipe is on
    /// the list, the list icon while it is not.
    @ViewBuilder
    private var savedGlyph: some View {
        if presentation.isOnList {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(suit.chipInk)
        } else {
            ShoppingListGlyph(ink: suit.chipInk)
        }
    }

    private func save() {
        if reduceMotion {
            // The saved change itself rides the animation so the pill
            // cross-fades to the list pill instead of jumping.
            withAnimation(.easeInOut(duration: KartaDesign.deck.faceRevealDuration)) {
                store.send(.saveRecipe(recipe.id))
            }
            if SaveTap.effect(of: store.state.lastSaveResult) == .cookbookFull {
                onCookbookFull()
            }
            return
        }
        store.send(.saveRecipe(recipe.id))
        switch SaveTap.effect(of: store.state.lastSaveResult) {
        case .cookbookFull:
            // The pill keeps its default look; the sheet does the talking.
            onCookbookFull()
        case .saved:
            playSaveAnimation()
        case .none:
            break
        }
    }

    private func playSaveAnimation() {
        animating = true
        typealias timeline = KartaDesign.save
        withAnimation(.easeInOut(duration: timeline.lidOpenDuration)) {
            lidOpen = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeline.cardDropDelay))
            withAnimation(.easeIn(duration: timeline.cardDropDuration)) {
                cardProgress = 1
            }
            try? await Task.sleep(for: .seconds(
                timeline.lidCloseDelay - timeline.cardDropDelay
            ))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: timeline.lidCloseDuration)) {
                lidOpen = 0
            }
            try? await Task.sleep(for: .seconds(
                timeline.savedSwapDelay - timeline.lidCloseDelay
            ))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bump = true
                tintApplied = true
            }
            try? await Task.sleep(for: .seconds(
                timeline.checkDrawDelay - timeline.savedSwapDelay
            ))
            withAnimation(.easeOut(duration: timeline.checkDrawDuration)) {
                checkTrim = 1
            }
            try? await Task.sleep(for: .seconds(
                timeline.duration - timeline.checkDrawDelay
            ))
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                bump = false
            }
            cardProgress = 0
            animating = false
        }
    }
}
