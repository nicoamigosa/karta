import SwiftUI
import KartaCore
import KartaPresentation

/// The filter panel that drops from the filter button
/// (`docs/design/karta-v1.md` → *The filter panel*): a scrolling body with the
/// title row, the NEVER SHOW ME block and the four filter tracks, and a pinned
/// footer with the "Show N recipes" button. Every option is visible at once.
///
/// Time, difficulty, Practical and Diet are a shell-owned `FilterDraft`: edits
/// update the draft through `FilterPanelPresentation.nextDraft` and are sent as
/// `.filter(.apply(_))` only when the user taps the button. Intolerancias are
/// never in the draft: each tap is saved at once through
/// `.filter(.setSafetyProfile(_))` — always free, no paywall.
struct FilterPanelView: View {
    let store: KartaStore
    let recipes: [Recipe]
    let clock: any KartaClock
    /// Total height available to the panel: it hugs its content up to the top
    /// of the bottom safe area, then the body scrolls under the pinned footer.
    let maxHeight: CGFloat
    let onApply: () -> Void

    @State private var draft: FilterDraft
    @State private var lastIntolerance: Allergen?
    /// Measured scroll-body content height; drives the hug/scroll switch.
    @State private var bodyContentHeight: CGFloat = .greatestFiniteMagnitude
    /// Flash trigger so the scroll indicator is flashed when the panel opens.
    @State private var openedAt = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        store: KartaStore,
        recipes: [Recipe],
        clock: any KartaClock,
        maxHeight: CGFloat,
        onApply: @escaping () -> Void
    ) {
        self.store = store
        self.recipes = recipes
        self.clock = clock
        self.maxHeight = maxHeight
        self.onApply = onApply
        _draft = State(initialValue: Self.openingDraft(store: store))
        _lastIntolerance = State(initialValue: DebugSeeds.panelIntoleranceNote)
    }

    /// The draft the panel opens with: the applied filters — edits that were
    /// closed without "Show N recipes" are already gone — unless a debug seed
    /// hands the panel an unapplied draft (board `feed-filters.png`).
    static func openingDraft(store: KartaStore) -> FilterDraft {
        DebugSeeds.panelInitialDraft ?? store.state.filterDraft
    }

    private var presentation: FilterPanelPresentation {
        FilterPanelPresentation(
            draft: draft,
            safetyProfile: store.state.safetyProfile
        )
    }

    /// N: the recipes the current Mundo would offer with the draft and the
    /// current Intolerancias, computed by the store, live.
    private var recipeCount: Int? {
        store.state.draftRecipeCount(
            for: store.state.navigation.world,
            draft: draft,
            recipes: recipes,
            clock: clock
        )
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
                    titleRow
                    neverShowMeBlock
                    readyInSection
                    difficultySection
                    practicalSection
                    dietSection
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
                // Signalled scroll: a 32 pt fade right above the pinned footer.
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

            Button {
                store.send(.filter(.apply(draft)))
                onApply()
            } label: {
                Text(
                    recipeCount.map(FilterPanelPresentation.showRecipesLabel(count:))
                        ?? "Show recipes"
                )
                .font(KartaDesign.FontToken.cookFinishLabel())
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
            }
            .accessibilityIdentifier("filterApply")
            .padding(.top, KartaDesign.space.filterFooterTopPadding)
            .padding(.horizontal, KartaDesign.space.filterPanelPadding)
            .padding(.bottom, KartaDesign.space.filterFooterPadding)
            .shadow(
                color: KartaDesign.ColorToken.buttonShadow,
                radius: KartaDesign.elevation.buttonShadowRadius,
                y: KartaDesign.elevation.buttonShadowY
            )
        }
        .onAppear { openedAt += 1 }
    }

    // MARK: - Sections

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Filters")
                .font(KartaDesign.FontToken.filterPanelTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
            Spacer(minLength: 0)
            Button("Reset") {
                draft = presentation.nextDraft(after: .reset)
            }
            .font(KartaDesign.FontToken.switchResting())
            .foregroundStyle(KartaDesign.ColorToken.ink)
            .padding(.horizontal, KartaDesign.space.saveButtonX)
            .frame(height: KartaDesign.space.filterResetHeight)
            .background {
                Capsule()
                    .fill(KartaDesign.ColorToken.buttonEdge)
                    .offset(y: KartaDesign.space.reverseButtonEdge)
                Capsule().fill(KartaDesign.ColorToken.card)
                Capsule().strokeBorder(
                    KartaDesign.ColorToken.line,
                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                )
            }
            .accessibilityIdentifier("filterReset")
        }
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
                options: presentation.intolerances.map { option in
                    FilterTrack.Option(label: option.label, isOn: option.isOn) {
                        // Saved at once, on every surface: the safety profile
                        // never waits for the draft and is never a paywall.
                        let next = presentation.nextSafetyProfile(toggling: option.allergen)
                        store.send(.filter(.setSafetyProfile(next)))
                        lastIntolerance = option.allergen
                    }
                }
            )

            if let note = presentation.intoleranceNote(after: lastIntolerance) {
                Text(note)
                    .font(KartaDesign.FontToken.sheetCount())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Saved as you tap. Reset and Clear never touch it.")
                    .font(KartaDesign.FontToken.mundoLine())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private var readyInSection: some View {
        filterSection(
            heading: "READY IN",
            meta: "MINUTES",
            multiChoice: false,
            options: presentation.readyIn.map { option in
                FilterTrack.Option(label: option.label, isOn: option.isOn) {
                    draft = presentation.nextDraft(after: .readyIn(option.value))
                }
            }
        )
    }

    private var difficultySection: some View {
        filterSection(
            heading: "DIFFICULTY",
            meta: nil,
            multiChoice: false,
            options: presentation.difficulty.map { option in
                FilterTrack.Option(label: option.label, isOn: option.isOn) {
                    draft = presentation.nextDraft(after: .difficulty(option.value))
                }
            }
        )
    }

    private var practicalSection: some View {
        filterSection(
            heading: "PRACTICAL",
            meta: "ANY NUMBER",
            multiChoice: true,
            options: presentation.practical.map { option in
                FilterTrack.Option(label: option.label, isOn: option.isOn) {
                    draft = presentation.nextDraft(after: .practical(option.value))
                }
            }
        )
    }

    private var dietSection: some View {
        filterSection(
            heading: "DIET",
            meta: nil,
            multiChoice: false,
            options: presentation.diet.map { option in
                FilterTrack.Option(label: option.label, isOn: option.isOn) {
                    draft = presentation.nextDraft(after: .diet(option.value))
                }
            }
        )
    }

    private func filterSection(
        heading: String,
        meta: String?,
        multiChoice: Bool,
        options: [FilterTrack.Option]
    ) -> some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.filterHeadingGap) {
            HStack(alignment: .firstTextBaseline) {
                Text(heading)
                    .font(KartaDesign.FontToken.filterHeading())
                    .tracking(KartaDesign.type.filterHeadingTracking)
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                Spacer(minLength: 0)
                if let meta {
                    Text(meta)
                        .font(KartaDesign.FontToken.filterHeading())
                        .tracking(KartaDesign.type.filterHeadingTracking)
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                }
            }
            FilterTrack(
                multiChoice: multiChoice,
                stacked: stacksTracks,
                options: options
            )
        }
    }
}

