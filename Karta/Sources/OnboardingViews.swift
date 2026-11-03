import SwiftUI
import KartaCore
import KartaPresentation

/// The header control a tour stop spotlights, mapped one-to-one from
/// `OnboardingState.TourStop` (the store owns which stop is up; the shell
/// only owns where each control sits).
enum TourControl {
    case cookbook, world, filters

    init?(stop: OnboardingState.TourStop) {
        switch stop {
        case .cookbook: self = .cookbook
        case .world: self = .world
        case .filters: self = .filters
        }
    }
}

/// What a tap on the tour scrim means, decided from the current stop and the
/// tap's location in `FeedLayout.coordinateSpace`: during stops 1–2 any tap
/// skips to the filter; at stop 3 the filter button opens the first-run
/// panel and any other tap ends the tour (spec: *The tour* → Skipping).
enum TourInput {
    static func action(
        stop: OnboardingState.TourStop,
        at point: CGPoint,
        filterHole: CGRect
    ) -> OnboardingAction {
        guard stop == .filters else { return .tourTap }
        return filterHole.contains(point) ? .filterButtonTapped : .tourTap
    }
}

/// The Baraja segura banner (`docs/design/karta-v1.md` → *First open and
/// onboarding*): 8 pt below the header row, 22 pt from the sides. Tapping
/// anywhere on it opens the first-run panel through `onboarding.banner`'s
/// action (Set mine).
struct SafeDeckBannerView: View {
    let banner: SafeDeckBanner
    let send: (OnboardingAction) -> Void

