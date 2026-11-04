import SwiftUI
import KartaCore
import KartaPresentation

/// The Leftovers pill on the Card (`leftovers-deck.png`): `card` fill, a
/// 1.5 pt border and the text in the suit's `chipInk`, the bowl of the Mundo
/// menu. The text comes from the store; ` + N` is kept on one line.
struct LeftoversPill: View {
    let text: String
    let suit: SuitTokens

    private var unbreakable: String {
        text.replacingOccurrences(of: " + ", with: "\u{00A0}+\u{00A0}")
    }

    var body: some View {
        HStack(spacing: KartaDesign.space.pillGlyphGap) {
            BowlGlyph(ink: suit.chipInk)
                .frame(width: KartaDesign.space.pillGlyph, height: KartaDesign.space.pillGlyph)
            Text(unbreakable)
                .font(KartaDesign.FontToken.leftoversPill())
                .foregroundStyle(suit.chipInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, KartaDesign.space.chipY)
        .padding(.leading, KartaDesign.space.pillLeading)
        .padding(.trailing, KartaDesign.space.pillTrailing)
        .frame(maxHeight: .infinity)
        .background {
            // Fully rounded on one line; radius 24 once the text wraps.
            RoundedRectangle(cornerRadius: KartaDesign.space.pillWrappedRadius, style: .continuous)
                .fill(KartaDesign.ColorToken.card)
            RoundedRectangle(cornerRadius: KartaDesign.space.pillWrappedRadius, style: .continuous)
                .strokeBorder(suit.chipInk, lineWidth: KartaDesign.space.pillBorder)
        }
    }
}

/// The note under the title block of a reverse opened from Leftovers
/// (`leftovers-reverse-note.png`).
struct LeftoversReverseNote: View {
    let note: String
    let suit: SuitTokens

    var body: some View {
        HStack(alignment: .top, spacing: KartaDesign.space.noteX) {
            BowlGlyph(ink: suit.chipInk)
                .frame(width: KartaDesign.space.noteGlyph, height: KartaDesign.space.noteGlyph)
            Text(note)
                .font(KartaDesign.FontToken.leftoversNote())
                .lineSpacing(KartaDesign.space.noteLineSpacing)
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, KartaDesign.space.noteY)
        .padding(.horizontal, KartaDesign.space.noteX)
        .background(
            KartaDesign.ColorToken.paper,
            in: RoundedRectangle(cornerRadius: KartaDesign.space.noteRadius, style: .continuous)
        )
    }
}

/// The See toast on For You after an explicit Cocinado
/// (`leftovers-see-toast.png`): the signed toast of *Save and the cookbook*
/// with the bowl and a cream See pill. It leaves on its own after the
/// store's duration; See and the dismissal are store actions.
struct LeftoversToastView: View {
    let toast: LeftoversToast
    let onSee: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: KartaDesign.space.toastPadding) {
            BowlGlyph(ink: KartaDesign.ColorToken.card)
                .frame(width: KartaDesign.space.toastGlyph, height: KartaDesign.space.toastGlyph)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(KartaDesign.FontToken.toastTitle())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                Text(toast.line)
                    .font(KartaDesign.FontToken.toastSecondLine())
                    .foregroundStyle(KartaDesign.ColorToken.creamLine)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: KartaDesign.space.toastPadding)
            Button(toast.buttonTitle, action: onSee)
                .font(KartaDesign.FontToken.button())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .frame(height: KartaDesign.space.toastUndoHit)
                .padding(.horizontal, KartaDesign.space.saveButtonX)
                .background {
                    Capsule()
                        .fill(KartaDesign.ColorToken.mutedStroke)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Capsule()
                        .fill(KartaDesign.ColorToken.card)
                }
        }
        .padding(.vertical, KartaDesign.space.toastPadding)
        .padding(.leading, KartaDesign.space.toastLeading)
        .padding(.trailing, KartaDesign.space.toastPadding)
        .background(
            KartaDesign.ColorToken.ink,
            in: RoundedRectangle(cornerRadius: KartaDesign.space.toastRadius, style: .continuous)
        )
        .shadow(
            color: KartaDesign.ColorToken.frontShadow,
            radius: KartaDesign.elevation.frontShadowRadius,
            y: KartaDesign.elevation.buttonShadowY
        )
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            if value.translation.height < 0 { onDismiss() }
        })
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onDismiss)
        .task(id: toast) {
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}

/// The empty states of the Leftovers Mundo, in the signed form of the feed
/// header's empty states. Copy, buttons and actions come from
/// `LeftoversEmptyState`; the view only draws them.
struct LeftoversEmptyStateView: View {
    let state: LeftoversEmptyState
    let onAction: (LeftoversEmptyStateAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            icon
                .frame(width: KartaDesign.space.emptyIcon, height: KartaDesign.space.emptyIcon)
                .padding(.bottom, KartaDesign.space.onboardingGap)
            if let title = state.title {
                Text(title)
                    .font(KartaDesign.FontToken.emptyTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, KartaDesign.space.chipGap)
            }
            if let line = state.line {
                Text(line)
                    .font(KartaDesign.FontToken.emptyBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, KartaDesign.space.onboardingGap)
            }
            VStack(spacing: KartaDesign.space.ctaGap) {
                if let title = state.primaryButtonTitle,
                   let action = LeftoversEmptyStateAction.primary(for: state) {
                    BrandCTAButton(title) { onAction(action) }
                }
                if let title = state.secondaryButtonTitle,
                   let action = LeftoversEmptyStateAction.secondary(for: state) {
                    TactileCardButton(title) { onAction(action) }
                }
            }
            if let note = state.intoleranceNote {
                HStack(alignment: .top, spacing: KartaDesign.space.chipGap) {
                    ShieldGlyph(ink: KartaDesign.ColorToken.inkMuted)
                        .frame(width: KartaDesign.space.shieldHeading, height: KartaDesign.space.shieldHeading)
                        .alignmentGuide(.top) { $0[.top] + 3 }
                    Text(note)
                        .font(KartaDesign.FontToken.cupoCount())
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, KartaDesign.space.onboardingGap)
            }
        }
        .padding(.horizontal, KartaDesign.space.emptyStateX)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .noMatchForFilters:
            FilterSlidersGlyph(ink: KartaDesign.ColorToken.mutedStroke, field: KartaDesign.ColorToken.paper)
        case .noMatchForProfile:
            ShieldGlyph(ink: KartaDesign.ColorToken.mutedStroke)
        default:
            BowlGlyph(ink: KartaDesign.ColorToken.mutedStroke)
        }
    }
}

/// The hint that fades in under the deck when the last Card rebounds: the
/// store's text beside the current Mundo's 16 pt icon.
struct LastCardHintView: View {
    let hint: String
    let world: World

    var body: some View {
        HStack(spacing: KartaDesign.space.pillGlyphGap) {
            Group {
                switch world {
                case .leftovers: BowlGlyph(ink: KartaDesign.ColorToken.inkMuted)
                case .forYou: FannedCardsGlyph(ink: KartaDesign.ColorToken.inkMuted, field: KartaDesign.ColorToken.paper)
                }
            }
            .frame(width: KartaDesign.space.pillGlyph, height: KartaDesign.space.pillGlyph)
            Text(hint)
                .font(KartaDesign.FontToken.lastCardHint())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
        }
    }
}
