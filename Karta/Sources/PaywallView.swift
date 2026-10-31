import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// The fan of seven card backs in the suit colours, shared by the
/// cookbook-full sheet (scale 1) and the paywall (90 %).
struct CardBacksFan: View {
    var scale: CGFloat = 1

    /// Seven card backs cycling the four suits, like the PNG's fan.
    private let fanSuits: [Course] = [
        .dinner, .lunch, .breakfast, .dinner, .dessert, .lunch, .dinner
    ]

    var body: some View {
        HStack(spacing: -KartaDesign.space.rankGap) {
            ForEach(Array(fanSuits.enumerated()), id: \.offset) { index, course in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(KartaDesign.suit(course).back)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(
                                KartaDesign.ColorToken.card,
                                lineWidth: KartaDesign.elevation.backFrameLineWidth
                            )
                            .padding(3)
                    }
                    .frame(
                        width: KartaDesign.space.fanCardWidth,
                        height: KartaDesign.space.fanCardHeight
                    )
                    .rotationEffect(.degrees(Double(index - 3) * 6))
                    .offset(y: abs(index - 3) > 0 ? 2 : 0)
                    .zIndex(-Double(abs(index - 3)))
            }
        }
        .frame(height: KartaDesign.space.fanCardHeight + 8)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

/// The 18 pt "list" icon of the Shopping list paywall feature: two checks
/// with their lines, drawn like the other shell glyphs.
struct ListGlyph: View {
    var ink: Color = KartaDesign.ColorToken.ink

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let stroke = side * 0.11
            Canvas { context, size in
                for row in 0..<2 {
                    let y = size.height * (0.28 + 0.4 * CGFloat(row))
                    var check = Path()
                    check.move(to: CGPoint(x: size.width * 0.06, y: y))
                    check.addLine(to: CGPoint(x: size.width * 0.16, y: y + size.height * 0.1))
                    check.addLine(to: CGPoint(x: size.width * 0.34, y: y - size.height * 0.1))
                    context.stroke(check, with: .color(ink), style: StrokeStyle(
                        lineWidth: stroke, lineCap: .round, lineJoin: .round))
                    var line = Path()
                    line.move(to: CGPoint(x: size.width * 0.46, y: y + stroke / 2))
                    line.addLine(to: CGPoint(x: size.width * 0.94, y: y + stroke / 2))
                    context.stroke(line, with: .color(ink), style: StrokeStyle(
                        lineWidth: stroke, lineCap: .round))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The paywall sheet (`docs/design/karta-v1.md` → *The paywall*): the same
/// bottom sheet the cookbook-full sheet grows into — the fan and the count
/// stay, the rest of the content is the signed contract's projection. All
/// copy, plan order, button titles, notes and states come from `Paywall`;
/// StoreKit answers arrive through `PremiumController`. Never an alert.
struct PaywallView: View {
    let paywall: Paywall
    let store: KartaStore
    let premium: PremiumController

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            KartaDesign.ColorToken.scrim
                .ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityHidden(true)

            VStack(spacing: KartaDesign.paywall.grabberGap) {
                Capsule()
                    .fill(KartaDesign.ColorToken.creamLine)
                    .frame(
                        width: KartaDesign.paywall.grabberWidth,
                        height: KartaDesign.paywall.grabberHeight
                    )
                    .padding(.top, KartaDesign.paywall.topPadding)

                if paywall.phase == .welcome {
                    WelcomeView(paywall: paywall, onDone: { close() })
                } else {
                    content
                }
            }
            .padding(.bottom, KartaDesign.paywall.bottomGap)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: KartaDesign.paywall.topRadius,
                    topTrailingRadius: KartaDesign.paywall.topRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                .ignoresSafeArea(edges: .bottom)
            }
            // Swiping the sheet down closes it like Not now.
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height > 60 { close() }
            })
        }
        .accessibilityAddTraits(.isModal)
    }

    /// Scrolling content (fan, count, title, features, plans) over the
    /// pinned button/renewal/footer: they must stay visible at larger text
    /// sizes (see *Open decisions* in the PR).
    private var content: some View {
        VStack(spacing: KartaDesign.paywall.blockGap) {
            ScrollView {
                VStack(spacing: KartaDesign.paywall.blockGap) {
                    CardBacksFan(scale: KartaDesign.paywall.fanScale)

                    Text(paywall.countLabel)
                        .font(KartaDesign.FontToken.paywallCount())
                        .tracking(2)
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)

                    Text(paywall.title)
                        .font(KartaDesign.FontToken.paywallTitle())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .multilineTextAlignment(.center)

                    VStack(spacing: KartaDesign.paywall.featureGap) {
                        ForEach(Array(Paywall.features.enumerated()), id: \.offset) { _, feature in
                            featureRow(feature)
                        }
                    }

                    VStack(spacing: KartaDesign.paywall.planGap) {
                        ForEach(paywall.plans, id: \.plan) { product in
                            planRow(product)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let badge = paywall.savingsBadge {
                            Text(badge)
                                .font(KartaDesign.FontToken.paywallBadge())
                                .tracking(1)
                                .foregroundStyle(KartaDesign.ColorToken.card)
                                .padding(.vertical, KartaDesign.paywall.badgePadY)
                                .padding(.horizontal, KartaDesign.paywall.badgePadX)
                                .background(
                                    KartaDesign.ColorToken.brand,
                                    in: RoundedRectangle(
                                        cornerRadius: KartaDesign.paywall.badgeRadius,
                                        style: .continuous
                                    )
                                )
                                .padding(.trailing, KartaDesign.paywall.badgeTrailing)
                                .offset(y: -KartaDesign.paywall.badgePadY - 8)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .opacity(paywall.isDisabled ? KartaDesign.paywall.disabledOpacity : 1)

            if let note = paywall.note {
                Text(note)
                    .font(KartaDesign.FontToken.paywallNote())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, KartaDesign.paywall.notePadY)
                    .padding(.horizontal, KartaDesign.paywall.notePadX)
                    .frame(maxWidth: .infinity)
                    .background(
                        KartaDesign.ColorToken.paper,
                        in: RoundedRectangle(
                            cornerRadius: KartaDesign.paywall.noteRadius,
                            style: .continuous
                        )
                    )
                    .opacity(paywall.isDisabled ? KartaDesign.paywall.disabledOpacity : 1)
            }

            primaryButton

            if let renewalLine = paywall.renewalLine {
                Text(renewalLine)
                    .font(KartaDesign.FontToken.paywallRenewal())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)
                    .opacity(paywall.isDisabled ? KartaDesign.paywall.disabledOpacity : 1)
            }

            footer
                .opacity(paywall.isDisabled ? KartaDesign.paywall.disabledOpacity : 1)
        }
        .padding(.horizontal, KartaDesign.paywall.sidePadding)
    }

    private func featureRow(_ feature: Paywall.Feature) -> some View {
        HStack(alignment: .top, spacing: KartaDesign.paywall.featureGap + 2) {
            featureIcon(feature)
                .frame(
                    width: KartaDesign.paywall.featureIcon,
                    height: KartaDesign.paywall.featureIcon
                )
                .frame(
                    width: KartaDesign.paywall.featureCircle,
                    height: KartaDesign.paywall.featureCircle
                )
                .background {
                    if feature == .freeForGood {
                        Circle().strokeBorder(
                            KartaDesign.ColorToken.line,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    } else {
                        Circle().fill(KartaDesign.ColorToken.paper)
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                Text(feature.title)
                    .font(KartaDesign.FontToken.paywallFeatureName())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                Text(feature.detail)
                    .font(KartaDesign.FontToken.paywallFeatureDetail())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func featureIcon(_ feature: Paywall.Feature) -> some View {
        switch feature {
        case .unlimitedCookbook:
            CookbookBoxGlyph(ink: KartaDesign.ColorToken.ink)
        case .shoppingList:
            ListGlyph(ink: KartaDesign.ColorToken.ink)
        case .freeForGood:
            ShieldGlyph(ink: KartaDesign.ColorToken.ink)
        }
    }

    private func planRow(_ product: Paywall.Product) -> some View {
        let selected = paywall.selectedPlan == product.plan
        return Button {
            store.send(.paywall(.selectPlan(product.plan)))
        } label: {
            HStack(spacing: KartaDesign.paywall.planGapBetween) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.line,
                            lineWidth: selected ? 2 : 1.5
                        )
                    if selected {
                        Circle().fill(KartaDesign.ColorToken.ink)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(KartaDesign.ColorToken.card)
                    }
                }
                .frame(
                    width: KartaDesign.paywall.planRadio,
                    height: KartaDesign.paywall.planRadio
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(product.name)
                        .font(KartaDesign.FontToken.paywallPlanName())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                    Text(product.detail)
                        .font(KartaDesign.FontToken.paywallPlanDetail())
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(KartaDesign.FontToken.paywallPlanPrice())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                    Text(product.period)
                        .font(KartaDesign.FontToken.paywallPlanPeriod())
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                }
            }
            .padding(.horizontal, KartaDesign.paywall.planPadding)
            .frame(height: KartaDesign.paywall.planHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: KartaDesign.paywall.planRadius,
                    style: .continuous
                )
                .fill(selected ? KartaDesign.ColorToken.inkEdge : KartaDesign.ColorToken.buttonEdge)
                .offset(y: KartaDesign.space.reverseButtonEdge)
                RoundedRectangle(
                    cornerRadius: KartaDesign.paywall.planRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                RoundedRectangle(
                    cornerRadius: KartaDesign.paywall.planRadius,
                    style: .continuous
                )
                .strokeBorder(
                    selected ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.line,
                    lineWidth: selected ? 2 : 1
                )
            }
            .contentShape(RoundedRectangle(
                cornerRadius: KartaDesign.paywall.planRadius,
                style: .continuous
            ))
        }
        .buttonStyle(.plain)
        .disabled(paywall.isDisabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var primaryButton: some View {
        Button {
            switch paywall.phase {
            case .ready, .failed:
                Task { await premium.purchase() }
            case .pending, .welcome:
                close()
            case .buying, .restoring:
                break
            }
        } label: {
            HStack(spacing: KartaDesign.space.ctaGap) {
                if paywall.isDisabled {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(KartaDesign.ColorToken.card)
                        .controlSize(.small)
                }
                if let title = paywall.buttonTitle {
                    Text(title)
                        .font(KartaDesign.FontToken.ctaLabel())
                }
            }
            .foregroundStyle(paywall.phase == .pending
                             ? KartaDesign.ColorToken.ink
                             : KartaDesign.ColorToken.card)
            .frame(maxWidth: .infinity)
            .frame(height: KartaDesign.space.ctaHeight)
            .background {
                if paywall.phase == .pending {
                    // The tactile Close of Ask to Buy.
                    RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                        .fill(KartaDesign.ColorToken.buttonEdge)
                        .offset(y: KartaDesign.space.ctaEdge)
                    RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                        .fill(KartaDesign.ColorToken.card)
                    RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                        .strokeBorder(
                            KartaDesign.ColorToken.line,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                } else {
                    RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                        .fill(KartaDesign.ColorToken.brandEdge)
                        .offset(y: KartaDesign.space.ctaEdge)
                    RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                        .fill(KartaDesign.ColorToken.brand)
                }
            }
            .shadow(
                color: KartaDesign.ColorToken.buttonShadow,
                radius: KartaDesign.elevation.buttonShadowRadius,
                y: KartaDesign.elevation.buttonShadowY
            )
        }
        .disabled(paywall.isDisabled || paywall.buttonTitle == nil)
        .accessibilityLabel(paywall.buttonTitle ?? "")
    }

    private var footer: some View {
        HStack(spacing: 0) {
            footerLink(Paywall.FooterLink.restorePurchases) { Task { await premium.restore() } }
            separator
            footerLink(Paywall.FooterLink.termsOfUse) { openURL(PremiumLinks.termsOfUse) }
            separator
            footerLink(Paywall.FooterLink.privacyPolicy) { openURL(PremiumLinks.privacyPolicy) }
        }
        .accessibilityElement(children: .contain)
    }

    private func footerLink(
        _ link: Paywall.FooterLink,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(link.title)
                .font(KartaDesign.FontToken.paywallFooter())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .underline(color: KartaDesign.ColorToken.line)
        }
        .disabled(paywall.isDisabled)
    }

    private var separator: some View {
        Text(" · ")
            .font(KartaDesign.FontToken.paywallFooter())
            .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            .accessibilityHidden(true)
    }

    private func close() {
        guard paywall.canClose else { return }
        store.send(.paywall(.close))
    }
}

/// Purchase done (`premium-welcome.png`): the falling card backs, the circle
/// bump and the success haptic in ~1.2 s; with Reduce Motion the final frame
/// fades in. All copy comes from the contract.
struct WelcomeView: View {
    let paywall: Paywall
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Progress of the celebration: 0 → cards above, 1 → landed.
    @State private var landed = false

    /// Deterministic landing spots around the circle, like the board's
    /// scatter of ~20 card backs in the four suits' back colours.
    private let cards: [(course: Course, x: CGFloat, y: CGFloat, spin: Double)] = [
        (.dinner, -140, -68, -24), (.lunch, -118, -78, 14), (.dessert, -92, -30, -30),
        (.lunch, -72, 42, 20), (.dinner, -96, 74, -14), (.breakfast, -60, 88, 26),
        (.dessert, -28, 96, -18), (.lunch, 8, 104, 8), (.dinner, 120, 76, 22),
        (.breakfast, 96, 62, -20), (.dessert, 132, 40, 16), (.lunch, 148, -30, -12),
        (.dinner, 118, -66, 28), (.lunch, 88, -88, -16), (.dessert, 52, -98, 24),
        (.lunch, 12, -100, -8), (.breakfast, -46, -96, 18), (.dinner, -150, 20, -26),
        (.dessert, -36, -34, 30), (.breakfast, 60, -20, -10)
    ]

    var body: some View {
        VStack(spacing: KartaDesign.paywall.blockGap) {
            ZStack {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    RoundedRectangle(
                        cornerRadius: KartaDesign.paywall.welcomeCardRadius,
                        style: .continuous
                    )
                    .fill(KartaDesign.suit(card.course).back)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: KartaDesign.paywall.welcomeCardRadius,
                            style: .continuous
                        )
                        .stroke(
                            KartaDesign.ColorToken.card,
                            lineWidth: KartaDesign.paywall.welcomeCardFrame
                        )
                        .padding(1.5)
                    }
                    .frame(
                        width: KartaDesign.paywall.welcomeCardWidth,
                        height: KartaDesign.paywall.welcomeCardHeight
                    )
                    .rotationEffect(.degrees(landed ? card.spin : card.spin + 90))
                    .offset(
                        x: card.x,
                        y: landed ? card.y : card.y - 160
                    )
                    .opacity(landed ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: KartaDesign.paywall.welcomeDuration)
                            .delay(Double(index) * 0.02),
                        value: landed
                    )
                }

                Circle()
                    .fill(KartaDesign.ColorToken.brandEdge)
                    .offset(y: 4)
                    .overlay {
                        Circle()
                            .fill(KartaDesign.ColorToken.brand)
                        CookbookBoxGlyph(
                            checked: true,
                            ink: KartaDesign.ColorToken.card
                        )
                        .padding(KartaDesign.paywall.welcomeIcon / 2.4)
                    }
                    .frame(
                        width: KartaDesign.paywall.welcomeCircle,
                        height: KartaDesign.paywall.welcomeCircle
                    )
                    .shadow(
                        color: KartaDesign.ColorToken.buttonShadow,
                        radius: KartaDesign.elevation.buttonShadowRadius,
                        y: KartaDesign.elevation.buttonShadowY
                    )
                    .scaleEffect(landed ? KartaDesign.save.bumpScale : 0.6)
                    .animation(
                        reduceMotion ? nil : .spring(
                            response: KartaDesign.paywall.welcomeDuration * 0.5,
                            dampingFraction: 0.55
                        ),
                        value: landed
                    )
            }
            .frame(height: KartaDesign.paywall.welcomeBandHeight)
            .opacity(landed ? 1 : (reduceMotion ? 0 : 1))

            Text(paywall.title)
                .font(KartaDesign.FontToken.welcomeTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .multilineTextAlignment(.center)

            if let message = paywall.message {
                Text(message)
                    .font(KartaDesign.FontToken.sheetBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDone) {
                Text(paywall.buttonTitle ?? "")
                    .font(KartaDesign.FontToken.ctaLabel())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                    .frame(maxWidth: .infinity)
                    .frame(height: KartaDesign.space.ctaHeight)
                    .background {
                        RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                            .fill(KartaDesign.ColorToken.brandEdge)
                            .offset(y: KartaDesign.space.ctaEdge)
                        RoundedRectangle(cornerRadius: KartaDesign.radius.cta, style: .continuous)
                            .fill(KartaDesign.ColorToken.brand)
                    }
                    .shadow(
                        color: KartaDesign.ColorToken.buttonShadow,
                        radius: KartaDesign.elevation.buttonShadowRadius,
                        y: KartaDesign.elevation.buttonShadowY
                    )
            }
            .accessibilityLabel(paywall.buttonTitle ?? "")
        }
        .padding(.horizontal, KartaDesign.paywall.sidePadding)
        .task {
            // Reduce Motion: the final frame simply fades in; otherwise the
            // cards fall and spin while the circle bumps and lands.
            if reduceMotion {
                withAnimation(.easeIn(duration: KartaDesign.paywall.welcomeDuration / 3)) {
                    landed = true
                }
            } else {
                landed = true
            }
            try? await Task.sleep(for: .seconds(KartaDesign.paywall.welcomeDuration))
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// Restore found nothing (`premium-paywall-restore-empty.png`): the signed
/// toast with no pill at the top of the screen — ink fill, "Nothing to
/// restore" over "No Karta subscription on this Apple ID".
struct RestoreToastView: View {
    let toast: RestoreToast
    let onExpire: () -> Void

    var body: some View {
        HStack(spacing: KartaDesign.space.toastPadding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(KartaDesign.FontToken.toastTitle())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                Text(toast.secondLine)
                    .font(KartaDesign.FontToken.toastSecondLine())
                    .foregroundStyle(KartaDesign.ColorToken.creamLine)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, KartaDesign.space.toastPadding)
        .padding(.leading, KartaDesign.space.toastLeading)
        .padding(.trailing, KartaDesign.space.toastPadding)
        .background(
            KartaDesign.ColorToken.ink,
            in: RoundedRectangle(
                cornerRadius: KartaDesign.space.toastRadius,
                style: .continuous
            )
        )
        .shadow(
            color: KartaDesign.ColorToken.frontShadow,
            radius: KartaDesign.elevation.frontShadowRadius,
            y: KartaDesign.elevation.buttonShadowY
        )
        .accessibilityElement(children: .combine)
        .task(id: toast) {
            try? await Task.sleep(for: .seconds(KartaDesign.space.toastDuration))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}

/// The one-time toast after the sixth save (`premium-save-toast.png`): the
/// Undo toast's shape with a cream **See plans** pill in place of Undo.
/// Tapping it opens the paywall; expiry or the tap dismisses the toast.
struct SaveToastView: View {
    let toast: SaveToast
    let onSeePlans: () -> Void
    let onExpire: () -> Void

    var body: some View {
        HStack(spacing: KartaDesign.space.toastPadding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(KartaDesign.FontToken.toastTitle())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                Text(toast.secondLine)
                    .font(KartaDesign.FontToken.toastSecondLine())
                    .foregroundStyle(KartaDesign.ColorToken.creamLine)
            }
            Spacer(minLength: KartaDesign.space.toastPadding)
            Button(toast.action.title, action: onSeePlans)
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
            in: RoundedRectangle(
                cornerRadius: KartaDesign.space.toastRadius,
                style: .continuous
            )
        )
        .shadow(
            color: KartaDesign.ColorToken.frontShadow,
            radius: KartaDesign.elevation.frontShadowRadius,
            y: KartaDesign.elevation.buttonShadowY
        )
        .accessibilityElement(children: .contain)
        .task(id: toast) {
            try? await Task.sleep(for: .seconds(KartaDesign.space.toastDuration))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}
