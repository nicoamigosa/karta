import SwiftUI
import KartaCore
import KartaPresentation

/// K3 grown into the paywall (`docs/design/karta-v1.md` → *The paywall*:
/// "keeps the same sheet, which grows to fit the paywall"). One sheet — the
/// card-back fan and the count keep their identity (the fan only eases to
/// the paywall's scale) while the rest of the content cross-fades from the
/// cookbook-full copy into the plans, and the container height animates.
/// Closing the paywall from this entry discards K3's save intent with it:
/// the sheet is gone entirely, so the reverse below shows bare again.
struct CapSheet: View {
    /// K3's content (what `store.blockedByCap` projects); nil only when the
    /// cap paywall opened without K3 on screen, which never renders it.
    let presentation: CookbookFullPresentation?
    /// The cap-entry paywall once the store opens it; nil while K3 shows.
    let paywall: Paywall?
    let store: KartaStore
    let premium: PremiumController
    /// Unlock unlimited cookbook → opens the cap-entry paywall.
    let onUnlock: () -> Void
    /// Drops the whole sheet (K3's Not now/scrim/swipe — and the paywall's
    /// close, which carries the save intent away too).
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            KartaDesign.ColorToken.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)

            VStack(spacing: KartaDesign.paywall.grabberGap) {
                Capsule()
                    .fill(KartaDesign.ColorToken.creamLine)
                    .frame(
                        width: KartaDesign.space.sheetHandleWidth,
                        height: KartaDesign.space.sheetHandleHeight
                    )
                    .padding(.top, KartaDesign.space.cardGap)
                    // K3 keeps its 18 pt block rhythm; the grown paywall
                    // runs at the paywall's 14 pt gap.
                    .padding(.bottom, paywall == nil
                             ? KartaDesign.space.cookbookBlockGap - KartaDesign.paywall.grabberGap
                             : 0)

                if let paywall, paywall.phase == .welcome {
                    WelcomeView(paywall: paywall, onDone: dismiss)
                        .transition(.opacity)
                } else {
                    // Fan and count keep the same identity across the
                    // growth: the fan only eases to the paywall's scale and
                    // the count slides up under it when K3's title leaves.
                    CardBacksFan(
                        scale: paywall != nil ? KartaDesign.paywall.fanScale : 1
                    )

                    if paywall == nil {
                        Text("Your cookbook is full")
                            .font(KartaDesign.FontToken.cardTitle())
                            .foregroundStyle(KartaDesign.ColorToken.ink)
                            .padding(.vertical, KartaDesign.space.cookbookBlockGap - KartaDesign.paywall.grabberGap)
                            .transition(.opacity)
                    }

                    Text(paywall?.countLabel ?? presentation?.countLabel ?? "")
                        .font(paywall != nil
                              ? KartaDesign.FontToken.paywallCount()
                              : KartaDesign.FontToken.sheetCount())
                        .tracking(paywall != nil ? 2 : KartaDesign.type.rankUnitTracking)
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)

                    ZStack {
                        if let paywall {
                            PaywallSheetContent(
                                paywall: paywall,
                                store: store,
                                premium: premium,
                                showsHeader: false,
                                onClose: dismiss
                            )
                            .transition(.opacity)
                        } else if let presentation {
                            CookbookFullContent(
                                presentation: presentation,
                                showsHeader: false,
                                onUnlock: onUnlock,
                                onDismiss: onDismiss
                            )
                            .padding(.horizontal, KartaDesign.space.screenX)
                            .padding(.top, KartaDesign.space.cookbookBlockGap - KartaDesign.paywall.grabberGap)
                            .transition(.opacity)
                        }
                    }
                }
            }
            .padding(.bottom, paywall != nil
                     ? KartaDesign.paywall.bottomGap
                     : KartaDesign.space.cardBottom)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: KartaDesign.space.sheetTopRadius,
                    topTrailingRadius: KartaDesign.space.sheetTopRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                .ignoresSafeArea(edges: .bottom)
            }
            // Swiping the sheet down closes it like Not now.
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height > 60 { dismiss() }
            })
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeOut(duration: 0.3), value: paywall != nil)
        .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        if let paywall {
            guard paywall.canClose else { return }
            store.send(.paywall(.close))
        }
        onDismiss()
    }
}
