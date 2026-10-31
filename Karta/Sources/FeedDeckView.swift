import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

struct FeedScreen: View {
    let store: KartaStore

    @State private var recipes: [Recipe] = []
    // An empty clip library cannot fail validation; clips load with the seed.
    @State private var clips = try! TechniqueClipLibrary(clips: [])
    @State private var manifest = MediaAssetManifest([:])
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var cookbookOpen = false
    @State private var reverseFromCookbook = false
    @State private var unsaveOrigin: UnsaveOrigin = .feedReverse
    /// The payload currently in the native share sheet; nil while Share is
    /// switched off or no sheet is up.
    @State private var presentedShare: PresentedShare?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                if cookbookOpen {
                    // The cookbook is not a Mundo: its own door opens and
                    // closes it, in place of the deck.
                    CookbookScreen(
                        recipes: recipes,
                        manifest: manifest,
                        store: store,
                        onClose: {
                            // Leaving the surface that hosts the toast
                            // dismisses it — same rule as the reverse's ✕.
                            store.send(.dismissUnsaveToast)
                            cookbookOpen = false
                        },
                        onOpenRecipe: { row in
                            reverseFromCookbook = true
                            store.send(.pushRoute(.recipeDetail(recipeID: row.recipeID)))
                        },
                        onUnsaveFromGrid: { row in
                            unsaveOrigin = .cookbookGrid
                            store.send(.unsaveRecipe(row.recipeID))
                        },
                        onShare: { row in
                            if let recipe = recipes.first(where: { $0.id == row.recipeID }),
                               let payload = ShareLinks.payload(for: recipe, in: store) {
                                presentedShare = PresentedShare(payload: payload)
                            }
                        },
                        onUndo: { toast in
                            store.send(.undoUnsave)
                            // Undo returns the card to its slot and opens the
                            // reverse again — not an Apertura. Skipped when the
                            // toast raced its own expiry and nothing was restored.
                            if unsaveOrigin.undoReopensReverse,
                               store.cookbook.isSaved(toast.recipeID) {
                                store.send(.pushRoute(.recipeDetail(recipeID: toast.recipeID)))
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    FeedSurface(
                        feed: feed,
                        recipes: recipes,
                        manifest: manifest,
                        store: store,
                        onOpenCookbook: {
                            cookbookOpen = true
                        },
                        onOpenCard: {
                            reverseFromCookbook = false
                        }
                    )
                    .transition(.opacity)
                }
            } else {
                OnboardingView(store: store)
            }
        }
        .overlay {
            if let recipe = RecipeReverseRoute.recipe(
                for: store.state.navigation.routes,
                in: recipes
            ), let reverse = store.reversePresentation(for: recipe) {
                RecipeReverseView(
                    recipe: recipe,
                    presentation: reverse,
                    manifest: manifest,
                    store: store,
                    openedFromCookbook: reverseFromCookbook,
                    onUnsave: {
                        unsaveOrigin = reverseFromCookbook
                            ? .cookbookReverse
                            : .feedReverse
                    },
                    unsaveToast: store.unsaveToast(recipes: recipes),
                    onUndo: {
                        store.send(.undoUnsave)
                    }
                )
                .transition(reverseTransition)
            }

            if let session = store.session,
               let recipe = CookingRoute.recipe(for: session, in: recipes) {
                CookingSessionView(
                    session: session,
                    recipe: recipe,
                    clips: clips,
                    manifest: manifest,
                    store: store,
                    onShare: { payload in
                        presentedShare = PresentedShare(payload: payload)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: KartaDesign.deck.faceRevealDuration) : KartaDesign.deckAnimation,
            value: store.session?.isExited == false
        )
        .animation(
            reduceMotion ? .easeOut(duration: KartaDesign.deck.faceRevealDuration) : KartaDesign.deckAnimation,
            value: cookbookOpen
        )
        .animation(
            reduceMotion ? .easeOut(duration: KartaDesign.deck.faceRevealDuration) : KartaDesign.deckAnimation,
            value: store.state.navigation.routes.last
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KartaDesign.ColorToken.paper)
        .foregroundStyle(KartaDesign.ColorToken.ink)
        .preferredColorScheme(.light)
        .sheet(item: $presentedShare) { presented in
            ShareSheetView(
                payload: presented.payload,
                image: ShareLinks.image(for: presented.payload.photo, manifest: manifest)
            )
        }
        .onOpenURL { openRecipeLink($0) }
        // Universal links arrive as NSUserActivity once #155's Associated
        // Domains entry exists; `onOpenURL` keeps custom-scheme opens working.
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                openRecipeLink(url)
            }
        }
        .task {
            do {
                let seed = SeedResourceAdapter()
                recipes = (try seed.loadRecipes() + DebugSeeds.extraRecipes())
                    .filter { !DebugSeeds.droppedRecipeIDs.contains($0.id) }
                clips = try DebugSeeds.clipLibrary(loading: seed)
                manifest = try DebugSeeds.mediaManifest(loading: seed)
                isLoaded = true
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private extension FeedScreen {
    /// One shared link: the store resolves it (reverse/Apertura, gone
    /// notice, not offered, ignored); the shell only mirrors the outcome.
    func openRecipeLink(_ url: URL) {
        switch store.openRecipeLink(url, recipes: recipes, at: Date()) {
        case .gone:
            // "The app opens the Feed": close the cookbook over it.
            cookbookOpen = false
        case .reverse:
            reverseFromCookbook = cookbookOpen
        case .notOffered, .ignored:
            break
        }
    }

    var reverseTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: KartaDesign.deck.reverseAppearScale).combined(with: .opacity)
    }
}

private struct SystemClock: KartaClock {
    var now: Date { Date() }
}

/// What `.sheet(item:)` presents: the contract's `SharePayload` isn't
/// Identifiable, so the shell wraps it.
private struct PresentedShare: Identifiable {
    let payload: SharePayload
    var id: URL { payload.url }
}

/// The one-shot notice after opening the link of a recipe that is no
/// longer in the catalogue (`share-recipe-gone.png`): the cookbook box
/// glyph in `card`, *This recipe is no longer on Karta* over *Here's your
/// deck instead.* on `ink` — the Undo toast's recipe without a button; it
/// leaves on its own after 5 s.
private struct RecipeGoneToastView: View {
    let notice: RecipeGoneNotice
    let onExpire: () -> Void

    var body: some View {
        HStack(spacing: KartaDesign.space.toastPadding) {
            CookbookBoxGlyph(ink: KartaDesign.ColorToken.card)
                .frame(
                    width: KartaDesign.space.doorGlyph + 6,
                    height: KartaDesign.space.doorGlyph + 6
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(KartaDesign.FontToken.toastTitle())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                Text(notice.message)
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
        .task(id: notice) {
            try? await Task.sleep(for: .seconds(KartaDesign.space.toastDuration))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}

/// The feed surface shared by both Mundos: the header row (wordmark, filter
/// button, Mundo pill, cookbook door) over the active Mundo's content — the
/// deck or, when the For You feed runs out, its empty state — plus the Mundo
/// menu, the filter panel and their scrims. The deck keeps each Mundo's
/// position through the session anchors (ADR 0009); switching Mundos never
/// touches the filters.
private struct FeedSurface: View {
    let feed: Feed
    let recipes: [Recipe]
    let manifest: MediaAssetManifest
    let store: KartaStore
    let onOpenCookbook: () -> Void
    let onOpenCard: () -> Void

    @State private var mundoMenuOpen = DebugSeeds.opensMundoMenu
    @State private var filterPanelOpen = DebugSeeds.opensFilterPanel
    @State private var filterButtonCenter: CGFloat = 0

    private var world: World {
        store.state.navigation.world
    }

    private var cards: [FeedDeckCard] {
        FeedDeckCard.cards(in: feed)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    FeedHeader(
                        store: store,
                        mundoMenuOpen: mundoMenuOpen,
                        filterPressed: filterPanelOpen,
                        onToggleMundoMenu: {
                            closePanel()
                            withAnimation(.easeOut(duration: KartaDesign.deck.faceRevealDuration)) {
                                mundoMenuOpen.toggle()
                            }
                        },
                        onOpenCookbook: {
                            mundoMenuOpen = false
                            filterPanelOpen = false
                            onOpenCookbook()
                        },
                        onFilter: {
                            // Tapping the button again discards the draft.
                            if filterPanelOpen { closePanel() } else { openPanel() }
                        },
                        onFilterButtonCenter: { filterButtonCenter = $0 }
                    )
                    .padding(.top, KartaDesign.space.headerTopGap)

                    Group {
                        switch world {
                        case .forYou:
                            if cards.isEmpty {
                                FeedEmptyStateView(
                                    state: store.feedEmptyState(
                                        recipes: recipes,
                                        clock: SystemClock()
                                    ),
                                    onChangeFilters: { openPanel() },
                                    onClearFilters: { store.send(.filter(.reset)) }
                                )
                            } else {
                                FeedDeck(
                                    cards: cards,
                                    manifest: manifest,
                                    store: store,
                                    onOpenCard: onOpenCard
                                )
                            }
                        case .leftovers:
                            LeftoversPlaceholder()
                        }
                    }
                    // A Mundo switch or any change to the effective filters
                    // (applied draft or Intolerancias) rebuilds the surface;
                    // the reducer discarded the anchors in the same action,
                    // so the rebuilt deck starts at the top.
                    .id(FeedDeckIdentity.key(
                        world: world,
                        filters: store.state.effectiveFeedFilters
                    ))
                }

                // The recipe-gone toast, 12 pt below the header row and
                // 22 pt from the sides (`share-recipe-gone.png`).
                if let notice = store.state.recipeGoneNotice {
                    VStack(spacing: 0) {
                        RecipeGoneToastView(
                            notice: notice,
                            onExpire: { store.send(.dismissRecipeGoneNotice) }
                        )
                        .padding(.top, headerClearance(in: geometry)
                                 + KartaDesign.space.cardGap)
                        .padding(.horizontal, KartaDesign.space.toastSideMargin)
                        Spacer(minLength: 0)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if mundoMenuOpen || filterPanelOpen {
                    ZStack(alignment: .top) {
                        // Everything below the header row is dimmed; tapping
                        // the scrim closes what is open.
                        VStack(spacing: 0) {
                            Color.clear.frame(height: headerClearance(in: geometry))
                            KartaDesign.ColorToken.scrim
                                .onTapGesture {
                                    closeMenu()
                                    closePanel()
                                }
                        }
                        .accessibilityHidden(true)

                        if mundoMenuOpen {
                            HStack {
                                Spacer(minLength: 0)
                                MundoMenuView(
                                    store: store,
                                    onSelect: { store.send(.selectWorld($0)) },
                                    onDismiss: { closeMenu() }
                                )
                                .padding(.top, headerClearance(in: geometry)
                                         + KartaDesign.space.mundoMenuTopGap)
                                .padding(.trailing, menuTrailingInset)
                            }
                        }

                        if filterPanelOpen {
                            VStack {
                                FilterPanelView(
                                    store: store,
                                    recipes: recipes,
                                    clock: SystemClock(),
                                    maxHeight: panelMaxHeight(in: geometry),
                                    onApply: { closePanel() }
                                )
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
                                // The pointer is outside the clip: its top
                                // half sticks out of the panel's top edge and
                                // its centre sits on the filter button.
                                .overlay(alignment: .topLeading) {
                                    PanelPointer()
                                        .offset(
                                            x: filterButtonCenter
                                                - KartaDesign.space.filterPanelInset
                                                - KartaDesign.space.panelPeak / 2,
                                            y: -KartaDesign.space.panelPeak / 2
                                        )
                                }
                                .padding(.top, headerClearance(in: geometry)
                                         + KartaDesign.space.filterPanelTopGap)
                                .padding(.horizontal, KartaDesign.space.filterPanelInset)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: FeedLayout.coordinateSpace)
        }
    }

    /// Clear zone above the scrim: status-bar area, the 6 pt header gap and
    /// the header row itself stay undimmed.
    private func headerClearance(in geometry: GeometryProxy) -> CGFloat {
        geometry.safeAreaInsets.top
            + KartaDesign.space.headerTopGap
            + KartaDesign.space.headerRowHeight
    }

    /// The menu's right edge sits on the pill's right edge: side margin plus
    /// the door and the 10 pt between pill and door.
    private var menuTrailingInset: CGFloat {
        KartaDesign.space.screenX
            + KartaDesign.space.doorButton
            + KartaDesign.space.headerButtonGap
    }

    /// The panel hugs its content up to the top of the bottom safe area.
    private func panelMaxHeight(in geometry: GeometryProxy) -> CGFloat {
        geometry.size.height
            + geometry.safeAreaInsets.top
            - headerClearance(in: geometry)
            - KartaDesign.space.filterPanelTopGap
    }

    private func openPanel() {
        closeMenu()
        withAnimation(.easeOut(duration: KartaDesign.deck.faceRevealDuration)) {
            filterPanelOpen = true
        }
    }

    /// Closing the panel without applying throws the draft away; the panel's
    /// draft dies with it and any saved Intolerancias stay saved.
    private func closePanel() {
        store.send(.filter(.cancel))
        withAnimation(.easeOut(duration: KartaDesign.deck.faceRevealDuration)) {
            filterPanelOpen = false
        }
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: KartaDesign.deck.faceRevealDuration)) {
            mundoMenuOpen = false
        }
    }
}

/// The two empty states of the For You feed (`docs/design/karta-v1.md` →
/// *Empty states*): centred where the deck would be, on `paper`, with the
/// header (badge included) still on top. The copy and the reason come from
/// `FeedEmptyState` (#127); the view only draws and sends the two actions.
private struct FeedEmptyStateView: View {
    let state: FeedEmptyState?
    let onChangeFilters: () -> Void
    let onClearFilters: () -> Void

    var body: some View {
        switch state {
        case .noMatchForFilters(let summary, let keptIntolerances):
            VStack(spacing: 0) {
                FilterSlidersGlyph(ink: KartaDesign.ColorToken.mutedStroke, field: KartaDesign.ColorToken.paper)
                    .frame(
                        width: KartaDesign.space.emptyIcon,
                        height: KartaDesign.space.emptyIcon
                    )
                    .padding(.bottom, KartaDesign.space.onboardingGap)
                Text("Nothing fits these filters")
                    .font(KartaDesign.FontToken.emptyTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, KartaDesign.space.chipGap)
                Text(summary)
                    .font(KartaDesign.FontToken.emptyBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, KartaDesign.space.onboardingGap)

                VStack(spacing: KartaDesign.space.ctaGap) {
                    BrandCTAButton("Change filters", action: onChangeFilters)
                    TactileCardButton("Clear all filters", action: onClearFilters)
                }

                if let keptIntolerances {
                    HStack(alignment: .top, spacing: KartaDesign.space.chipGap) {
                        ShieldGlyph(ink: KartaDesign.ColorToken.inkMuted)
                            .frame(
                                width: KartaDesign.space.shieldHeading,
                                height: KartaDesign.space.shieldHeading
                            )
                            .alignmentGuide(.top) { $0[.top] + 3 }
                        Text("Clearing keeps your intolerances: \(keptIntolerances).")
                            .font(KartaDesign.FontToken.cupoCount())
                            .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, KartaDesign.space.onboardingGap)
                }
            }
            .padding(.horizontal, KartaDesign.space.emptyStateX)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
        case .noMatchForProfile(let allergens):
            VStack(spacing: 0) {
                ShieldGlyph(ink: KartaDesign.ColorToken.mutedStroke)
                    .frame(
                        width: KartaDesign.space.emptyIcon,
                        height: KartaDesign.space.emptyIcon
                    )
                    .padding(.bottom, KartaDesign.space.onboardingGap)
                Text("No recipes fit your\nintolerances yet")
                    .font(KartaDesign.FontToken.emptyTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, KartaDesign.space.chipGap)
                Text("None of our recipes is free of \(allergens). That gap is ours to fill, not yours.")
                    .font(KartaDesign.FontToken.emptyBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, KartaDesign.space.onboardingGap)

                TactileCardButton("Check my intolerances", action: onChangeFilters)
            }
            .padding(.horizontal, KartaDesign.space.emptyStateX)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .some(.none), nil:
            EmptyView()
        }
    }
}

/// The primary action: `brand` fill, 54 pt, radius 18, Figtree 800 17 `card`,
/// 3 pt `brandEdge` plus the soft shadow.
struct BrandCTAButton: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(label, action: action)
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
            .shadow(
                color: KartaDesign.ColorToken.buttonShadow,
                radius: KartaDesign.elevation.buttonShadowRadius,
                y: KartaDesign.elevation.buttonShadowY
            )
    }
}

/// The tactile secondary action: `card` fill, 1 pt `line`, 2 pt `buttonEdge`,
/// 54 pt, Figtree 800 17 `ink`.
struct TactileCardButton: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(label, action: action)
            .font(KartaDesign.FontToken.cookFinishLabel())
            .foregroundStyle(KartaDesign.ColorToken.ink)
            .frame(maxWidth: .infinity)
            .frame(height: KartaDesign.space.ctaHeight)
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
}

/// Leftovers is reachable from the Mundo menu but its feed is issue #9: the
/// store has no Leftovers seam yet, so the Mundo shows a placeholder in the
/// established empty-state style.
private struct LeftoversPlaceholder: View {
    var body: some View {
        VStack(spacing: KartaDesign.space.chipGap) {
            BowlGlyph(ink: KartaDesign.ColorToken.mutedStroke)
                .frame(
                    width: KartaDesign.space.emptyIcon,
                    height: KartaDesign.space.emptyIcon
                )
            Text("Leftovers")
                .font(KartaDesign.FontToken.emptyTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
            Text("Reuse what you cooked")
                .font(KartaDesign.FontToken.emptyBody())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FeedDeck: View {
    let manifest: MediaAssetManifest
    let store: KartaStore
    /// Called when the front Card is tapped open.
    let onOpenCard: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cards: [FeedDeckCard]
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasInteracted = false
    @State private var entryOffset: CGFloat = 0
    @State private var entryRotation: Double = 0
    @State private var hintVisible = true
    @State private var transitionDirection = 0

    init(
        cards: [FeedDeckCard],
        manifest: MediaAssetManifest,
        store: KartaStore,
        onOpenCard: @escaping () -> Void
    ) {
        self.manifest = manifest
        self.store = store
        self.onOpenCard = onOpenCard
        _cards = State(initialValue: cards)
        _currentIndex = State(initialValue: FeedDeckAnchor.initialIndex(
            cards: cards,
            navigation: store.state.navigation
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack {
                    ForEach(visibleCards.reversed()) { visible in
                        deckLayer(visible, size: geometry.size)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .overlay {
                    FirstTouchCapture(action: stopEntryNudge)
                        .accessibilityHidden(true)
                }
                .gesture(dragGesture)
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
        return (0...KartaDesign.deck.backCardCount).compactMap { relativeIndex in
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
                if let presentation = store.state.cardPresentation(
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
        .zIndex(Double(KartaDesign.deck.visibleCardCount - visible.relativeIndex))
        .transition(cardTransition(height: size.height))
        .animation(
            reduceMotion ? .easeOut(duration: KartaDesign.deck.faceRevealDuration) : KartaDesign.deckAnimation,
            value: currentIndex
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: KartaDesign.deck.dragMinimumDistance)
            .onChanged { value in
                let vertical = value.translation.height
                let horizontal = abs(value.translation.width)
                guard abs(vertical) > horizontal else {
                    dragOffset = 0
                    return
                }
                dragOffset = vertical
            }
            .onEnded { value in
                let destination = DeckNavigator.destination(
                    from: currentIndex,
                    translation: value.translation,
                    predictedTranslation: value.predictedEndTranslation,
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

    private func cardTransition(height: CGFloat) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let flight = AnyTransition.modifier(
            active: DeckFlightModifier(
                offset: -height * KartaDesign.deck.leavingTranslationScale,
                rotation: KartaDesign.deck.leavingRotation,
                opacity: 0
            ),
            identity: DeckFlightModifier(
                offset: 0,
                rotation: 0,
                opacity: 1
            )
        )
        return transitionDirection >= 0
            ? .asymmetric(insertion: .identity, removal: flight)
            : .asymmetric(insertion: flight, removal: .identity)
    }

    private func frontOpacity(relativeIndex: Int, height: CGFloat) -> Double {
        guard relativeIndex == 0, height > 0 else { return 1 }
        return max(0, 1 - Double(abs(dragOffset) / height))
    }

    private func recordSettledCard() {
        guard cards.indices.contains(currentIndex) else { return }
        let card = cards[currentIndex]
        store.send(.recordView(recipeID: card.id, at: Date()))
        store.send(.setFeedAnchor(
            ScrollAnchor(recipeID: card.id, relativeOffset: 0),
            world: store.state.navigation.world
        ))
    }

    private func openCurrentCard() {
        stopEntryNudge()
        guard cards.indices.contains(currentIndex) else { return }
        onOpenCard()
        for action in CardOpening.actions(recipeID: cards[currentIndex].id, at: Date()) {
            store.send(action)
        }
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

        for _ in 0..<KartaDesign.deck.nudgeRepeatCount {
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

private struct FirstTouchCapture: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let recognizer = TouchDownGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTouch(_:))
        )
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func handleTouch(_ recognizer: UIGestureRecognizer) {
            guard recognizer.state == .began else { return }
            action()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private final class TouchDownGestureRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

private struct VisibleDeckCard: Identifiable {
    let card: FeedDeckCard
    let relativeIndex: Int

    var id: String { card.id }
}

private struct DeckFlightModifier: ViewModifier {
    let offset: CGFloat
    let rotation: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
    }
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
                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: KartaDesign.space.rankGap
                    ) {
                        Text(presentation.rankValue)
                            .font(KartaDesign.FontToken.rank())
                            .minimumScaleFactor(KartaDesign.type.rankMinimumScale)
                            .lineLimit(KartaDesign.type.rankLineLimit)
                        Text(presentation.rankUnit)
                            .font(KartaDesign.FontToken.rankUnit())
                            .tracking(KartaDesign.type.rankUnitTracking)
                    }
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
                        .tracking(KartaDesign.type.cardTitleTracking)
                        .lineLimit(KartaDesign.type.cardTitleLineLimit)
                        .minimumScaleFactor(KartaDesign.type.cardTitleMinimumScale)

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
        CardRelief(
            edgeColors: Array(
                repeating: suit.edge,
                count: KartaDesign.elevation.edgeLayerCount
            ),
            back: true
        ) {
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
                .stroke(
                    KartaDesign.ColorToken.card,
                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                )
                .padding(KartaDesign.space.backFrameInset)
            }
        }
        .accessibilityHidden(true)
    }
}

struct CardRelief<Content: View>: View {
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
                .offset(
                    y: CGFloat(layer.offset) + KartaDesign.elevation.edgeLayerOffset
                )
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
            color: back
                ? KartaDesign.ColorToken.backShadow
                : KartaDesign.ColorToken.frontShadow,
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
                .tracking(KartaDesign.type.wordmarkTracking)
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
        .frame(maxWidth: KartaDesign.layout.onboardingMaxWidth, alignment: .leading)
        .padding(KartaDesign.space.onboarding)
    }
}

struct TactileButton: View {
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
                color: KartaDesign.ColorToken.buttonShadow,
                radius: KartaDesign.elevation.buttonShadowRadius,
                y: KartaDesign.elevation.buttonShadowY
            )
    }
}

struct RecipePhoto: View {
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
                            fill { image.resizable().scaledToFill() }
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
                        fill { Image(uiImage: image).resizable().scaledToFill() }
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

    private func fill(@ViewBuilder _ content: () -> some View) -> some View {
        Color.clear.overlay(content()).clipped()
    }

    private var unavailable: some View {
        ContentUnavailableView("Photo unavailable", systemImage: "photo")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KartaDesign.ColorToken.line)
    }
}
