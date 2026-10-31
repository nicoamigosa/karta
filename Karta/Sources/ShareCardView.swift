import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// The share card of the finish card (`docs/design/karta-v1.md` →
/// *The share card*, `share-finish-card.png`): two card backs in miniature,
/// *Pass this card on* and a tactile **Share** pill under a grabber.
/// At default sizes it floats over the bottom of the Foto (`stacked = false`,
/// with swipe-down, VoiceOver *Dismiss* and the 8 s timeout owned by the
/// caller); from AX1 it is plain scroll content (`stacked = true`, the pill
/// under the message — `share-finish-card-ax1.png`) and only closes by
/// sharing or ending the session.
struct ShareCardView: View {
    let payload: SharePayload
    let course: Course
    var stacked = false
    /// Reports the card's VoiceOver focus so the caller's timeout can hold
    /// while the card is focused.
    var focused: AccessibilityFocusState<Bool>.Binding? = nil
    let onShare: () -> Void
    /// Floating layout only: swiped down, *Dismiss* or the escape gesture.
    var onDismiss: (() -> Void)? = nil

    private var suit: SuitTokens {
        KartaDesign.suit(course)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The grabber belongs to the floating card; in the AX scroll the
            // card is plain content with nothing to drag (`share-finish-card-ax1.png`).
            if !stacked {
                Capsule()
                    .fill(KartaDesign.ColorToken.line)
                    .frame(
                        width: KartaDesign.shareCard.grabberWidth,
                        height: KartaDesign.shareCard.grabberHeight
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, KartaDesign.shareCard.grabberTopGap)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .center, spacing: 0) {
                miniatureBacks
                    .accessibilityHidden(true)

                Text("Pass this card on")
                    .font(KartaDesign.FontToken.shareMessage())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .lineLimit(stacked ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, KartaDesign.shareCard.messageGap)

                if !stacked {
                    Spacer(minLength: KartaDesign.shareCard.messageGap)
                    sharePill
                }
            }
            // From AX1 the row is leading-aligned with the card's edge
            // (`share-finish-card-ax1.png`).
            .frame(maxWidth: stacked ? .infinity : nil, alignment: .leading)
            .padding(.top, KartaDesign.shareCard.padTop)

            if stacked {
                // The pill moves under the message, aligned with it.
                sharePill
                    .padding(.top, KartaDesign.shareCard.axPillGap)
                    .padding(
                        .leading,
                        KartaDesign.shareCard.miniWidth
                            + KartaDesign.shareCard.miniFrontOffset
                            + KartaDesign.shareCard.messageGap
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, KartaDesign.shareCard.padTop - KartaDesign.shareCard.grabberTopGap)
        .padding(.leading, KartaDesign.shareCard.padLeading)
        .padding(.trailing, KartaDesign.shareCard.padTrailing)
        .padding(.bottom, KartaDesign.shareCard.padBottom)
        .background {
            RoundedRectangle(
                cornerRadius: KartaDesign.shareCard.radius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.buttonEdge)
            .offset(y: KartaDesign.shareCard.edge)
            RoundedRectangle(
                cornerRadius: KartaDesign.shareCard.radius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.card)
            RoundedRectangle(
                cornerRadius: KartaDesign.shareCard.radius,
                style: .continuous
            )
            .strokeBorder(
                KartaDesign.ColorToken.line,
                lineWidth: KartaDesign.elevation.backFrameLineWidth
            )
        }
        .compositingGroup()
        .shadow(
            color: KartaDesign.ColorToken.frontShadow,
            radius: KartaDesign.elevation.frontShadowRadius,
            y: KartaDesign.elevation.frontShadowY
        )
        .modifier(ShareCardAccessibility(
            focused: focused,
            onDismiss: stacked ? nil : onDismiss
        ))
        .gesture(stacked ? nil : swipeDown)
    }

    /// Two card backs in miniature, fanned as in the deck: the back one in
    /// the suit's `edge` at −8°, the front one in `back` at +8° and 8 pt to
    /// the right, each with a 1 pt `card` inner frame 2.5 pt in.
    private var miniatureBacks: some View {
        ZStack {
            miniBack(fill: suit.edge)
                .rotationEffect(.degrees(-KartaDesign.shareCard.miniRotation))

            miniBack(fill: suit.back)
                .rotationEffect(.degrees(KartaDesign.shareCard.miniRotation))
                .offset(x: KartaDesign.shareCard.miniFrontOffset)
        }
        .frame(
            width: KartaDesign.shareCard.miniWidth
                + KartaDesign.shareCard.miniFrontOffset,
            height: KartaDesign.shareCard.miniHeight
        )
    }

    /// One miniature back: 24 × 34 with its 1 pt `card` frame drawn inside
    /// it, 2.5 pt in from the edge.
    private func miniBack(fill: Color) -> some View {
        RoundedRectangle(
            cornerRadius: KartaDesign.shareCard.miniRadius,
            style: .continuous
        )
        .fill(fill)
        .overlay {
            RoundedRectangle(
                cornerRadius: KartaDesign.shareCard.miniRadius
                    - KartaDesign.shareCard.miniFrameInset,
                style: .continuous
            )
            .strokeBorder(
                KartaDesign.ColorToken.card,
                lineWidth: KartaDesign.elevation.backFrameLineWidth
            )
            .padding(KartaDesign.shareCard.miniFrameInset)
        }
        .frame(
            width: KartaDesign.shareCard.miniWidth,
            height: KartaDesign.shareCard.miniHeight
        )
    }

    /// The tactile **Share** pill (same recipe as the reverse's buttons):
    /// `buttonEdge` under `card` with a `line` stroke.
    private var sharePill: some View {
        Button(action: onShare) {
            HStack(spacing: KartaDesign.space.saveIconGap) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(
                        size: KartaDesign.shareCard.pillIcon,
                        weight: .semibold
                    ))
                Text("Share")
                    .font(KartaDesign.FontToken.sharePillLabel())
            }
            .foregroundStyle(KartaDesign.ColorToken.ink)
            .frame(minHeight: KartaDesign.shareCard.pillHeight)
            .padding(.horizontal, KartaDesign.shareCard.pillPadX)
            .background {
                Capsule()
                    .fill(KartaDesign.ColorToken.buttonEdge)
                    .offset(y: KartaDesign.space.reverseButtonEdge)
                Capsule()
                    .fill(KartaDesign.ColorToken.card)
                Capsule()
                    .strokeBorder(
                        KartaDesign.ColorToken.line,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
            }
        }
        .accessibilityLabel("Share \(payload.title)")
        .modifier(ShareCardFocus(focused: focused))
    }

    /// A downward swipe closes the floating card without sharing.
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: KartaDesign.cooking.dragMinimumDistance)
            .onEnded { value in
                if value.translation.height > KartaDesign.cooking.swipeThreshold,
                   abs(value.translation.height) > abs(value.translation.width) {
                    onDismiss?()
                }
            }
    }
}

/// VoiceOver: the card is one focusable group with a *Dismiss* action and
/// the escape gesture (floating layout only); `focused` reports focus so
/// the caller's 8 s timeout never fires while it is focused.
private struct ShareCardAccessibility: ViewModifier {
    var focused: AccessibilityFocusState<Bool>.Binding?
    var onDismiss: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = content
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Share this recipe")
        if let onDismiss {
            base
                .accessibilityAction(named: "Dismiss") { onDismiss() }
                .accessibilityAction(.escape) { onDismiss() }
                .modifier(ShareCardFocus(focused: focused))
        } else {
            base.modifier(ShareCardFocus(focused: focused))
        }
    }
}

private struct ShareCardFocus: ViewModifier {
    var focused: AccessibilityFocusState<Bool>.Binding?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let focused {
            content.accessibilityFocused(focused)
        } else {
            content
        }
    }
}
