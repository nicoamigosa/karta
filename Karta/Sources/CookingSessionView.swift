import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// Cooking mode: the Sesión de cocina. Renders what
/// `KartaStore.cookingStepPresentation` projects — one Paso per card — and,
/// after the last Paso, the Cierre card from
/// `KartaStore.cookingFinishPresentation`. No rules live here: transitions,
/// clamping, the cooked event and the probably-cooked inference (evaluated
/// by the store on arrival at the Cierre) are all decided by
/// `CookingSession`/`KartaReducer`.
struct CookingSessionView: View {
    let session: CookingSession
    let recipe: Recipe
    let clips: TechniqueClipLibrary
    let manifest: MediaAssetManifest
    let store: KartaStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Read so the body re-evaluates on Dynamic Type changes: the Fraunces
    // tokens resolve their point size eagerly in `KartaDesign.FontToken`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var dragOffset: CGFloat = 0
    @State private var confirmLeave = false
    @State private var swipeHintVisible = true
    /// Height of the scrolling area between the pinned header and the
    /// pinned bottom zone — the viewport the give-way order measures.
    @State private var bodyViewport: CGFloat = 0
    /// Measured heights of the scroll content around the media window:
    /// the Resumen+Detalle block, the FOR THIS STEP section and the
    /// bottom-zone block when it scrolls (AX sizes).
    @State private var leadingHeight: CGFloat = 0
    @State private var rowsHeight: CGFloat = 0
    @State private var scrolledBottomHeight: CGFloat = 0
    /// Live scroll metrics for the signalled scroll (fade, chip, at-end).
    @State private var scrollGeometry: ScrollGeometry?
    /// Bottom edge of every FOR THIS STEP row, in scroll-body coordinates.
    @State private var rowBottoms: [Int: CGFloat] = [:]
    /// Bumped when a card settles so the scroll indicator flashes.
    @State private var indicatorFlash = 0

    private var suit: SuitTokens {
        KartaDesign.suit(recipe.primaryCourse)
    }

    private var now: TimeInterval {
        Date().timeIntervalSince1970
    }

    /// From AX1 to AX5 nothing stays pinned at the bottom: the Temporizador
    /// and the finish card's buttons move to the end of the scroll.
    private var bottomZoneScrolls: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var presentation: CookingStepPresentation? {
        store.cookingStepPresentation(for: recipe, clips: clips, now: now)
    }

    private var finishPresentation: CookingFinishPresentation? {
        store.cookingFinishPresentation(for: recipe, now: now)
    }

