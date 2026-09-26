import SwiftUI
import KartaCore
import KartaPresentation

struct FeedScreen: View {
    let store: KartaStore

    @State private var recipes: [Recipe] = []
    @State private var manifest = MediaAssetManifest([:])
    @State private var isLoaded = false
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView(
                    "Catalog unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if !isLoaded {
                ProgressView("Loading recipes")
                    .font(KartaDesign.FontToken.body())
                    .tint(KartaDesign.ColorToken.brand)
            } else if let feed = store.feed(recipes: recipes, clock: SystemClock()) {
                if feed.isEmpty {
                    ContentUnavailableView(
                        "No compatible recipes",
                        systemImage: "fork.knife",
                        description: Text("There are no recipes compatible with your intolerances.")
                    )
                } else {
                    FeedDeck(
                        cards: FeedDeckCard.cards(in: feed),
                        manifest: manifest,
                        store: store
                    )
                }
            } else {
                OnboardingView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KartaDesign.ColorToken.paper)
        .foregroundStyle(KartaDesign.ColorToken.ink)
        .preferredColorScheme(.light)
        .task {
            do {
                let seed = SeedResourceAdapter()
                recipes = try seed.loadRecipes()
                manifest = try seed.loadMediaManifest()
                isLoaded = true
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private struct SystemClock: KartaClock {
    var now: Date { Date() }
}

private struct FeedDeck: View {
    let manifest: MediaAssetManifest
    let store: KartaStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cards: [FeedDeckCard]
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasInteracted = false
    @State private var entryOffset: CGFloat = 0
    @State private var entryRotation: Double = 0
    @State private var hintVisible = true
    @State private var transitionDirection = 0

    init(cards: [FeedDeckCard], manifest: MediaAssetManifest, store: KartaStore) {
        self.manifest = manifest
        self.store = store
        _cards = State(initialValue: cards)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("karta")
                .font(KartaDesign.FontToken.wordmark())
                .tracking(-0.8)
                .foregroundStyle(KartaDesign.ColorToken.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, KartaDesign.space.screenX)
                .accessibilityAddTraits(.isHeader)

            GeometryReader { geometry in
                ZStack {
                    ForEach(visibleCards.reversed()) { visible in
                        deckLayer(visible, size: geometry.size)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(firstTouchGesture)
                .onTapGesture(perform: openCurrentCard)
            }
            .padding(.top, KartaDesign.space.headerToDeck)
            .padding(.horizontal, KartaDesign.space.screenX)

            Text("Swipe up or down")
                .font(KartaDesign.FontToken.hint())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .frame(height: KartaDesign.deck.hintHeight)
                .opacity(hintVisible ? 1 : 0)
                .animation(
                    .easeOut(duration: KartaDesign.deck.hintFadeDuration),
                    value: hintVisible
                )
        }
        .onAppear {
            recordSettledCard()
            Task { @MainActor in
                await runEntryNudge()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(KartaDesign.deck.hintFadeDelay))
            hintVisible = false
        }
    }

    private var visibleCards: [VisibleDeckCard] {
        guard !cards.isEmpty else { return [] }
        return (0...2).compactMap { relativeIndex in
            let index = currentIndex + relativeIndex
            guard cards.indices.contains(index) else { return nil }
            return VisibleDeckCard(card: cards[index], relativeIndex: relativeIndex)
        }
    }

    @ViewBuilder
    private func deckLayer(_ visible: VisibleDeckCard, size: CGSize) -> some View {
        let position = DeckPosition(relativeIndex: visible.relativeIndex)

        Group {
            if visible.relativeIndex == 0 {
                if let presentation = store.state.onboarding.cardPresentation(
                    for: visible.card.recipe
                ) {
                    RecipeCardView(
                        card: visible.card,
                        presentation: presentation,
                        manifest: manifest
                    )
                    .transition(
                        .opacity.animation(
                            .easeIn(duration: KartaDesign.deck.faceRevealDuration)
                                .delay(KartaDesign.deck.faceRevealDelay)
                        )
                    )
                }
            } else {
                CardBack(course: visible.card.recipe.primaryCourse)
            }
        }
        .padding(.leading, position.left)
        .padding(.trailing, position.right)
        .padding(.top, position.top)
        .padding(.bottom, position.bottom)
        .rotationEffect(.degrees(position.rotation))
        .offset(y: visible.relativeIndex == 0 ? dragOffset + entryOffset : 0)
        .rotationEffect(
            .degrees(
                visible.relativeIndex == 0
                    ? Double(dragOffset / KartaDesign.deck.dragRotationDivisor) + entryRotation
                    : 0
            )
        )
        .opacity(frontOpacity(relativeIndex: visible.relativeIndex, height: size.height))
        .zIndex(Double(3 - visible.relativeIndex))
        .transition(cardTransition)
        .animation(
            reduceMotion ? .easeOut(duration: KartaDesign.deck.faceRevealDuration) : KartaDesign.deckAnimation,
            value: currentIndex
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: KartaDesign.space.cardGap)
            .onChanged { value in
                let vertical = value.translation.height
                let horizontal = abs(value.translation.width)
                guard abs(vertical) > horizontal else { return }
                dragOffset = vertical
            }
            .onEnded { value in
                let destination = DeckNavigator.destination(
                    from: currentIndex,
                    predictedTranslation: value.predictedEndTranslation.height,
                    cardCount: cards.count
                )
                guard destination != currentIndex else {
                    withAnimation(KartaDesign.deckAnimation) {
                        dragOffset = 0
                    }
                    return
                }

                transitionDirection = destination > currentIndex ? 1 : -1
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: KartaDesign.deck.faceRevealDuration)
                        : KartaDesign.deckAnimation
                ) {
                    currentIndex = destination
                    dragOffset = 0
                } completion: {
                    recordSettledCard()
                }
            }
    }

    private var firstTouchGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                stopEntryNudge()
            }
    }

