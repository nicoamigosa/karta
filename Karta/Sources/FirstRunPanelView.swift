import SwiftUI
import KartaCore
import KartaPresentation

/// The filter panel in its first-run form (`docs/design/karta-v1.md` → *The
/// first-run panel*): same geometry, relief, pointer and scrim as the full
/// panel, holding only the two questions — NEVER SHOW ME and COOKING FOR —
/// under *Two quick questions*. The Hogar has no default: **Show my cards**
/// stays in its disabled look until one is chosen. Taps are session-only
/// edits on `onboarding.firstRunPanel`; only Show my cards commits them
/// through `.onboarding(.showMyCards)` — the reducer answers Intolerancias
/// and Hogar, drops the banner and discards the anchors so the personal
/// feed starts at the top (ADR 0009).
struct FirstRunPanelView: View {
    let store: KartaStore
    /// Total height available to the panel: it hugs its content up to the top
    /// of the bottom safe area, then the body scrolls under the pinned footer.
    let maxHeight: CGFloat

    /// Measured scroll-body content height; drives the hug/scroll switch.
    @State private var bodyContentHeight: CGFloat = .greatestFiniteMagnitude
    /// Flash trigger so the scroll indicator is flashed when the panel opens.
    @State private var openedAt = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var panel: FirstRunPanel {
        store.state.onboarding.firstRunPanel
    }

    private var controls: FilterPanelPresentation {
        panel.controls
    }

    private var footerHeight: CGFloat {
        KartaDesign.space.filterFooterTopPadding
            + KartaDesign.space.filterFooterPadding
            + KartaDesign.space.ctaHeight
            + KartaDesign.space.ctaEdge
    }

    private var maxBodyHeight: CGFloat {
        max(0, maxHeight - footerHeight)
    }

    private var bodyHeight: CGFloat {
        min(bodyContentHeight, maxBodyHeight)
    }

    private var isScrollable: Bool {
        bodyContentHeight > maxBodyHeight
    }

    private var stacksTracks: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: KartaDesign.space.filterBlockGap) {
                    titleBlock
                    neverShowMeBlock
                    cookingForSection
                }
                .padding(.top, KartaDesign.space.filterBodyPaddingY)
                .padding(.horizontal, KartaDesign.space.filterPanelPadding)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    bodyContentHeight = height
                }
            }
            .frame(height: bodyHeight)
            .scrollIndicators(.visible)
            .scrollIndicatorsFlash(trigger: openedAt)
            .overlay(alignment: .bottom) {
                if isScrollable {
                    LinearGradient(
                        colors: [
                            KartaDesign.ColorToken.card.opacity(0),
                            KartaDesign.ColorToken.card
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: KartaDesign.space.filterScrollFade)
                    .allowsHitTesting(false)
                }
            }

            showMyCardsButton
                .padding(.top, KartaDesign.space.filterFooterTopPadding)
                .padding(.horizontal, KartaDesign.space.filterPanelPadding)
                .padding(.bottom, KartaDesign.space.filterFooterPadding)
        }
        .onAppear { openedAt += 1 }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(panel.title)
                .font(KartaDesign.FontToken.filterPanelTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
            Text(panel.subtitle)
                .font(KartaDesign.FontToken.firstRunSubtitle())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var neverShowMeBlock: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.neverShowGap) {
            HStack(alignment: .firstTextBaseline) {
                ShieldGlyph(ink: KartaDesign.ColorToken.ink)
                    .frame(
                        width: KartaDesign.space.shieldHeading,
                        height: KartaDesign.space.shieldHeading
                    )
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                Text("NEVER SHOW ME")
                    .font(KartaDesign.FontToken.filterHeading())
                    .tracking(KartaDesign.type.filterHeadingTracking)
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                Spacer(minLength: 0)
                Text("Always free")
                    .font(KartaDesign.FontToken.filterMeta())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            }

            FilterTrack(
                multiChoice: true,
                stacked: stacksTracks,
                options: controls.intolerances.map { option in
                    FilterTrack.Option(label: option.label, isOn: option.isOn) {
                        store.send(.onboarding(.toggleFirstRunAllergen(option.allergen)))
                    }
                }
            )

            Text(panel.intoleranceLine)
                .font(intoleranceLineIsMuted
                    ? KartaDesign.FontToken.mundoLine()
                    : KartaDesign.FontToken.sheetCount())
                .foregroundStyle(
                    intoleranceLineIsMuted
                        ? KartaDesign.ColorToken.inkMuted
                        : KartaDesign.ColorToken.ink
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KartaDesign.space.neverShowPadding)
        .background {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.neverShowRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.paper)
        }
    }

    /// The first of the three signed lines — nothing chosen and no Hogar
    /// yet — is the muted one (Figtree 600 `inkMuted`); the two settled
    /// states draw `ink`.
    private var intoleranceLineIsMuted: Bool {
        panel.intolerances.isEmpty && panel.householdSize == nil
    }

    private var cookingForSection: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.filterHeadingGap) {
            HStack(alignment: .firstTextBaseline) {
                Text("COOKING FOR")
                    .font(KartaDesign.FontToken.filterHeading())
                    .tracking(KartaDesign.type.filterHeadingTracking)
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                Spacer(minLength: 0)
                Text("PEOPLE")
                    .font(KartaDesign.FontToken.filterHeading())
                    .tracking(KartaDesign.type.filterHeadingTracking)
                    .foregroundStyle(KartaDesign.ColorToken.ink)
            }
            FilterTrack(
                multiChoice: false,
                stacked: stacksTracks,
                options: controls.cookingFor.map { option in
                    FilterTrack.Option(label: option.label, isOn: option.isOn) {
                        store.send(.onboarding(.chooseFirstRunHousehold(option.value)))
                    }
                }
            )
            Text(panel.householdLine)
                .font(KartaDesign.FontToken.mundoLine())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Off until a Hogar is chosen: `track` fill, `inkMuted`, no edge, no
    /// shadow, no arrow (`onboarding-panel-empty.png`); the primary look once
    /// enabled (`onboarding-panel.png`).
    private var showMyCardsButton: some View {
        let enabled = panel.canShowCards
        return Button {
            store.send(.onboarding(.showMyCards))
        } label: {
            HStack(spacing: KartaDesign.space.saveIconGap) {
                Text(panel.actionLabel)
                    .font(KartaDesign.FontToken.cookFinishLabel())
                if enabled {
                    Image(systemName: "arrow.right")
                        .font(.system(size: KartaDesign.space.ctaGlyph, weight: .bold))
                }
            }
            .foregroundStyle(
                enabled ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.inkMuted
            )
            .frame(maxWidth: .infinity)
            .frame(height: KartaDesign.space.ctaHeight)
            .background {
                if enabled {
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
                } else {
                    RoundedRectangle(
                        cornerRadius: KartaDesign.radius.cta,
                        style: .continuous
                    )
                    .fill(KartaDesign.ColorToken.track)
                }
            }
        }
        .disabled(!enabled)
        .accessibilityIdentifier("showMyCards")
        .shadow(
            color: enabled ? KartaDesign.ColorToken.buttonShadow : .clear,
            radius: KartaDesign.elevation.buttonShadowRadius,
            y: KartaDesign.elevation.buttonShadowY
        )
    }
}
