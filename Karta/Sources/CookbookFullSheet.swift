import SwiftUI
import KartaCore
import KartaPresentation

/// The upgrade invitation shown when a save hits the free-tier Cupo
/// (`docs/design/karta-v1.md` → *Save with the cookbook full*, board *K3*):
/// a fan of seven card backs in the suit colours over a scrim. The Unlock
/// button calls the paywall hook; the paywall itself is #14.
struct CookbookFullSheet: View {
    let presentation: CookbookFullPresentation
    let onUnlock: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            KartaDesign.ColorToken.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: KartaDesign.space.cookbookBlockGap) {
                Capsule()
                    .fill(KartaDesign.ColorToken.creamLine)
                    .frame(
                        width: KartaDesign.space.sheetHandleWidth,
                        height: KartaDesign.space.sheetHandleHeight
                    )
                    .padding(.top, KartaDesign.space.cardGap)

                CardBacksFan()

                Text("Your cookbook is full")
                    .font(KartaDesign.FontToken.cardTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)

                Text(presentation.countLabel)
                    .font(KartaDesign.FontToken.sheetCount())
                    .tracking(KartaDesign.type.rankUnitTracking)
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)

                Text(presentation.explanation)
                    .font(KartaDesign.FontToken.sheetBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)

                Button(action: onUnlock) {
                    Text("Unlock unlimited cookbook")
                        .font(KartaDesign.FontToken.ctaLabel())
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

                Button("Not now", action: onDismiss)
                    .font(KartaDesign.FontToken.button())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: KartaDesign.space.notNowHit)
                    .background {
                        RoundedRectangle(
                            cornerRadius: KartaDesign.radius.cta,
                            style: .continuous
                        )
                        .fill(KartaDesign.ColorToken.buttonEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                        RoundedRectangle(
                            cornerRadius: KartaDesign.radius.cta,
                            style: .continuous
                        )
                        .fill(KartaDesign.ColorToken.card)
                        RoundedRectangle(
                            cornerRadius: KartaDesign.radius.cta,
                            style: .continuous
                        )
                        .strokeBorder(
                            KartaDesign.ColorToken.line,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                    }
            }
            .padding(.horizontal, KartaDesign.space.screenX)
            .padding(.bottom, KartaDesign.space.cardBottom)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: KartaDesign.space.sheetTopRadius,
                    topTrailingRadius: KartaDesign.space.sheetTopRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.isModal)
    }
}