    private var cardTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let y = transitionDirection >= 0 ? -KartaDesign.deck.nudgeDistance : KartaDesign.deck.nudgeDistance
        return .asymmetric(
            insertion: .offset(y: -y).combined(with: .opacity),
            removal: .offset(y: y).combined(with: .opacity)
        )
    }

    private func frontOpacity(relativeIndex: Int, height: CGFloat) -> Double {
        guard relativeIndex == 0, height > 0 else { return 1 }
        return max(0, 1 - Double(abs(dragOffset) / height))
    }

    private func recordSettledCard() {
        guard cards.indices.contains(currentIndex) else { return }
        let card = cards[currentIndex]
        store.send(.recordView(recipeID: card.id, at: Date()))
        cards[currentIndex].alreadySeen = true
    }

    private func openCurrentCard() {
        stopEntryNudge()
        guard cards.indices.contains(currentIndex) else { return }
        let recipeID = cards[currentIndex].id
        store.send(.recordOpen(recipeID: recipeID, at: Date()))
        store.send(.pushRoute(.recipeDetail(recipeID: recipeID)))
    }

    @MainActor
    private func runEntryNudge() async {
        guard !reduceMotion, !hasInteracted else { return }
        do {
            try await Task.sleep(for: .seconds(KartaDesign.deck.nudgeDelay))
        } catch {
            return
        }
        guard !hasInteracted else { return }

        for _ in 0..<2 {
            withAnimation(.easeOut(duration: KartaDesign.deck.nudgeLiftDuration)) {
                entryOffset = -KartaDesign.deck.nudgeDistance
                entryRotation = KartaDesign.deck.nudgeRotation
            }
            do {
                try await Task.sleep(for: .seconds(KartaDesign.deck.nudgeLiftDuration))
            } catch {
                return
            }
            guard !hasInteracted else { return }
            withAnimation(.easeOut(duration: KartaDesign.deck.nudgeSettleDuration)) {
                entryOffset = 0
                entryRotation = 0
            }
            do {
                try await Task.sleep(for: .seconds(
                    KartaDesign.deck.nudgeSettleDuration + KartaDesign.deck.nudgeRestDuration
                ))
            } catch {
                return
            }
            guard !hasInteracted else { return }
        }
    }

    private func stopEntryNudge() {
        guard !hasInteracted else { return }
        hasInteracted = true
        hintVisible = false
        entryOffset = 0
        entryRotation = 0
    }
}