    var body: some View {
        Button {
            send(banner.action)
        } label: {
            HStack(alignment: .top, spacing: KartaDesign.space.bannerGap) {
                ShieldGlyph(ink: KartaDesign.ColorToken.ink)
                    .frame(
                        width: KartaDesign.space.bannerShield,
                        height: KartaDesign.space.bannerShield
                    )
                Text(banner.line)
                    .font(KartaDesign.FontToken.bannerLine())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(banner.actionLabel)
                    .font(KartaDesign.FontToken.bannerAction())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .underline(color: KartaDesign.ColorToken.line)
                    .fixedSize()
            }
            .padding(.horizontal, KartaDesign.space.bannerPaddingX)
            .padding(.vertical, KartaDesign.space.bannerPaddingY)
            .background {
                RoundedRectangle(
                    cornerRadius: KartaDesign.space.bannerRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.buttonEdge)
                .offset(y: KartaDesign.space.menuEdge)
                RoundedRectangle(
                    cornerRadius: KartaDesign.space.bannerRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                RoundedRectangle(
                    cornerRadius: KartaDesign.space.bannerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    KartaDesign.ColorToken.line,
                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(banner.line) \(banner.actionLabel)")
    }
}

/// The tour spotlight overlay (`docs/design/karta-v1.md` → *The tour*): the
/// whole screen dimmed with `tourScrim` except a hole 6 pt around the current
/// control with a 3 pt `brand` ring; the bubble sits 14 pt below the hole,
/// cross-fading between stops; stop 3 keeps a ring pulse every 1.4 s and the
/// skip line shows during stops 1–2. All state comes from
/// `store.state.onboarding`; the view only draws and sends actions.
struct OnboardingTourOverlay: View {
    let onboarding: OnboardingState
    /// Control frames in `FeedLayout.coordinateSpace`.
    let controlFrames: [TourControl: CGRect]
    let safeAreaInsets: EdgeInsets
    let send: (OnboardingAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pulseOn = false

    private var stop: OnboardingState.TourStop? {
        onboarding.tourStop
    }

    /// The hole the spotlight leaves around the current control: the control's
    /// frame grown by 6 pt on every side.
    private var hole: CGRect? {
        guard let stop, let control = TourControl(stop: stop),
              let frame = controlFrames[control] else { return nil }
        return frame.insetBy(
            dx: -KartaDesign.space.tourHoleOutset,
            dy: -KartaDesign.space.tourHoleOutset
        )
    }

    private var filterHole: CGRect? {
        controlFrames[.filters]?.insetBy(
            dx: -KartaDesign.space.tourHoleOutset,
            dy: -KartaDesign.space.tourHoleOutset
        )
    }

    /// 300 ms on the deck curve — the spotlight's move between stops.
    private static var move: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: KartaDesign.space.tourMoveDuration)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if let stop, let hole {
                    // The overlay ignores the safe area; the controls' frames
                    // live in `FeedLayout.coordinateSpace`, whose origin is
                    // the safe area's top — shift the drawn hole down to meet
                    // them. Taps are still routed in the named space.
                    let drawn = hole.offsetBy(
                        dx: safeAreaInsets.leading,
                        dy: safeAreaInsets.top
                    )
                    scrim(hole: drawn)
                    ring(hole: drawn, pulsing: onboarding.pulsesFilter)
                    bubble(for: stop, hole: drawn, in: geometry.size)
                } else {
                    scrim(hole: nil)
                }
                skipLine
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .named(FeedLayout.coordinateSpace)) { point in
                guard let stop else { return }
                send(TourInput.action(
                    stop: stop,
                    at: point,
                    filterHole: filterHole ?? .zero
                ))
            }
            .animation(Self.move, value: stop)
        }
        .ignoresSafeArea()
        .task(id: onboarding.tourStop) {
            // Each stop holds 1.2 s; the store owns which stop is next.
            guard let delay = onboarding.tourStop?.delay else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            send(.tourDelayElapsed)
        }
    }

    private func scrim(hole: CGRect?) -> some View {
        ZStack {
            KartaDesign.ColorToken.tourScrim
            if let hole {
                RoundedRectangle(
                    cornerRadius: hole.height / 2,
                    style: .continuous
                )
                .fill(.white)
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .accessibilityHidden(true)
    }

    private func ring(hole: CGRect, pulsing: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: hole.height / 2, style: .continuous)
                .strokeBorder(
                    KartaDesign.ColorToken.brand,
                    lineWidth: KartaDesign.space.tourRingWidth
                )
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
            if pulsing {
                RoundedRectangle(cornerRadius: hole.height / 2, style: .continuous)
                    .strokeBorder(
                        KartaDesign.ColorToken.brand,
                        lineWidth: KartaDesign.space.tourRingWidth
                    )
                    .frame(width: hole.width, height: hole.height)
                    // Scale before positioning: the ring grows around its own
                    // centre, not the overlay's.
                    .scaleEffect(pulseOn ? KartaDesign.space.tourPulseScale : 1)
                    .opacity(pulseOn ? 0 : 1)
                    .position(x: hole.midX, y: hole.midY)
                    .animation(
                        .easeOut(duration: KartaDesign.space.tourPulsePeriod)
                            .repeatForever(autoreverses: false),
                        value: pulseOn
                    )
                    .onAppear { pulseOn = true }
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
    }

    private func bubble(for stop: OnboardingState.TourStop, hole: CGRect, in size: CGSize) -> some View {
        // From AX1 the bubble takes the full width between the 22 pt margins;
        // otherwise it is 230 pt wide, centred under the control and kept
        // 22 pt from the screen edges.
        let stacked = dynamicTypeSize >= .accessibility1
        let width = stacked
            ? size.width - 2 * KartaDesign.space.tourEdgeMargin
            : KartaDesign.space.tourBubbleWidth
        let minX = KartaDesign.space.tourEdgeMargin
        let leading = stacked
            ? minX
            : min(
                max(hole.midX - width / 2, minX),
                size.width - minX - width
            )
        let centerX = leading + width / 2
        let top = hole.maxY + KartaDesign.space.tourBubbleTopGap
        return TourBubble(stop: stop)
            .frame(width: width)
            .overlay(alignment: .top) {
                // The 12 pt pointer square sits on the bubble's top edge,
                // centred under the control even when the bubble is clamped.
                TourBubblePointer()
                    .offset(x: hole.midX - centerX, y: -KartaDesign.space.panelPeak / 2)
            }
            .offset(x: leading, y: top)
            .id(stop)
            .transition(.opacity)
            .animation(Self.move, value: stop)
    }

    private var skipLine: some View {
        VStack {
            Spacer(minLength: 0)
            if let line = onboarding.tourSkipLine {
                Text(line)
                    .font(KartaDesign.FontToken.tourSkip())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                    .padding(.bottom, safeAreaInsets.bottom + KartaDesign.space.tourSkipBottom)
                    .accessibilityIdentifier("tourSkipLine")
            }
        }
        // Full width inside the topLeading ZStack so the line centres.
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}

/// The tour bubble: card fill, radius 16, 12 × 14 pt padding, the 2 pt
/// `buttonEdge` relief plus the signed drop shadow.
private struct TourBubble: View {
    let stop: OnboardingState.TourStop

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stop.title)
                .font(KartaDesign.FontToken.tourTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(stop.line)
                .font(KartaDesign.FontToken.tourLine())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(stop.progress)
                .font(KartaDesign.FontToken.tourStep())
                .tracking(KartaDesign.type.filterHeadingTracking)
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .padding(.top, 4)
        }
        .padding(.horizontal, KartaDesign.space.tourBubblePaddingX)
        .padding(.vertical, KartaDesign.space.tourBubblePaddingY)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.tourBubbleRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.buttonEdge)
            .offset(y: KartaDesign.space.menuEdge)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.tourBubbleRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.card)
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(0.45),
            radius: KartaDesign.elevation.tourBubbleShadowRadius,
            y: KartaDesign.elevation.tourBubbleShadowY
        )
        .accessibilityIdentifier("tourBubble")
    }
}

