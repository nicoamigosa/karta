import SwiftUI

/// The cooking session's bottom sheets (*Leave cooking?*, *Alarms are off*):
/// grabber, Resumen title, Detalle body, a 56 pt brand primary and a 56 pt
/// tactile secondary, ending 16 pt above the bottom safe area over the
/// session scrim — the same sheet grammar as `CookbookFullSheet`.
struct CookingSheet: View {
    let title: String
    let bodyText: String
    let primaryLabel: String
    let secondaryLabel: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    /// Scrim tap dismisses when the sheet is modal, like the cookbook sheet.
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottom) {
            KartaDesign.ColorToken.scrim
                .ignoresSafeArea()
                .onTapGesture { onDismiss?() }
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Capsule()
                    .fill(KartaDesign.ColorToken.creamLine)
                    .frame(
                        width: KartaDesign.space.sheetHandleWidth,
                        height: KartaDesign.space.sheetHandleHeight
                    )
                    .padding(.top, KartaDesign.space.cardGap)

                Text(title)
                    .font(KartaDesign.FontToken.cookSheetTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, KartaDesign.cooking.sheetBodyGap)

                Text(bodyText)
                    .font(KartaDesign.FontToken.cookDetail())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, KartaDesign.cooking.sheetTitleGap)

                VStack(spacing: KartaDesign.cooking.sheetButtonGap) {
                    Button(primaryLabel, action: onPrimary)
                        .font(KartaDesign.FontToken.ctaLabel())
                        .foregroundStyle(KartaDesign.ColorToken.card)
                        .frame(maxWidth: .infinity)
                        .frame(height: KartaDesign.cooking.sheetButtonHeight)
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

                    Button(secondaryLabel, action: onSecondary)
                        .font(KartaDesign.FontToken.ctaLabel())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: KartaDesign.cooking.sheetButtonHeight)
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
                .padding(.top, KartaDesign.cooking.sheetBodyGap)
                .padding(.bottom, KartaDesign.cooking.sheetBottomGap)
            }
            .padding(.horizontal, KartaDesign.cooking.bottomZoneHGap)
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