    var body: some View {
        ZStack {
            suit.back.ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    ForEach(peekOffsets.indices, id: \.self) { depth in
                        peekCard(depth: depth)
                    }

                    frontCard(width: geometry.size.width)
                        .zIndex(Double(KartaDesign.cooking.peekCardCount + 1))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .padding(.horizontal, KartaDesign.space.reverseCardX)
            .padding(.vertical, KartaDesign.space.reverseCardY)
        }
        .foregroundStyle(KartaDesign.ColorToken.ink)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .confirmationDialog(
            leaveTitle,
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                store.send(.exitCooking)
            }
            Button("Keep cooking", role: .cancel) {}
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            indicatorFlash += 1
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: session.currentIndex) { _, _ in
            indicatorFlash += 1
        }
        .onChange(of: session.isOnFinish) { _, _ in
            indicatorFlash += 1
        }
        .task {
            try? await Task.sleep(
                for: .seconds(KartaDesign.cooking.swipeHintFadeDelay)
            )
            swipeHintVisible = false
        }
    }

    /// The signed-off text of the leave sheet (no board yet; the title carries
    /// the step position, e.g. "Leave cooking? You're on step 3 of 4.").
    private var leaveTitle: String {
        "Leave cooking? You're on step \(session.currentIndex + 1) of \(session.steps.count)."
    }

    // MARK: - The card

    @ViewBuilder
    private func frontCard(width: CGFloat) -> some View {
        if let presentation {
            pasoCard(presentation, width: width)
        } else if let finishPresentation {
            finishCard(finishPresentation, width: width)
        }
    }

    /// Shared chrome for the Paso and Cierre cards: the pinned header, the
    /// scrolling body (with its signalled overflow) and the bottom zone,
    /// which stays pinned up to xxxL and scrolls from AX1.
    private func cardShell<ScrollBody: View, Bottom: View>(
        segments: [CookingStepPresentation.ProgressSegment],
        width: CGFloat,
        accessibilityLabel: String,
        @ViewBuilder scrollBody: @escaping () -> ScrollBody,
        @ViewBuilder bottomZone: @escaping () -> Bottom
    ) -> some View {
        CardRelief(edgeColors: KartaDesign.ColorToken.cardEdges) {
            VStack(alignment: .leading, spacing: 0) {
                header(segments)
                    .padding(.top, KartaDesign.cooking.headerTop)
                    .padding(.horizontal, KartaDesign.cooking.cardInset)

                ScrollViewReader { proxy in
                    ScrollView {
                        scrollBody()
                            .frame(minHeight: bodyViewport, alignment: .top)
                    }
                    .scrollIndicators(.visible)
                    .scrollIndicatorsFlash(trigger: indicatorFlash)
                    .scrollBounceBehavior(.basedOnSize)
                    .coordinateSpace(name: ScrollBodySpace.name)
                    .onGeometryChange(
                        for: CGFloat.self,
                        of: { $0.size.height }
                    ) { _, newHeight in
                        bodyViewport = newHeight
                    }
                    .onScrollGeometryChange(for: ScrollGeometry.self) { geometry in
                        geometry
                    } action: { _, newGeometry in
                        scrollGeometry = newGeometry
                    }
                    .overlay(alignment: .bottom) {
                        if showsScrollSignal {
                            scrollFade
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showsScrollSignal {
                            signalChip(proxy: proxy)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                bottomZone()
            }
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / KartaDesign.deck.dragRotationDivisor)))
        .contentShape(Rectangle())
        .onTapGesture { location in
            dismissSwipeHint()
            handleTap(locationX: location.x, width: width)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - The Paso card

    private func pasoCard(
        _ presentation: CookingStepPresentation,
        width: CGFloat
    ) -> some View {
        cardShell(
            segments: presentation.progress,
            width: width,
            accessibilityLabel: "Step \(session.currentIndex + 1) of \(session.steps.count): \(presentation.summary)"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(presentation.summary)
                        .font(KartaDesign.FontToken.cookSummary())
                        .tracking(-0.4)
                        .modifier(SpecLineHeight(
                            fontName: "Fraunces", fontWeight: .bold,
                            size: 34,
                            target: KartaDesign.cooking.summaryLineHeight,
                            relativeTo: .largeTitle
                        ))
                        // ≤ 36 characters fits two lines at the spec'd
                        // size; bigger text needs more room.
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .padding(.top, KartaDesign.cooking.summaryGap)

                    Text(presentation.detail)
                        .font(KartaDesign.FontToken.cookDetail())
                        .modifier(SpecLineHeight(
                            fontName: "Figtree", fontWeight: .medium,
                            size: 17,
                            target: KartaDesign.cooking.detailLineHeight,
                            relativeTo: .body
                        ))
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, KartaDesign.cooking.detailGap)
                }
                .padding(.horizontal, KartaDesign.cooking.cardInset)
                .onGeometryChange(
                    for: CGFloat.self,
                    of: { $0.size.height }
                ) { _, newHeight in
                    leadingHeight = newHeight
                }

                // The media window gives way 220 → 160 after the free space
                // has shrunk to its 20 pt minimum, before the body scrolls.
                mediaWindow(presentation)
                    .frame(height: mediaHeight(extra: scrolledBottomHeight))
                    .padding(.top, KartaDesign.cooking.sectionGap)
                    .padding(.horizontal, KartaDesign.cooking.mediaInset)

                ingredientsSection(presentation)
                    .padding(.top, KartaDesign.cooking.sectionGap)
                    .padding(.horizontal, KartaDesign.cooking.cardInset)
                    .onGeometryChange(
                        for: CGFloat.self,
                        of: { $0.size.height }
                    ) { _, newHeight in
                        rowsHeight = newHeight
                    }

                Spacer(minLength: KartaDesign.cooking.freeSpaceMin)

                if bottomZoneScrolls, presentation.timerLabel != nil {
                    timerBlock(presentation)
                        .padding(.horizontal, KartaDesign.cooking.cardInset)
                        .padding(.bottom, KartaDesign.cooking.timerBottomGap)
                        .onGeometryChange(
                            for: CGFloat.self,
                            of: { $0.size.height }
                        ) { _, newHeight in
                            scrolledBottomHeight = newHeight
                        }
                }

                Color.clear
                    .frame(height: 0)
                    .id(ScrollBodyAnchor.end)
            }
        } bottomZone: {
            if !bottomZoneScrolls, presentation.timerLabel != nil {
                timerBlock(presentation)
                    .padding(.horizontal, KartaDesign.cooking.cardInset)
                    .padding(.bottom, KartaDesign.cooking.timerBottomGap)
            }
        }
        .overlay(alignment: .bottom) {
            swipeHint
        }
    }

    /// The media window height after the give-way order: free space down to
    /// 20 pt first, then the window shrinks 220 → 160, and only then does the
    /// body scroll (signalled). `extra` is the height of the bottom-zone
    /// block when it scrolls at accessibility sizes.
    private func mediaHeight(extra: CGFloat) -> CGFloat {
        guard bodyViewport > 0 else { return KartaDesign.cooking.mediaHeight }
        let rest = leadingHeight
            + KartaDesign.cooking.sectionGap * 2
            + rowsHeight
            + KartaDesign.cooking.freeSpaceMin
            + extra
        return min(
            KartaDesign.cooking.mediaHeight,
            max(KartaDesign.cooking.mediaMinHeight, bodyViewport - rest)
        )
    }

    /// The Paso-1-only hint: a left arrow and "Swipe left for step 2" 20 pt
    /// above the bottom edge, taking no space; it fades after 3 s or on the
    /// first touch.
    private var swipeHint: some View {
        Group {
            if session.currentIndex == 0, !session.isOnFinish, swipeHintVisible {
                HStack(spacing: KartaDesign.space.saveIconGap) {
                    Image(systemName: "arrow.left")
                    Text("Swipe left for step 2")
                }
                .font(.custom("Figtree", size: 13).weight(.bold))
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .padding(.bottom, KartaDesign.cooking.swipeHintBottom)
            }
        }
        .animation(
            .easeOut(duration: KartaDesign.cooking.swipeHintFadeDuration),
            value: swipeHintVisible
        )
    }

    private func dismissSwipeHint() {
        guard swipeHintVisible else { return }
        swipeHintVisible = false
    }

    // MARK: - The finish card (Cierre)

    private func finishCard(
        _ finish: CookingFinishPresentation,
        width: CGFloat
    ) -> some View {
        cardShell(
            segments: finish.progress,
            width: width,
            accessibilityLabel: finishTitle(finish)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(finishTitle(finish))
                        .font(KartaDesign.FontToken.cookSummary())
                        .tracking(-0.4)
                        .modifier(SpecLineHeight(
                            fontName: "Fraunces", fontWeight: .bold,
                            size: 34,
                            target: KartaDesign.cooking.summaryLineHeight,
                            relativeTo: .largeTitle
                        ))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .padding(.top, KartaDesign.cooking.summaryGap)

                    Text(finish.recipeName)
                        .font(KartaDesign.FontToken.cookDetail())
                        .modifier(SpecLineHeight(
                            fontName: "Figtree", fontWeight: .medium,
                            size: 17,
                            target: KartaDesign.cooking.detailLineHeight,
                            relativeTo: .body
                        ))
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, KartaDesign.cooking.detailGap)
                }
                .padding(.horizontal, KartaDesign.cooking.cardInset)
                .onGeometryChange(
                    for: CGFloat.self,
                    of: { $0.size.height }
                ) { _, newHeight in
                    leadingHeight = newHeight
                }

                // The recipe's Foto fills the free height, never under 160 pt.
                RecipePhoto(reference: finish.photo, manifest: manifest)
                    .frame(maxWidth: .infinity)
                    .frame(height: finishPhotoHeight)
                    .clipShape(RoundedRectangle(
                        cornerRadius: KartaDesign.cooking.mediaRadius,
                        style: .continuous
                    ))
                    .padding(.top, KartaDesign.cooking.sectionGap)
                    .padding(.horizontal, KartaDesign.cooking.mediaInset)

                Spacer(minLength: KartaDesign.cooking.freeSpaceMin)

                if bottomZoneScrolls {
                    finishBottomContent(finish)
                        .padding(.horizontal, KartaDesign.cooking.bottomZoneHGap)
                        .padding(.bottom, KartaDesign.cooking.bottomZoneVGap)
                        .onGeometryChange(
                            for: CGFloat.self,
                            of: { $0.size.height }
                        ) { _, newHeight in
                            scrolledBottomHeight = newHeight
                        }
                }

                Color.clear
                    .frame(height: 0)
                    .id(ScrollBodyAnchor.end)
            }
        } bottomZone: {
            if !bottomZoneScrolls {
                VStack(spacing: 0) {
                    edgeToEdgeLine
                    finishBottomContent(finish)
                        .padding(.top, KartaDesign.cooking.bottomZoneTopGap)
                        .padding(.horizontal, KartaDesign.cooking.bottomZoneHGap)
                        .padding(.bottom, KartaDesign.cooking.bottomZoneVGap)
                }
            }
        }
    }

    private func finishTitle(_ finish: CookingFinishPresentation) -> String {
        switch finish.outcome {
        case .asking:
            return "How did it turn out?"
        case .answered:
            return "Cooked. Enjoy it!"
        }
    }

    private var finishPhotoHeight: CGFloat {
        guard bodyViewport > 0 else { return KartaDesign.cooking.mediaMinHeight }
        let rest = leadingHeight
            + KartaDesign.cooking.sectionGap
            + KartaDesign.cooking.freeSpaceMin
            + scrolledBottomHeight
        return max(KartaDesign.cooking.mediaMinHeight, bodyViewport - rest)
    }

    /// The Cierre's pinned bottom zone: the three outcome buttons while the
    /// prompt is open, or the primary Finish once answered. At AX sizes the
    /// same content scrolls, stacked one button per row.
    @ViewBuilder
    private func finishBottomContent(_ finish: CookingFinishPresentation) -> some View {
        switch finish.outcome {
        case .asking:
            if bottomZoneScrolls {
                VStack(spacing: KartaDesign.space.cardGap) {
                    outcomeButton(outcome: .thumbsUp, icon: "hand.thumbsup", label: "Good", stacked: true)
                    outcomeButton(outcome: .thumbsDown, icon: "hand.thumbsdown", label: "Not great", stacked: true)
                    outcomeButton(outcome: .photo, icon: "camera", label: "Add photo", stacked: true)
                }
            } else {
                HStack(spacing: KartaDesign.cooking.bottomZoneHGap) {
                    outcomeButton(outcome: .thumbsUp, icon: "hand.thumbsup", label: "Good", stacked: false)
                    outcomeButton(outcome: .thumbsDown, icon: "hand.thumbsdown", label: "Not great", stacked: false)
                    outcomeButton(outcome: .photo, icon: "camera", label: "Add photo", stacked: false)
                }
            }
        case .answered:
            finishButton
        }
    }

    private var finishButton: some View {
        Button {
            store.send(.exitCooking)
        } label: {
            Text("Finish")
                .font(KartaDesign.FontToken.ctaLabel())
                .foregroundStyle(KartaDesign.ColorToken.card)
                .frame(maxWidth: .infinity)
                .frame(minHeight: KartaDesign.cooking.finishHeight)
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
        .accessibilityLabel("Finish cooking")
    }

    private func outcomeButton(
        outcome: CookOutcome,
        icon: String,
        label: String,
        stacked: Bool
    ) -> some View {
        Button {
            store.send(.respond(outcome))
        } label: {
            Group {
                if stacked {
                    HStack(spacing: KartaDesign.space.cardGap) {
                        Image(systemName: icon)
                            .font(.system(size: KartaDesign.cooking.outcomeIcon, weight: .semibold))
                            .frame(width: KartaDesign.cooking.outcomeIcon)
                        Text(label)
                            .font(KartaDesign.FontToken.button())
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, KartaDesign.cooking.bottomZoneHGap)
                } else {
                    VStack(spacing: KartaDesign.space.rankGap) {
                        Image(systemName: icon)
                            .font(.system(size: KartaDesign.cooking.outcomeIcon, weight: .semibold))
                            // Fixed box so all three labels share a baseline.
                            .frame(height: KartaDesign.cooking.outcomeIcon)
                        Text(label)
                            .font(KartaDesign.FontToken.button())
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .foregroundStyle(KartaDesign.ColorToken.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: stacked
                ? KartaDesign.cooking.outcomeButtonAXHeight
                : KartaDesign.cooking.outcomeButtonHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: KartaDesign.radius.chip,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.buttonEdge)
                .offset(y: KartaDesign.space.reverseButtonEdge)
                RoundedRectangle(
                    cornerRadius: KartaDesign.radius.chip,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                RoundedRectangle(
                    cornerRadius: KartaDesign.radius.chip,
                    style: .continuous
                )
                .strokeBorder(
                    KartaDesign.ColorToken.line,
                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                )
            }
        }
        .accessibilityLabel(label)
    }

    // MARK: - Header: ✕ + progress bar

    private func header(_ segments: [CookingStepPresentation.ProgressSegment]) -> some View {
        ZStack {
            progressBar(segments)
                .frame(maxWidth: .infinity)

            HStack {
                Button {
                    confirmLeave = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(
                            size: KartaDesign.space.reverseCloseGlyph,
                            weight: .bold
                        ))
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .frame(
                            width: KartaDesign.space.reverseButtonHit,
                            height: KartaDesign.space.reverseButtonHit
                        )
                        .background {
                            Circle()
                                .fill(KartaDesign.ColorToken.buttonEdge)
                                .offset(y: KartaDesign.space.reverseButtonEdge)
                            Circle().fill(KartaDesign.ColorToken.card)
                            Circle().strokeBorder(
                                KartaDesign.ColorToken.line,
                                lineWidth: KartaDesign.elevation.backFrameLineWidth
                            )
                        }
                }
                .accessibilityLabel("Leave cooking")
                Spacer()
            }
        }
        .frame(height: KartaDesign.space.reverseButtonHit)
    }

    /// One segment per Paso: suit `back` for done and current, `chip` for the
    /// rest. A Temporizador running on another Paso turns its segment into an
    /// outlined pill; at zero it fills `brand` and reads "Time's up". The
    /// finish card has no segment of its own — every Paso shows done.
    private func progressBar(_ segments: [CookingStepPresentation.ProgressSegment]) -> some View {
        HStack(spacing: KartaDesign.cooking.segmentGap) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                segmentView(segment)
            }
        }
    }

    @ViewBuilder
    private func segmentView(_ segment: CookingStepPresentation.ProgressSegment) -> some View {
        switch segment.timer {
        case let .running(remaining):
            timerPill(label: remaining, fired: false, stepIndex: segment.stepIndex)
        case .finished:
            timerPill(label: "Time's up", fired: true, stepIndex: segment.stepIndex)
        case nil:
            RoundedRectangle(
                cornerRadius: KartaDesign.cooking.segmentRadius,
                style: .continuous
            )
            .fill(segment.state == .upcoming ? suit.chip : suit.back)
            .frame(
                width: KartaDesign.cooking.segmentWidth,
                height: KartaDesign.cooking.segmentHeight
            )
        }
    }

    /// The running/finished Temporizador pill in the progress bar. Tapping it
    /// goes to that Paso through the existing next/previous seam.
    private func timerPill(label: String, fired: Bool, stepIndex: Int) -> some View {
        Button {
            jump(to: stepIndex)
        } label: {
            Text(label)
                .font(.custom("Figtree", size: 13).weight(.heavy).monospacedDigit())
                .foregroundStyle(fired ? KartaDesign.ColorToken.card : suit.chipInk)
                .padding(.horizontal, KartaDesign.cooking.timerPillHGap)
                .frame(minHeight: KartaDesign.cooking.timerPillHeight)
                .background {
                    Capsule().fill(fired ? KartaDesign.ColorToken.brand : KartaDesign.ColorToken.card)
                    if !fired {
                        Capsule().strokeBorder(
                            suit.chipInk,
                            lineWidth: KartaDesign.cooking.timerPillBorder
                        )
                    }
                }
        }
        .accessibilityLabel(fired ? "Timer finished on step \(stepIndex + 1)" : "Timer running on step \(stepIndex + 1), \(label) left")
    }

    // MARK: - Media window

    /// The Foto del paso window. With a technique clip it keeps the photo but
    /// swaps the label chip for the clip's name and length and puts a play
    /// circle in the centre; playback itself is issue #12.
    private func mediaWindow(_ presentation: CookingStepPresentation) -> some View {
        ZStack {
            if let photo = presentation.photo {
                RecipePhoto(reference: photo, manifest: manifest)
            } else {
                // With a clip the play circle owns the centre; the
                // placeholder's label would clash with it.
                stepPhotoPlaceholder(showsLabel: presentation.clip == nil)
            }

            if presentation.clip != nil {
                Button {
                    // Clip playback is issue #12: the affordance is drawn,
                    // the player is not part of this slice.
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .frame(
                            width: KartaDesign.cooking.playCircle,
                            height: KartaDesign.cooking.playCircle
                        )
                        .background {
                            Circle()
                                .fill(KartaDesign.ColorToken.buttonEdge)
                                .offset(y: KartaDesign.space.reverseButtonEdge)
                            Circle().fill(KartaDesign.ColorToken.card)
                        }
                }
                .accessibilityLabel("Play technique clip")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(
            cornerRadius: KartaDesign.cooking.mediaRadius,
            style: .continuous
        ))
        .overlay(alignment: .bottomLeading) {
            Text(mediaChipLabel(presentation))
                .font(.custom("Figtree", size: 12).weight(.heavy))
                .foregroundStyle(suit.chipInk)
                .lineLimit(1)
                .padding(.vertical, KartaDesign.space.stepCueY + 2)
                .padding(.horizontal, KartaDesign.space.rankGap * 2 + 4)
                .background(
                    KartaDesign.ColorToken.card,
                    in: RoundedRectangle(
                        cornerRadius: KartaDesign.cooking.mediaChipRadius,
                        style: .continuous
                    )
                )
                .padding(KartaDesign.cooking.mediaChipInset)
        }
    }

    private func mediaChipLabel(_ presentation: CookingStepPresentation) -> String {
        if let clip = presentation.clip {
            return "\(clip.name) · \(clip.lengthLabel)"
        }
        return "When it looks like this, move on"
    }

    /// No step photos exist in the catalog yet (#104); the boards draw a beige
    /// window with a camera glyph and an eyebrow where the Foto del paso goes.
    private func stepPhotoPlaceholder(showsLabel: Bool) -> some View {
        ZStack {
            KartaDesign.ColorToken.cardEdges[0]
            VStack(spacing: KartaDesign.space.cardGap) {
                Image(systemName: "camera")
                    .font(.system(size: 28))
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                if showsLabel {
                    Text("Step photo".uppercased())
                        .font(KartaDesign.FontToken.rankUnit())
                        .tracking(KartaDesign.type.rankUnitTracking)
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - FOR THIS STEP

    private func ingredientsSection(_ presentation: CookingStepPresentation) -> some View {
        VStack(alignment: .leading, spacing: KartaDesign.cooking.ingredientRowGap) {
            Text("For this step".uppercased())
                .font(KartaDesign.FontToken.rankUnit())
                .tracking(KartaDesign.type.rankUnitTracking)
                .foregroundStyle(suit.chipInk)
                .padding(.bottom, KartaDesign.cooking.ingredientRowGap)

            ForEach(Array(presentation.ingredientRows.enumerated()), id: \.offset) { index, row in
                (Text(row.quantity + " ")
                    .font(.custom("Figtree", size: 17).weight(.heavy))
                    + Text(row.name)
                    .font(.custom("Figtree", size: 17).weight(.medium)))
                .modifier(SpecLineHeight(
                    fontName: "Figtree", fontWeight: .heavy,
                    size: 17,
                    target: KartaDesign.cooking.ingredientLineHeight,
                    relativeTo: .body
                ))
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)
                .id(ScrollBodyAnchor.row(index))
                .onGeometryChange(
                    for: CGFloat.self,
                    of: { $0.frame(in: .named(ScrollBodySpace.name)).maxY }
                ) { _, newBottom in
                    rowBottoms[index] = newBottom
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Bottom zone (pinned up to xxxL)

    /// The ready-state Temporizador block: declared duration, TIMER label and
    /// the brand play circle. Starting and running timers are issue #5; the
    /// play affordance is drawn but inert in this slice.
    private func timerBlock(_ presentation: CookingStepPresentation) -> some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: KartaDesign.space.cardGap) {
                Text(presentation.timerLabel ?? "")
                    .font(KartaDesign.FontToken.cookTimer())
                    .monospacedDigit()
                    .lineLimit(1)
                    // Shrink rather than truncate the digits when the scaled
                    // Fraunces no longer fits beside TIMER and the play disc.
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(suit.chipInk)
                Text("TIMER")
                    .font(.custom("Figtree", size: 12).weight(.heavy))
                    .tracking(KartaDesign.cooking.timerLabelTracking)
                    .foregroundStyle(suit.chipInk)
            }
            Spacer()
            Button {
                // Starting a Temporizador is issue #5.
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(KartaDesign.ColorToken.card)
                    .frame(
                        width: KartaDesign.cooking.timerPlay,
                        height: KartaDesign.cooking.timerPlay
                    )
                    .background {
                        Circle()
                            .fill(KartaDesign.ColorToken.brandEdge)
                            .offset(y: KartaDesign.space.ctaEdge)
                        Circle().fill(KartaDesign.ColorToken.brand)
                    }
            }
            .accessibilityLabel("Start timer")
        }
        .padding(.horizontal, KartaDesign.cooking.bottomZoneHGap)
        .padding(.vertical, KartaDesign.cooking.timerPaddingY)
        .background(
            suit.chip,
            in: RoundedRectangle(
                cornerRadius: KartaDesign.cooking.timerRadius,
                style: .continuous
            )
        )
    }

    /// The 1 pt separator between the card body and the pinned bottom zone;
    /// runs edge to edge like on the boards.
    private var edgeToEdgeLine: some View {
        KartaDesign.ColorToken.line
            .frame(height: KartaDesign.elevation.backFrameLineWidth)
    }

    // MARK: - Signalled scroll

    /// Hidden content is always signalled: the fade, the chip and the
    /// indicator show while the body can still scroll and go away at the end.
    private var showsScrollSignal: Bool {
        guard let scrollGeometry else { return false }
        guard scrollGeometry.contentSize.height > scrollGeometry.containerSize.height + 1
        else { return false }
        return scrollGeometry.contentOffset.y + scrollGeometry.containerSize.height
            < scrollGeometry.contentSize.height - 1
    }

    /// Rows of FOR THIS STEP below the visible area or under the 32 pt fade.
    private var hiddenRowCount: Int {
        guard let scrollGeometry else { return 0 }
        let threshold = scrollGeometry.contentOffset.y
            + scrollGeometry.containerSize.height
            - KartaDesign.cooking.signalFadeHeight
        return rowBottoms.values.filter { $0 > threshold }.count
    }

    private var nextHiddenRowIndex: Int? {
        guard let scrollGeometry else { return nil }
        let threshold = scrollGeometry.contentOffset.y
            + scrollGeometry.containerSize.height
            - KartaDesign.cooking.signalFadeHeight
        return rowBottoms
            .filter { $0.value > threshold }
            .keys
            .min()
    }

    private var scrollFade: some View {
        LinearGradient(
            colors: [
                KartaDesign.ColorToken.card.opacity(0),
                KartaDesign.ColorToken.card
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: KartaDesign.cooking.signalFadeHeight)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    /// The signal chip: "N more ingredients" while rows are hidden, "More
    /// below" otherwise. A button — it scrolls to the next hidden row and
    /// never changes Paso.
    private func signalChip(proxy: ScrollViewProxy) -> some View {
        let hidden = hiddenRowCount
        let label = hidden == 0
            ? "More below"
            : "\(hidden) more ingredient\(hidden == 1 ? "" : "s")"
        return Button {
            withAnimation {
                if let next = nextHiddenRowIndex {
                    proxy.scrollTo(ScrollBodyAnchor.row(next), anchor: .top)
                } else {
                    proxy.scrollTo(ScrollBodyAnchor.end, anchor: .bottom)
                }
            }
        } label: {
            HStack(spacing: KartaDesign.space.rankGap) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                Text(label)
            }
            .font(.custom("Figtree", size: 13).weight(.heavy))
            .foregroundStyle(suit.chipInk)
            .padding(.horizontal, KartaDesign.space.chipX)
            .frame(height: KartaDesign.cooking.signalChipHeight)
            .background {
                Capsule()
                    .fill(suit.chipEdge)
                    .offset(y: KartaDesign.space.reverseButtonEdge)
                Capsule().fill(suit.chip)
            }
        }
        .accessibilityLabel("Scroll down for \(label.lowercased())")
        .padding(.trailing, KartaDesign.cooking.signalChipHInset)
        .padding(.bottom, KartaDesign.cooking.signalChipBottomGap)
    }

    // MARK: - Deck of Pasos

    /// Offsets of the upcoming cards peeking behind the front one (`paper`
    /// and `cardEdge[0]`, rotated 1.8° / 3.5°). Behind the last Paso peeks
    /// the finish card; the finish card has nothing behind it.
    private var peekOffsets: [Int] {
        guard !session.isOnFinish else { return [] }
        let remaining = session.steps.count - session.currentIndex
        return Array(0..<min(remaining, KartaDesign.cooking.peekCardCount))
    }

    private func peekCard(depth: Int) -> some View {
        RoundedRectangle(
            cornerRadius: KartaDesign.radius.card,
            style: .continuous
        )
        .fill(depth == 0 ? KartaDesign.ColorToken.paper : KartaDesign.ColorToken.cardEdges[0])
        .offset(y: depth == 0 ? KartaDesign.cooking.peek1Offset : KartaDesign.cooking.peek2Offset)
        .rotationEffect(.degrees(
            depth == 0 ? KartaDesign.cooking.peek1Rotation : KartaDesign.cooking.peek2Rotation
        ))
        .zIndex(Double(KartaDesign.cooking.peekCardCount - depth))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: KartaDesign.cooking.dragMinimumDistance)
            .onChanged { value in
                dismissSwipeHint()
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) else {
                    dragOffset = 0
                    return
                }
                dragOffset = horizontal
            }
            .onEnded { value in
                guard let command = CookingGestureDecision.command(
                    translation: value.translation,
                    predictedTranslation: value.predictedEndTranslation
                ) else {
                    withAnimation(KartaDesign.deckAnimation) {
                        dragOffset = 0
                    }
                    return
                }
                fly(to: command)
            }
    }

    /// The card leaves sideways like a card of the deck; the next one settles
    /// in from the other side. Reduce Motion: cross-fade.
    private func fly(to command: CookingCommand) {
        let direction: CGFloat = command == .next ? -1 : 1
        let exit = direction * UIScreen.main.bounds.width * KartaDesign.cooking.leavingTranslationScale
        if reduceMotion {
            dragOffset = 0
            send(command)
            return
        }
        withAnimation(KartaDesign.deckAnimation) {
            dragOffset = exit
        } completion: {
            dragOffset = -exit * 0.25
            send(command)
            withAnimation(KartaDesign.deckAnimation) {
                dragOffset = 0
            }
        }
    }

    private func handleTap(locationX: CGFloat, width: CGFloat) {
        guard let command = CookingTapDecision.command(
            locationX: locationX,
            width: width
        ) else { return }
        send(command)
    }

    /// Move straight to a Paso (the timer pill's target) through the existing
    /// next/previous seam.
    private func jump(to stepIndex: Int) {
        while store.session != nil && store.session?.currentIndex != stepIndex {
            let current = store.session?.currentIndex ?? 0
            if current < stepIndex {
                store.send(.nextStep(now: now))
            } else {
                store.send(.previousStep)
            }
        }
    }

    private func send(_ command: CookingCommand) {
        switch command {
        case .next:
            store.send(.nextStep(now: now))
        case .previous:
            store.send(.previousStep)
        }
    }
}

/// Coordinate space of the scrolling card body, shared by the row probes
/// that count hidden ingredient rows for the signal chip.
private enum ScrollBodySpace {
    static let name = "cookingScrollBody"
}

/// Scroll targets inside a card body: an ingredient row or the end marker.
private enum ScrollBodyAnchor: Hashable {
    case row(Int)
    case end
}

/// Pins a text to the spec's baseline-to-baseline line height: exact at the
/// default Dynamic Type size and scaled with the same curve afterwards, so
/// lines keep their spec'd proportion instead of overlapping at accessibility
/// sizes. A target below the font's natural line height (e.g. Fraunces 34 →
/// 39) needs iOS 26's exact line height — `lineSpacing` can only add space —
/// and a target above it adds the difference.
private struct SpecLineHeight: ViewModifier {
    let fontName: String
    let fontWeight: UIFont.Weight

    @ScaledMetric private var scaledSize: CGFloat
    @ScaledMetric private var scaledTarget: CGFloat

    init(
        fontName: String,
        fontWeight: UIFont.Weight,
        size: CGFloat,
        target: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) {
        self.fontName = fontName
        self.fontWeight = fontWeight
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        _scaledTarget = ScaledMetric(wrappedValue: target, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: fontName,
            .traits: [UIFontDescriptor.TraitKey.weight: fontWeight]
        ])
        let natural = UIFont(descriptor: descriptor, size: scaledSize).lineHeight
        return Group {
            if scaledTarget < natural {
                content.lineHeight(.exact(points: scaledTarget))
            } else {
                content.lineSpacing(scaledTarget - natural)
            }
        }
    }
}