private struct VisibleDeckCard: Identifiable {
    let card: FeedDeckCard
    let relativeIndex: Int

    var id: String { card.id }
}

private struct DeckPosition {
    let left: CGFloat
    let right: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    let rotation: Double

    init(relativeIndex: Int) {
        switch relativeIndex {
        case 1:
            left = KartaDesign.deck.back1Left
            right = KartaDesign.deck.back1Right
            top = KartaDesign.deck.back1Top
            bottom = KartaDesign.deck.back1Bottom
            rotation = KartaDesign.deck.back1Rotation
        case 2:
            left = KartaDesign.deck.back2Left
            right = KartaDesign.deck.back2Right
            top = KartaDesign.deck.back2Top
            bottom = KartaDesign.deck.back2Bottom
            rotation = KartaDesign.deck.back2Rotation
        default:
            left = 0
            right = 0
            top = 0
            bottom = KartaDesign.deck.frontBottomInset
            rotation = 0
        }
    }
}

private struct RecipeCardView: View {
    let card: FeedDeckCard
    let presentation: RecipeCardPresentation
    let manifest: MediaAssetManifest

    private var suit: SuitTokens {
        KartaDesign.suit(presentation.primaryCourse)
    }

    var body: some View {
        CardRelief(edgeColors: KartaDesign.ColorToken.cardEdges) {
            VStack(alignment: .leading, spacing: KartaDesign.space.cardGap) {
                HStack(alignment: .firstTextBaseline) {
                    Text(presentation.durationLabel)
                        .font(KartaDesign.FontToken.rank())
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                    Spacer(minLength: KartaDesign.space.cardGap)
                    Text(presentation.primaryCourse.rawValue)
                        .font(KartaDesign.FontToken.suitLabel())
                }
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .padding(.horizontal, KartaDesign.space.cardTextInset)

                RecipePhoto(reference: card.recipe.heroPhoto, manifest: manifest)
                    .clipShape(RoundedRectangle(
                        cornerRadius: KartaDesign.radius.photo,
                        style: .continuous
                    ))

                VStack(alignment: .leading, spacing: KartaDesign.space.cardGap) {
                    Text(presentation.name)
                        .font(KartaDesign.FontToken.cardTitle())
                        .tracking(-0.6)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: KartaDesign.space.chipGap) {
                        CardChip(label: presentation.servingsLabel, suit: suit)
                        CardChip(label: presentation.difficultyLabel.capitalized, suit: suit)
                        Spacer(minLength: 0)
                        if card.alreadySeen {
                            Text("seen")
                                .font(KartaDesign.FontToken.hint())
                                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                        }
                    }
                }
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .padding(.horizontal, KartaDesign.space.cardTextInset)
            }
            .padding(.top, KartaDesign.space.cardTop)
            .padding(.horizontal, KartaDesign.space.cardX)
            .padding(.bottom, KartaDesign.space.cardBottom)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(presentation.name), \(presentation.durationLabel), "
                + "\(presentation.servingsLabel), \(presentation.difficultyLabel), "
                + "\(presentation.primaryCourse.rawValue)"
        )
        .accessibilityHint("Double-tap to open. Swipe up or down for another recipe.")
    }
}

private struct CardChip: View {
    let label: String
    let suit: SuitTokens

    var body: some View {
        Text(label)
            .font(KartaDesign.FontToken.chip())
            .foregroundStyle(suit.chipInk)
            .padding(.vertical, KartaDesign.space.chipY)
            .padding(.horizontal, KartaDesign.space.chipX)
            .background(
                suit.chip,
                in: RoundedRectangle(
                    cornerRadius: KartaDesign.radius.chip,
                    style: .continuous
                )
            )
    }
}

private struct CardBack: View {
    let course: Course

    private var suit: SuitTokens { KartaDesign.suit(course) }