/// The bubble's pointer: the top half of a 12 pt square turned 45°, peak
/// above the bubble edge (same cut as `PanelPointer` but the peak is fully
/// drawn — the board shows the tip, not a slot into the panel).
private struct TourBubblePointer: View {
    var body: some View {
        Rectangle()
            .fill(KartaDesign.ColorToken.card)
            .frame(
                width: KartaDesign.space.panelPointer,
                height: KartaDesign.space.panelPointer
            )
            .rotationEffect(.degrees(45))
            .frame(
                width: KartaDesign.space.panelPeak,
                height: KartaDesign.space.panelPeak
            )
            .mask(alignment: .top) {
                Color.white.frame(height: KartaDesign.space.panelPeak / 2)
            }
            .frame(height: KartaDesign.space.panelPeak / 2, alignment: .top)
            .allowsHitTesting(false)
    }
}

/// The shared chrome of the two panels that drop from the filter button
/// (the full filter panel and the first-run panel): card fill, 24 pt radius,
/// 2 pt `buttonEdge` relief, 1 pt `line`, shadow and the pointer centred
/// under the filter button.
struct PanelChrome<Content: View>: View {
    /// Filter button's horizontal centre in `FeedLayout.coordinateSpace`.
    let filterButtonCenter: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: KartaDesign.space.filterPanelRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.buttonEdge)
                .offset(y: KartaDesign.space.menuEdge)
                RoundedRectangle(
                    cornerRadius: KartaDesign.space.filterPanelRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                RoundedRectangle(
                    cornerRadius: KartaDesign.space.filterPanelRadius,
                    style: .continuous
                )
                .strokeBorder(
                    KartaDesign.ColorToken.line,
                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                )
            }
            .clipShape(RoundedRectangle(
                cornerRadius: KartaDesign.space.filterPanelRadius,
                style: .continuous
            ))
            .compositingGroup()
            .shadow(
                color: KartaDesign.ColorToken.frontShadow,
                radius: KartaDesign.elevation.menuShadowRadius,
                y: KartaDesign.elevation.menuShadowY
            )
            // The pointer is outside the clip: its top half sticks out of the
            // panel's top edge and its centre sits on the filter button.
            .overlay(alignment: .topLeading) {
                PanelPointer()
                    .offset(
                        x: filterButtonCenter
                            - KartaDesign.space.filterPanelInset
                            - KartaDesign.space.panelPeak / 2,
                        y: -KartaDesign.space.panelPeak / 2
                    )
            }
    }
}
