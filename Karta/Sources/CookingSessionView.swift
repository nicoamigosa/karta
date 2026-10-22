import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// Cooking mode: the Sesión de cocina. Renders what
/// `KartaStore.cookingStepPresentation` projects — one Paso per card, on the
/// same suit-coloured frame as the reverse — and reports shell events
/// (gestures, prompt responses, step arrivals) back as store actions. No rules
/// live here: transitions, clamping, the cooked event and the probably-cooked
/// inference are all decided by `CookingSession`.
struct CookingSessionView: View {
    let session: CookingSession
    let recipe: Recipe
    let clips: TechniqueClipLibrary
    let manifest: MediaAssetManifest
    let store: KartaStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var confirmLeave = false

    private var suit: SuitTokens {
        KartaDesign.suit(recipe.primaryCourse)
    }

    private var now: TimeInterval {
        Date().timeIntervalSince1970
    }

    private var presentation: CookingStepPresentation? {
        store.cookingStepPresentation(for: recipe, clips: clips, now: now)
    }

    var body: some View {
        ZStack {
            suit.back.ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    ForEach(peekOffsets.indices, id: \.self) { depth in
                        peekCard(depth: depth)
                    }

                    if let presentation {
                        card(presentation, width: geometry.size.width)
                            .zIndex(Double(KartaDesign.cooking.peekCardCount + 1))
                    }
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
            reportStepArrival()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: session.currentIndex) { _, _ in
            reportStepArrival()
        }
    }

    /// The signed-off text of the leave sheet (no board yet; the title carries
    /// the step position, e.g. "Leave cooking? You're on step 3 of 4.").
    private var leaveTitle: String {
        "Leave cooking? You're on step \(session.currentIndex + 1) of \(session.steps.count)."
    }

    // MARK: - The Paso's card

    private func card(
        _ presentation: CookingStepPresentation,
        width: CGFloat
    ) -> some View {
        CardRelief(edgeColors: KartaDesign.ColorToken.cardEdges) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    header(presentation)
                        .padding(.top, KartaDesign.cooking.headerTop)

                    Text(presentation.summary)
                    .font(KartaDesign.FontToken.cookSummary())
                    .tracking(-0.4)
                    .lineSpacing(5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .padding(.top, KartaDesign.cooking.summaryGap)

                Text(presentation.detail)
                    .font(KartaDesign.FontToken.cookDetail())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, KartaDesign.cooking.detailGap)
            }
            .padding(.horizontal, KartaDesign.cooking.cardInset)

            // The media window sits 12 pt from the card edges — wider than
            // the text blocks.
            mediaWindow(presentation)
                .padding(.top, KartaDesign.cooking.sectionGap)
                .padding(.horizontal, KartaDesign.cooking.mediaInset)

            ingredientsSection(presentation)
                .padding(.top, KartaDesign.cooking.sectionGap)
                .padding(.horizontal, KartaDesign.cooking.cardInset)

            Spacer(minLength: KartaDesign.cooking.freeSpaceMin)