    var body: some View {
        CardRelief(edgeColors: Array(repeating: suit.edge, count: 4), back: true) {
            RoundedRectangle(
                cornerRadius: KartaDesign.radius.card,
                style: .continuous
            )
            .fill(suit.back)
            .overlay {
                RoundedRectangle(
                    cornerRadius: KartaDesign.radius.cardBackFrame,
                    style: .continuous
                )
                .stroke(KartaDesign.ColorToken.card, lineWidth: 1)
                .padding(KartaDesign.space.backFrameInset)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CardRelief<Content: View>: View {
    let edgeColors: [Color]
    var back = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            ForEach(Array(edgeColors.enumerated()).reversed(), id: \.offset) { layer in
                RoundedRectangle(
                    cornerRadius: KartaDesign.radius.card,
                    style: .continuous
                )
                .fill(layer.element)
                .offset(y: CGFloat(layer.offset + 1))
            }

            content()
                .background(
                    KartaDesign.ColorToken.card,
                    in: RoundedRectangle(
                        cornerRadius: KartaDesign.radius.card,
                        style: .continuous
                    )
                )
                .clipShape(RoundedRectangle(
                    cornerRadius: KartaDesign.radius.card,
                    style: .continuous
                ))
        }
        .shadow(
            color: KartaDesign.ColorToken.shadow.opacity(back ? 0.35 / 0.45 : 1),
            radius: back
                ? KartaDesign.elevation.backShadowRadius
                : KartaDesign.elevation.frontShadowRadius,
            y: back
                ? KartaDesign.elevation.backShadowY
                : KartaDesign.elevation.frontShadowY
        )
    }
}

private struct OnboardingView: View {
    let store: KartaStore

    var body: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.onboardingGap) {
            Text("karta")
                .font(KartaDesign.FontToken.wordmark())
                .tracking(-0.8)
                .foregroundStyle(KartaDesign.ColorToken.brand)

            if case .unanswered = store.state.onboarding.intoleranceAnswer {
                Text("Do you avoid dairy?")
                    .font(KartaDesign.FontToken.cardTitle())
                Text("If you do, recipes containing dairy won't appear in your feed. Other intolerances are not supported yet.")
                    .font(KartaDesign.FontToken.body())
                TactileButton("Yes, avoid dairy") {
                    store.send(.onboarding(.answerIntolerances([.dairy])))
                }
                TactileButton("No dairy intolerance") {
                    store.send(.onboarding(.answerIntolerances([])))
                }
            } else {
                Text("How many in your household?")
                    .font(KartaDesign.FontToken.cardTitle())
                Text("We'll put recipes that fit your household first, without hiding the rest.")
                    .font(KartaDesign.FontToken.body())
                ForEach(1...6, id: \.self) { size in
                    TactileButton("\(size) \(size == 1 ? "person" : "people")") {
                        store.send(.onboarding(.setHouseholdSize(size)))
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(KartaDesign.space.onboarding)
    }
}

private struct TactileButton: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(label, action: action)
            .font(KartaDesign.FontToken.button())
            .foregroundStyle(KartaDesign.ColorToken.card)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KartaDesign.space.cardGap)
            .background(
                KartaDesign.ColorToken.ink,
                in: RoundedRectangle(
                    cornerRadius: KartaDesign.radius.chip,
                    style: .continuous
                )
            )
            .shadow(
                color: KartaDesign.ColorToken.shadow.opacity(0.25 / 0.45),
                radius: KartaDesign.elevation.buttonShadowRadius,
                y: KartaDesign.elevation.buttonShadowY
            )
    }
}

private struct RecipePhoto: View {
    let reference: MediaReference
    let manifest: MediaAssetManifest

    var body: some View {
        Group {
            if let media = try? MediaResolver(manifest: manifest, baseURL: nil).resolve(reference) {
                switch media {
                case let .remote(url):
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFill()
                        case .empty:
                            ProgressView().tint(KartaDesign.ColorToken.brand)
                        case .failure:
                            unavailable
                        @unknown default:
                            unavailable
                        }
                    }
                case let .bundle(resource):
                    if let bundleURL = Bundle.main.url(
                        forResource: "KartaCore_KartaPresentation",
                        withExtension: "bundle"
                    ),
                    let bundle = Bundle(url: bundleURL),
                    let url = bundle.url(forResource: resource, withExtension: nil),
                    let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        unavailable
                    }
                }
            } else {
                unavailable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var unavailable: some View {
        ContentUnavailableView("Photo unavailable", systemImage: "photo")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KartaDesign.ColorToken.line)
    }
}