/// One filter track (`docs/design/karta-v1.md` → *Tracks*): the cookbook
/// switch extended — `track` fill, radius 14, 4 pt inset, 4 pt between
/// equal-width segments, each segment 40 pt high. A segment label never wraps
/// and never truncates: when the widest label does not fit its equal share —
/// or from AX1 — the track takes its stacked form: one full-width 48 pt row
/// per option, with a check on an on multi-choice row.
private struct FilterTrack: View {
    struct Option {
        let label: String
        let isOn: Bool
        let action: () -> Void
    }

    let multiChoice: Bool
    /// Stacked regardless of fit (Dynamic Type ≥ AX1).
    let stacked: Bool
    let options: [Option]

    @State private var availableWidth: CGFloat = .greatestFiniteMagnitude
    @State private var widestLabel: CGFloat = 0

    private var isStacked: Bool {
        stacked || labelShare < widestLabel
    }

    private var labelShare: CGFloat {
        let count = CGFloat(options.count)
        guard count > 0, availableWidth < .greatestFiniteMagnitude else {
            return .greatestFiniteMagnitude
        }
        let gaps = KartaDesign.space.switchTrackInset * (count - 1)
        return (availableWidth - gaps) / count
    }

    var body: some View {
        Group {
            if isStacked {
                VStack(spacing: KartaDesign.space.switchTrackInset) {
                    ForEach(Array(options.enumerated()), id: \.offset) { option in
                        row(option.element)
                    }
                }
            } else {
                HStack(spacing: KartaDesign.space.switchTrackInset) {
                    ForEach(Array(options.enumerated()), id: \.offset) { option in
                        segment(option.element)
                    }
                }
            }
        }
        .padding(KartaDesign.space.switchTrackInset)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width - 2 * KartaDesign.space.switchTrackInset
        } action: { width in
            availableWidth = width
        }
        .background {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchTrackRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.track)
        }
        .background {
            // Off-screen copy that measures the widest label so the track can
            // fall back to its stacked form before a label ever truncates.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { option in
                    Text(option.element.label)
                        .font(labelFont(on: option.element.isOn))
                        .fixedSize()
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.width + KartaDesign.space.trackLabelSlack
                        } action: { width in
                            widestLabel = max(widestLabel, width)
                        }
                }
            }
            .hidden()
        }
    }

    private func labelFont(on: Bool) -> Font {
        if multiChoice {
            return on
                ? KartaDesign.FontToken.sheetCount()
                : KartaDesign.FontToken.cupoCount()
        }
        return on
            ? KartaDesign.FontToken.switchActive()
            : KartaDesign.FontToken.switchResting()
    }

    private func segment(_ option: Option) -> some View {
        Button(action: option.action) {
            Text(option.label)
                .font(labelFont(on: option.isOn))
                .lineLimit(1)
                .foregroundStyle(
                    option.isOn
                        ? (multiChoice ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.ink)
                        : KartaDesign.ColorToken.inkMuted
                )
                .frame(maxWidth: .infinity)
                .frame(height: KartaDesign.space.trackSegmentHeight)
                .background { segmentBackground(on: option.isOn) }
        }
        .accessibilityAddTraits(option.isOn ? [.isSelected] : [])
    }

    private func row(_ option: Option) -> some View {
        Button(action: option.action) {
            HStack(spacing: KartaDesign.space.chipGap) {
                Text(option.label)
                    .font(labelFont(on: option.isOn))
                    .lineLimit(1)
                    .foregroundStyle(
                        option.isOn
                            ? (multiChoice ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.ink)
                            : KartaDesign.ColorToken.inkMuted
                    )
                Spacer(minLength: 0)
                if multiChoice, option.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KartaDesign.ColorToken.card)
                }
            }
            .padding(.horizontal, KartaDesign.space.saveButtonX)
            .frame(maxWidth: .infinity)
            .frame(height: KartaDesign.space.trackRowHeight)
            .background { segmentBackground(on: option.isOn) }
        }
        .accessibilityAddTraits(option.isOn ? [.isSelected] : [])
    }

    @ViewBuilder
    private func segmentBackground(on: Bool) -> some View {
        if on, multiChoice {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchSegmentRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.inkEdge)
            .offset(y: KartaDesign.space.reverseButtonEdge)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchSegmentRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.ink)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchSegmentRadius,
                style: .continuous
            )
            .strokeBorder(
                KartaDesign.ColorToken.ink,
                lineWidth: KartaDesign.elevation.backFrameLineWidth
            )
        } else if on {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchSegmentRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.buttonEdge)
            .offset(y: KartaDesign.space.reverseButtonEdge)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchSegmentRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.card)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.switchSegmentRadius,
                style: .continuous
            )
            .strokeBorder(
                KartaDesign.ColorToken.line,
                lineWidth: KartaDesign.elevation.backFrameLineWidth
            )
        }
    }
}

/// The thin-outline shield of the NEVER SHOW ME heading, the kept-intolerance
/// note under the empty-filter buttons and the "no recipes fit your
/// intolerances" board.
struct ShieldGlyph: View {
    var ink: Color = KartaDesign.ColorToken.ink

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ShieldShape()
                .stroke(ink, style: StrokeStyle(
                    lineWidth: side * 0.07,
                    lineCap: .round,
                    lineJoin: .round
                ))
                .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.16))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.62),
            control2: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.16),
            control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.82),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.62)
        )
        path.closeSubpath()
        return path
    }
}

/// The pointer on the panel's top edge: a 12 pt square turned 45°, same fill
/// and border as the panel.
struct PanelPointer: View {
    var body: some View {
        Rectangle()
            .fill(KartaDesign.ColorToken.card)
            .overlay {
                Rectangle().strokeBorder(
                    KartaDesign.ColorToken.line,
                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                )
            }
            .frame(
                width: KartaDesign.space.panelPointer,
                height: KartaDesign.space.panelPointer
            )
            .rotationEffect(.degrees(45))
    }
}
