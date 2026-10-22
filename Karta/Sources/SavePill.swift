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
            let stroke = side * 0.105
            let boxWidth = side * 0.78
            let boxHeight = side * 0.62
            let lidWidth = side * 0.92
            let lidHeight = side * 0.24

            ZStack {
                // The dropping card, falling in front of the open lid.
                if let droppingCardColor, cardProgress > 0 {
                    RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                        .fill(droppingCardColor)
                        .frame(width: side * 0.4, height: side * 0.3)
                        .offset(y: -side * 0.55 + cardProgress * side * 0.75)
                        .opacity(cardProgress < 0.05 ? 0 : 1)
                }

                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .stroke(ink, lineWidth: stroke)
                    .frame(width: boxWidth, height: boxHeight)
                    .offset(y: side * 0.17)
                    .overlay {
                        if checked {
                            CheckMark()
                                .trim(from: 0, to: checkTrim)
                                .stroke(ink, style: StrokeStyle(
                                    lineWidth: stroke,
                                    lineCap: .round,
                                    lineJoin: .round
                                ))
                                .frame(width: side * 0.34, height: side * 0.26)
                                .offset(y: side * 0.17)
                        } else {
                            Capsule()
                                .fill(ink)
                                .frame(width: side * 0.26, height: stroke)
                                .offset(y: side * 0.08)
                        }
                    }

                RoundedRectangle(cornerRadius: side * 0.1, style: .continuous)
                    .stroke(ink, lineWidth: stroke)
                    .frame(width: lidWidth, height: lidHeight)
                    .offset(y: -side * 0.3)
                    .rotationEffect(
                        .degrees(-60 * lidOpen),
                        anchor: .leading
                    )
                    .offset(x: -side * 0.46)
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

/// The Save pill on a Card's reverse: default, saved (suit `chip` tint) and
/// the "into the box" save animation — the only place Save lives
/// (`docs/design/karta-v1.md` → *Save pill*, *Save animation*). The pill only
/// sends `.saveRecipe` / `.unsaveRecipe`; the store owns the rules.
struct SavePill: View {
    let recipe: Recipe
    let store: KartaStore
    let onUnsave: () -> Void
    let onCookbookFull: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lidOpen: CGFloat = 0
    @State private var cardProgress: CGFloat = 0
    @State private var checkTrim: CGFloat = 0
    @State private var animating = false
    @State private var bump = false

    private var suit: SuitTokens {
        KartaDesign.suit(recipe.primaryCourse)
    }

    private var isSaved: Bool {
        store.cookbook.isSaved(recipe.id)
    }

    private var tinted: Bool {
        isSaved && !animating
    }

    var body: some View {
        Button {
            if isSaved {
                unsave()
            } else {
                save()
            }
        } label: {
            HStack(spacing: KartaDesign.space.saveIconGap) {
                CookbookBoxGlyph(
                    lidOpen: lidOpen,
                    droppingCardColor: suit.back,
                    cardProgress: cardProgress,
                    checked: tinted || checkTrim > 0,
                    checkTrim: tinted ? 1 : checkTrim,
                    ink: tinted ? suit.chipInk : KartaDesign.ColorToken.ink
                )
                .frame(width: KartaDesign.space.saveGlyph, height: KartaDesign.space.saveGlyph)

                Text(tinted ? "Saved" : "Save")
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
        .accessibilityLabel(tinted ? "Saved" : "Save")
        .accessibilityHint(
            tinted
                ? "Removes the recipe from your cookbook"
                : "Saves the recipe to your cookbook"
        )
    }

    private func save() {
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

    private func unsave() {
        // Instant, no animation: the pill goes back to Save at once.
        lidOpen = 0
        cardProgress = 0
        checkTrim = 0
        store.send(.unsaveRecipe(recipe.id))
        onUnsave()
    }

    private func playSaveAnimation() {
        guard !reduceMotion else {
            // Reduce Motion: cross-fade straight to the saved state.
            animating = false
            withAnimation(.easeInOut(duration: KartaDesign.deck.faceRevealDuration)) {
                checkTrim = 1
            }
            return
        }

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
