import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

struct FeedScreen: View {
    let store: KartaStore
    /// The shell's StoreKit bridge: entitlement at launch, the four ways in,
    /// purchase and restore.
    let premium: PremiumController

    @State private var recipes: [Recipe] = []
    // An empty clip library cannot fail validation; clips load with the seed.
    @State private var clips = try! TechniqueClipLibrary(clips: [])
    @State private var manifest = MediaAssetManifest([:])
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var cookbookOpen = DebugSeeds.opensCookbook
    /// The payload currently in the native share sheet; nil while Share is
    /// switched off or no sheet is up.
    @State private var presentedShare: PresentedShare?
    /// A shared link that arrived before the catalogue finished loading:
    /// resolving it early would report `gone` for recipes that exist, so it
    /// waits for the seed.
    @State private var pendingLink: URL?
    /// The onboarding's coldLaunch is sent once per process (#172).
    @State private var didColdLaunch = false
    /// The Mundo a reverse was opened from, captured at Apertura; nil for a
    /// reverse opened from the cookbook or a shared link.
    @State private var reverseOrigin: World? = DebugSeeds.reverseOrigin

    /// See list on a shopping toast: pop whatever covers the feed (a
    /// reverse is the only route the toast can sit on) and open the list
    /// inside the cookbook.
    private func openShoppingList() {
        if !store.state.navigation.routes.isEmpty {
            store.send(.popRoute)
        }
        cookbookOpen = true
        store.send(.shopping(.openList))
        store.send(.shopping(.dismissToast))
    }

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
                            reverseOrigin = nil
                            store.send(.pushRoute(.recipeDetail(recipeID: row.recipeID)))
                        },
                        onUnsaveFromGrid: { row in
                            store.send(.unsaveRecipe(row.recipeID))
                        },
                        onShare: { row in
                            if let recipe = recipes.first(where: { $0.id == row.recipeID }),
                               let payload = ShareLinks.payload(for: recipe, in: store) {
                                presentedShare = PresentedShare(payload: payload)
                            }
                        },
                        onSeeList: openShoppingList,
                        premium: premium
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
                            reverseOrigin = store.state.navigation.world
                        },
                        premium: premium
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
            ), let reverse = store.reversePresentation(
                for: recipe,
                openedFrom: reverseOrigin,
                recipes: recipes,
                clock: SystemClock()
            ) {
                RecipeReverseView(
                    recipe: recipe,
                    presentation: reverse,
                    manifest: manifest,
                    store: store,
                    onSeeList: openShoppingList,
                    premium: premium
                )
                .transition(reverseTransition)
            }

            // The paywall from the other three ways in rises over the feed;
            // the K3 sheet grows into it inside the reverse, and the
            // shopping invitation grows into it below, keeping one sheet.
            if let paywall = store.state.paywall,
               case .cap = paywall.entry {} else if let paywall = store.state.paywall,
               case .shoppingList = paywall.entry {} else if let paywall = store.state.paywall {
                PaywallView(paywall: paywall, store: store, premium: premium)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // The shopping sheets: the add sheet over the reverse, the
            // one-time auto-add question, and the invitation→paywall sheet.
            // Their icon circles take the chip of the recipe behind them —
            // dinner's when the sheet stands over the cookbook alone.
            let sheetSuit = KartaDesign.suit(
                RecipeReverseRoute.recipe(
                    for: store.state.navigation.routes,
                    in: recipes
                )?.primaryCourse ?? .dinner
            )
            if let sheet = store.state.shoppingSheet {
                ShoppingAddSheetView(sheet: sheet, store: store)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if store.state.showsAutoAddQuestion {
                ShoppingAutoAddQuestionView(store: store, suit: sheetSuit)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if store.state.shoppingEntryIsPresented {
                ShoppingEntrySheet(store: store, premium: premium, suit: sheetSuit)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Restore-with-nothing toast: no pill, at the top of the screen.
            if let toast = store.state.restoreToast {
                VStack {
                    RestoreToastView(toast: toast) {
                        store.send(.paywall(.dismissRestoreToast))
                    }
                    .padding(.top, KartaDesign.space.cardGap)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
            // Half height like `share-sheet.png`, expandable.
            .presentationDetents([.medium, .large])
        }
        .onOpenURL { openRecipeLink($0) }
        // Universal links arrive as NSUserActivity once #155's Associated
        // Domains entry exists. No custom scheme is registered, so until
        // then only NSUserActivity links reach the app.
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                openRecipeLink(url)
            }
        }
        // One cold launch per process: the store decides whether the tour
        // runs (full, stop 3 alone or never) — no rule lives here.
        .task {
            guard !didColdLaunch else { return }
            didColdLaunch = true
            store.send(.onboarding(.coldLaunch(reduceMotion: reduceMotion)))
            DebugSeeds.afterColdLaunch(into: store)
        }
        // Persisted answers make the tour's later-launch behaviour possible:
        // the shell owns the write side of UserSnapshot (#172).
        .onChange(of: store.state) {
            UserSnapshotStorage.save(store.state)
        }
        .task {
            do {
                let seed = SeedResourceAdapter()
                recipes = (try seed.loadRecipes() + DebugSeeds.extraRecipes())
                    .filter { !DebugSeeds.droppedRecipeIDs.contains($0.id) }
                clips = try DebugSeeds.clipLibrary(loading: seed)
                manifest = try DebugSeeds.mediaManifest(loading: seed)
                isLoaded = true
                // A link that cold-launched the app waited for the seed.
                if let url = pendingLink {
                    pendingLink = nil
                    openRecipeLink(url)
                }
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private extension FeedScreen {
    /// One shared link: the store resolves it (reverse/Apertura, gone
    /// notice, not offered, ignored); the shell only mirrors the outcome.
    /// A link that arrives before the catalogue loads is held — resolving
    /// against an empty catalogue would report `gone` for existing recipes.
    func openRecipeLink(_ url: URL) {
        guard isLoaded else {
            pendingLink = url
            return
        }
        reverseOrigin = nil
        switch store.openRecipeLink(url, recipes: recipes, at: Date()) {
        case .gone:
            // "The app opens the Feed": close the cookbook over it.
            cookbookOpen = false
        case .reverse, .notOffered, .ignored:
            break
        }
    }

    var reverseTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: KartaDesign.deck.reverseAppearScale).combined(with: .opacity)
    }
}

/// The wall clock the shell hands to the store so shopping and save
/// actions reduce with `recipes`/`now` (docs/shopping-list-contract.md).
struct SystemClock: KartaClock {
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
    let premium: PremiumController

    @State private var mundoMenuOpen = DebugSeeds.opensMundoMenu
    @State private var filterButtonCenter: CGFloat = 0
    /// Header control frames for the tour spotlight (#172).
    @State private var controlFrames: [TourControl: CGRect] = [:]

    /// Which panel drops from the filter button — the first-run form while
    /// the Intolerancias are unanswered, the full panel after — or none.
    private var panel: OnboardingState.Panel? {
        store.state.onboarding.panel
    }

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
                        filterPressed: panel != nil,
                        onToggleMundoMenu: {
                            closePanel()
                            withAnimation(.easeOut(duration: KartaDesign.deck.faceRevealDuration)) {
                                mundoMenuOpen.toggle()
                            }
                        },
                        onOpenCookbook: {
                            mundoMenuOpen = false
                            closePanel()
                            onOpenCookbook()
                        },
                        onFilter: {
                            // Tapping the button again discards the draft.
                            if panel != nil { closePanel() } else { openPanel() }
                        },
                        onFilterButtonCenter: { filterButtonCenter = $0 },
                        onControlFrames: { controlFrames[$0] = $1 }
                    )
                    .padding(.top, KartaDesign.space.headerTopGap)

                    if let banner = store.state.onboarding.banner {
                        // The Baraja segura banner: 8 pt below the header row,
                        // 22 pt from the sides (`onboarding-safe-deck.png`).
                        SafeDeckBannerView(
                            banner: banner,
                            send: { store.send(.onboarding($0)) }
                        )
                        .padding(.top, KartaDesign.space.bannerTopGap)
                        .padding(.horizontal, KartaDesign.space.screenX)
                    }

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
                                    world: .forYou,
                                    recipes: recipes,
                                    topGap: deckTopGap,
                                    onOpenCard: onOpenCard
                                )
                            }
                        case .leftovers:
                            let emptyState = store.leftoversEmptyState(
                                recipes: recipes,
                                clock: SystemClock()
                            )
                            if emptyState == .none {
                                FeedDeck(
                                    cards: FeedDeckCard.cards(in: store.leftoversFeed(
                                        recipes: recipes,
                                        clock: SystemClock()
                                    )),
                                    manifest: manifest,
                                    store: store,
                                    world: .leftovers,
                                    recipes: recipes,
                                    topGap: deckTopGap,
                                    onOpenCard: onOpenCard
                                )
                            } else {
                                LeftoversEmptyStateView(state: emptyState) { action in
                                    switch action {
                                    case .send(let action): store.send(action)
                                    case .openFilters: openPanel()
                                    }
                                }
                            }
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
                    .ignoresSafeArea()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // The See toast after an explicit Cocinado, in the same
                // place; the store never offers it beside recipe-gone.
                if let toast = store.state.leftoversToast {
                    VStack(spacing: 0) {
                        LeftoversToastView(
                            toast: toast,
                            onSee: { store.send(LeftoversToastResponse.see) },
                            onDismiss: { store.send(LeftoversToastResponse.dismissed) }
                        )
                        .padding(.top, headerClearance(in: geometry)
                                 + KartaDesign.space.cardGap)
                        .padding(.horizontal, KartaDesign.space.toastSideMargin)
                        Spacer(minLength: 0)
                    }
                    .ignoresSafeArea()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if mundoMenuOpen || panel != nil {
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
                                    onDismiss: { closeMenu() },
                                    onGoPremium: { Task { await premium.open(entry: .worldMenu) } }
                                )
                                .padding(.top, headerClearance(in: geometry)
                                         + KartaDesign.space.mundoMenuTopGap)
                                .padding(.trailing, menuTrailingInset)
                            }
                        }

                        if panel != nil {
                            VStack {
                                PanelChrome(filterButtonCenter: filterButtonCenter) {
                                    switch panel {
                                    case .full:
                                        FilterPanelView(
                                            store: store,
                                            recipes: recipes,
                                            clock: SystemClock(),
                                            maxHeight: panelMaxHeight(in: geometry),
                                            onApply: { closePanel() }
                                        )
                                    default:
                                        FirstRunPanelView(
                                            store: store,
                                            maxHeight: panelMaxHeight(in: geometry)
                                        )
                                    }
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

                // The tour's spotlight sits above everything, dimming the
                // header too; while it is up it owns all taps.
                if store.state.onboarding.tourStop != nil {
                    OnboardingTourOverlay(
                        onboarding: store.state.onboarding,
                        controlFrames: controlFrames,
                        safeAreaInsets: geometry.safeAreaInsets,
                        send: { store.send(.onboarding($0)) }
                    )
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: FeedLayout.coordinateSpace)
            // The scrim+panel and the tour overlay declare .transition(.opacity);
            // these cover their insertion/removal wherever the action comes
            // from (button, scrim tap, coldLaunch) — 300 ms, as in #6, and it is
            // also what fades stop 3 in under Reduce Motion.
            .animation(.easeOut(duration: KartaDesign.deck.faceRevealDuration),
                       value: store.state.onboarding.panel != nil)
            .animation(.easeOut(duration: KartaDesign.deck.faceRevealDuration),
                       value: store.state.onboarding.tourStop != nil)
        }
    }

    /// The deck's gap below what sits above it: 14 pt below the banner,
    /// 20 pt below the header row (spec: *First open and onboarding*).
    private var deckTopGap: CGFloat {
        store.state.onboarding.banner != nil
            ? KartaDesign.space.bannerToDeck
            : KartaDesign.space.headerToDeck
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
        // The store picks first-run or full (and advances the tour's stop 3).
        store.send(.onboarding(.filterButtonTapped))
    }

    /// Closing the panel without applying throws the draft away; the panel's
    /// draft dies with it and any saved Intolerancias stay saved.
    private func closePanel() {
        store.send(.filter(.cancel))
        store.send(.onboarding(.closePanel))
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

private struct FeedDeck: View {
    let manifest: MediaAssetManifest
    let store: KartaStore
    /// The Mundo this deck shows and the catalogue its projections read.
    let world: World
    let recipes: [Recipe]
    /// Gap between the deck and what sits above it (20 pt below the header
    /// row, 14 below the Baraja segura banner).
    var topGap: CGFloat = KartaDesign.space.headerToDeck
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
    /// The last-card hint (fades in on a rebound past the end, out after
    /// the store's duration) and the light haptic's trigger.
    @State private var endHintVisible = false
    @State private var endBounces = 0
    @State private var endHintTask: Task<Void, Never>?

    init(
        cards: [FeedDeckCard],
        manifest: MediaAssetManifest,
        store: KartaStore,
        world: World,
        recipes: [Recipe],
        topGap: CGFloat = KartaDesign.space.headerToDeck,
        onOpenCard: @escaping () -> Void
    ) {
        self.manifest = manifest
        self.store = store
        self.world = world
        self.recipes = recipes
        self.topGap = topGap
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
            .padding(.top, topGap)
            .padding(.horizontal, KartaDesign.space.screenX)

            ZStack {
                Text("Swipe up or down")
                    .font(KartaDesign.FontToken.hint())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .opacity(hintVisible ? 1 : 0)
                    .animation(
                        .easeOut(duration: KartaDesign.deck.hintFadeDuration),
                        value: hintVisible
                    )
                if let lastCard {
                    LastCardHintView(hint: lastCard.hint, world: world)
                        .opacity(endHintVisible ? 1 : 0)
                        .animation(
                            .easeOut(duration: KartaDesign.deck.hintFadeDuration),
                            value: endHintVisible
                        )
                        .accessibilityHidden(!endHintVisible)
                }
            }
            .frame(height: KartaDesign.deck.hintHeight)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: endBounces)
        .onAppear {
            recordSettledCard()
            if let attempt = DebugSeeds.lastCardAttempt, lastCard != nil {
                stopEntryNudge()
                bouncePastEnd(heldOffset: attempt.heldOffset)
                return
            }
            Task { @MainActor in
                await runEntryNudge()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(KartaDesign.deck.hintFadeDelay))
            hintVisible = false
        }
    }

    /// Non-nil on the deck's last Card: the store's end-of-deck hint, and
    /// whether cards show behind it.
    private var lastCard: LastCardPresentation? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return store.lastCard(
            recipeID: cards[currentIndex].id,
            world: world,
            recipes: recipes,
            clock: SystemClock()
        )
    }

    private var visibleCards: [VisibleDeckCard] {
        guard !cards.isEmpty else { return [] }
        let behind = lastCard.map { $0.showsCardsBehind ? KartaDesign.deck.backCardCount : 0 }
            ?? KartaDesign.deck.backCardCount
        return (0...behind).compactMap { relativeIndex in
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
                if let presentation = store.cardPresentation(
                    for: visible.card.recipe,
                    world: world,
                    recipes: recipes,
                    clock: SystemClock()
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
                // Reduce Motion: the last Card does not move forward.
                if reduceMotion, vertical < 0, lastCard != nil {
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
                    if lastCard != nil, DeckNavigator.isForwardSwipe(
                        translation: value.translation,
                        predictedTranslation: value.predictedEndTranslation
                    ) {
                        bouncePastEnd(heldOffset: nil)
                    } else {
                        withAnimation(KartaDesign.deckAnimation) {
                            dragOffset = 0
                        }
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

    /// Trying to pass the last Card: it comes back with the deck's rebound
    /// and a light haptic, and the store's hint fades in, then out after its
    /// duration. Reduce Motion keeps the hint only. A debug seed can hold
    /// the Card mid-drag to photograph the bounce.
    private func bouncePastEnd(heldOffset: CGFloat?) {
        guard let lastCard else { return }
        if !reduceMotion {
            endBounces += 1
            withAnimation(KartaDesign.deckAnimation) {
                dragOffset = heldOffset ?? 0
            }
        }
        endHintVisible = true
        endHintTask?.cancel()
        endHintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(lastCard.hintDuration))
            guard !Task.isCancelled else { return }
            endHintVisible = false
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
        // The nudge waits until the tour has ended and no panel is up
        // (#172): the store owns `canShowEntryNudge`.
        while !store.state.onboarding.canShowEntryNudge {
            guard !hasInteracted, !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(0.25))
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The chips, plus the Leftovers pill when the store gives one: in the
    /// same row when it fits, else (and always from AX1) on its own line
    /// 8 pt under the chips.
    @ViewBuilder
    private var chipsRow: some View {
        if let pill = presentation.leftoversPill {
            if dynamicTypeSize >= .accessibility1 {
                pillOnOwnLine(pill)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: KartaDesign.space.chipGap) {
                        chips
                        LeftoversPill(text: pill, suit: suit)
                            .fixedSize()
                        Spacer(minLength: 0)
                        seenLabel
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    pillOnOwnLine(pill)
                }
            }
        } else {
            HStack(spacing: KartaDesign.space.chipGap) {
                chips
                Spacer(minLength: 0)
                seenLabel
            }
        }
    }

    private func pillOnOwnLine(_ pill: String) -> some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.pillOwnLineGap) {
            HStack(spacing: KartaDesign.space.chipGap) {
                chips
                Spacer(minLength: 0)
                seenLabel
            }
            LeftoversPill(text: pill, suit: suit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var chips: some View {
        CardChip(label: presentation.servingsLabel, suit: suit)
        CardChip(label: presentation.difficultyLabel.capitalized, suit: suit)
    }

    @ViewBuilder
    private var seenLabel: some View {
        if card.alreadySeen {
            Text("seen")
                .font(KartaDesign.FontToken.hint())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
        }
    }

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

                    chipsRow
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
            .padding(.horizontal, KartaDesign.space.cardChipX)
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