            // Pinned bottom zone: separators run edge to edge, content
            // aligns on the card inset.
            bottomZone(presentation)
        }
        .padding(.bottom, KartaDesign.cooking.upNextVGap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / KartaDesign.deck.dragRotationDivisor)))
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleTap(locationX: location.x, width: width)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(session.currentIndex + 1) of \(session.steps.count): \(presentation.summary)")
    }

    // MARK: - Header: ✕ + progress bar

    private func header(_ presentation: CookingStepPresentation) -> some View {
        ZStack {
            progressBar(presentation)
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
    /// outlined pill; at zero it fills `brand` and reads "Time's up".
    private func progressBar(_ presentation: CookingStepPresentation) -> some View {
        HStack(spacing: KartaDesign.cooking.segmentGap) {
            ForEach(Array(presentation.progress.enumerated()), id: \.offset) { _, segment in
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
                .frame(height: KartaDesign.cooking.timerPillHeight)
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

    /// The 220 pt Foto del paso window. With a technique clip it keeps the
    /// photo but swaps the label chip for the clip's name and length and puts
    /// a play circle in the centre; playback itself is issue #12.
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
                        .background(Circle().fill(KartaDesign.ColorToken.card))
                }
                .accessibilityLabel("Play technique clip")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: KartaDesign.cooking.mediaHeight)
        .clipShape(RoundedRectangle(
            cornerRadius: KartaDesign.cooking.mediaRadius,
            style: .continuous
        ))
        .overlay(alignment: .bottomLeading) {
            Text(mediaChipLabel(presentation))
                .font(.custom("Figtree", size: 12).weight(.heavy))
                .foregroundStyle(suit.chipInk)
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
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .padding(.bottom, KartaDesign.cooking.ingredientRowGap)

            ForEach(presentation.ingredientRows, id: \.ingredientID) { row in
                (Text(row.quantity + " ")
                    .font(.custom("Figtree", size: 17).weight(.heavy))
                    + Text(row.name)
                    .font(.custom("Figtree", size: 17).weight(.medium)))
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Bottom zone

    @ViewBuilder
    private func bottomZone(_ presentation: CookingStepPresentation) -> some View {
        if session.isOnLastStep {
            VStack(spacing: 0) {
                edgeToEdgeLine
                Group {
                    if session.showsOutcomePrompt {
                        outcomeFooter
                    } else {
                        cookedFooter
                    }
                }
                .padding(.top, KartaDesign.cooking.upNextLineGap)
                .padding(.horizontal, KartaDesign.cooking.cardInset)
            }
        } else {
            VStack(spacing: 0) {
                if presentation.timerLabel != nil {
                    timerBlock(presentation)
                        .padding(.bottom, KartaDesign.cooking.timerTopGap)
                        .padding(.horizontal, KartaDesign.cooking.cardInset)
                }
                upNextRow(presentation)
            }
        }
    }

    /// The ready-state Temporizador block: declared duration, TIMER label and
    /// the brand play circle. Starting and running timers are issue #5; the
    /// play affordance is drawn but inert in this slice.
    private func timerBlock(_ presentation: CookingStepPresentation) -> some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: KartaDesign.space.cardGap) {
                Text(presentation.timerLabel ?? "")
                    .font(KartaDesign.FontToken.cookTimer())
                    .monospacedDigit()
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
                    .background(Circle().fill(KartaDesign.ColorToken.brand))
            }
            .accessibilityLabel("Start timer")
        }
        .padding(.horizontal, KartaDesign.cooking.upNextHGap)
        .padding(.vertical, KartaDesign.cooking.timerTopGap)
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

    private func upNextRow(_ presentation: CookingStepPresentation) -> some View {
        VStack(spacing: 0) {
            edgeToEdgeLine

            HStack(spacing: KartaDesign.space.cardGap) {
                upNextThumbnail(presentation)
                    .frame(
                        width: KartaDesign.cooking.upNextThumb,
                        height: KartaDesign.cooking.upNextThumb
                    )
                    .clipShape(RoundedRectangle(
                        cornerRadius: KartaDesign.cooking.upNextThumbRadius,
                        style: .continuous
                    ))

                VStack(alignment: .leading, spacing: KartaDesign.space.rankGap) {
                    Text((session.currentIndex == 0 ? "Up next · Swipe left" : "Up next").uppercased())
                        .font(KartaDesign.FontToken.rankUnit())
                        .tracking(KartaDesign.type.rankUnitTracking)
                        .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    Text(presentation.upNext?.summary ?? "")
                        .font(KartaDesign.FontToken.upNextSummary())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: KartaDesign.space.cardGap)
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            }
            .padding(.top, KartaDesign.cooking.upNextLineGap)
            .padding(.horizontal, KartaDesign.cooking.cardInset)
            .padding(.bottom, KartaDesign.cooking.upNextVGap - KartaDesign.space.cardBottom)
        }
    }

    @ViewBuilder
    private func upNextThumbnail(_ presentation: CookingStepPresentation) -> some View {
        if let photo = presentation.upNext?.photo {
            RecipePhoto(reference: photo, manifest: manifest)
        } else {
            ZStack {
                KartaDesign.ColorToken.cardEdges[0]
                Image(systemName: "camera")
                    .font(.system(size: 18))
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            }
        }
    }

    // MARK: - Last Paso: outcome prompt, then Finish

    private var outcomeFooter: some View {
        VStack(spacing: KartaDesign.space.cardGap) {
            Text("How did it turn out?")
                .font(KartaDesign.FontToken.cookOutcomeTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .frame(maxWidth: .infinity)

            HStack(spacing: KartaDesign.cooking.upNextHGap) {
                outcomeButton(outcome: .thumbsUp, icon: "hand.thumbsup", label: "Good")
                outcomeButton(outcome: .thumbsDown, icon: "hand.thumbsdown", label: "Not great")
                outcomeButton(outcome: .photo, icon: "camera", label: "Add photo")
            }
        }
    }

    private func outcomeButton(
        outcome: CookOutcome,
        icon: String,
        label: String
    ) -> some View {
        Button {
            store.send(.respond(outcome))
        } label: {
            VStack(spacing: KartaDesign.space.rankGap) {
                Image(systemName: icon)
                    .font(.system(size: KartaDesign.cooking.outcomeIcon, weight: .semibold))
                Text(label)
                    .font(KartaDesign.FontToken.button())
            }
            .foregroundStyle(KartaDesign.ColorToken.ink)
            .frame(maxWidth: .infinity)
            .frame(height: KartaDesign.cooking.outcomeButtonHeight)
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

    /// After an answer: check disc, "Cooked. Enjoy it!" and the primary Finish
    /// button, which ends the session without asking.
    private var cookedFooter: some View {
        VStack(spacing: KartaDesign.space.cardGap) {
            HStack(spacing: KartaDesign.space.cardGap) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(suit.chipInk)
                    .frame(
                        width: KartaDesign.cooking.cookedDisc,
                        height: KartaDesign.cooking.cookedDisc
                    )
                    .background(suit.chip, in: Circle())
                Text("Cooked. Enjoy it!")
                    .font(KartaDesign.FontToken.cookOutcomeTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
            }
            .frame(maxWidth: .infinity)

            Button {
                store.send(.exitCooking)
            } label: {
                Text("Finish")
                    .font(KartaDesign.FontToken.ctaLabel())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                    .frame(maxWidth: .infinity)
                    .frame(height: KartaDesign.cooking.finishHeight)
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
    }

    // MARK: - Deck of Pasos

    /// Offsets of the upcoming Pasos peeking behind the front card
    /// (`paper` and `cardEdge[0]`, rotated 1.8° / 3.5°). The last Paso has
    /// nothing behind it.
    private var peekOffsets: [Int] {
        let remaining = session.steps.count - session.currentIndex - 1
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

    /// The Paso leaves sideways like a card of the deck; the next one settles
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

    /// Report the Paso settling on screen: on the last one, let the session
    /// itself decide whether the journey already counts as a probable cook.
    private func reportStepArrival() {
        guard let step = session.currentStep else { return }
        for action in CookingStepArrival.actions(
            for: step,
            isLastStep: session.isOnLastStep,
            now: now
        ) {
            store.send(action)
        }
    }
}
