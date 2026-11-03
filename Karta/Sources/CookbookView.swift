import SwiftUI
import StoreKit
import KartaCore
import KartaPresentation

/// The Cookbook: the user's saved recipes in two non-overlapping halves
/// (`CONTEXT.md` → Repertorio / Por probar). Not a Mundo — it is reached by
/// its own door, a box button pressed to go back. Rows come verbatim from
/// `KartaStore.cookbookPresentation`; the view applies no rule.
struct CookbookScreen: View {
    let recipes: [Recipe]
    let manifest: MediaAssetManifest
    let store: KartaStore
    let onClose: () -> Void
    let onOpenRecipe: (CookbookPresentation.Row) -> Void
    let onUnsaveFromGrid: (CookbookPresentation.Row) -> Void
    let onShare: (CookbookPresentation.Row) -> Void
    /// See list on the shopping toast: the parent also coordinates the
    /// surfaces the toast can sit on (a reverse over the feed).
    let onSeeList: () -> Void
    /// The cupo line's way in (Go unlimited → paywall, Manage → Apple).
    let premium: PremiumController

    @State private var showsManageSubscriptions = false

    @AppStorage("cookbook.lastHalf") private var lastHalf = CookbookHalf.wantToTry.rawValue

    private var presentation: CookbookPresentation {
        store.cookbookPresentation(recipes: recipes)
    }

    private var half: CookbookHalf {
        CookbookHalf.reopening(stored: lastHalf)
    }

    var body: some View {
        VStack(spacing: KartaDesign.space.cookbookBlockGap) {
            header

            if store.state.showsShoppingList {
                ShoppingListView(
                    recipes: recipes,
                    store: store,
                    onSeeList: onSeeList
                )
            } else {
                cookbookBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, KartaDesign.space.screenX)
        .background(KartaDesign.ColorToken.paper.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if presentation.isSelecting {
                selectionBar
                    .padding(.horizontal, KartaDesign.space.toastSideMargin)
                    .padding(.bottom, KartaDesign.space.selectionBarBottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let toast = store.unsaveToast(recipes: recipes) {
                UnsaveToastView(toast: toast, onUndo: {
                    store.send(.undoUnsave)
                }, onExpire: {
                    store.send(.dismissUnsaveToast)
                })
                .padding(.horizontal, KartaDesign.space.toastSideMargin)
                .padding(.bottom, KartaDesign.space.toastBottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.unsaveToast(recipes: recipes))
        .animation(.easeOut(duration: 0.25), value: presentation.isSelecting)
        .manageSubscriptionsSheet(
            isPresented: $showsManageSubscriptions,
            subscriptionGroupID: PremiumProductIDs.subscriptionGroupID
        )
    }

    /// The cookbook body the list replaces: switch, cupo line and the grid
    /// or empty state — unchanged apart from the selection chrome.
    @ViewBuilder
    private var cookbookBody: some View {
        if !presentation.wantToTry.isEmpty || !presentation.repertoire.isEmpty {
            switchView
        }

        if let cupoLine = presentation.cupoLine {
            cupoView(cupoLine)
                .font(KartaDesign.FontToken.cupoCount())
                .frame(maxWidth: .infinity)
        }

        if presentation.wantToTry.isEmpty && presentation.repertoire.isEmpty {
            emptyState(
                title: "Nothing saved yet",
                body: "Tap Save on a recipe you like and it lands here."
            )
        } else if half.rows(in: presentation).isEmpty {
            switch half {
            case .repertoire:
                emptyState(
                    title: "Nothing cooked yet",
                    body: "Cook a recipe from Want to try and it moves here."
                )
            case .wantToTry:
                emptyState(
                    title: "You've cooked them all",
                    body: "Save something new from For You to try next."
                )
            }
        } else {
            grid(rows: half.rows(in: presentation))
        }
    }

    /// The cupo line under the switch: only its link is underlined and
    /// tappable — Go unlimited opens the paywall, Manage opens Apple's
    /// manage-subscriptions sheet (`premium-cookbook-*.png`).
    @ViewBuilder
    private func cupoView(_ cupoLine: CookbookPresentation.CupoLine) -> some View {
        if let link = cupoLine.link {
            HStack(spacing: 0) {
                Text(cupoLine.text + " · ")
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                Button(link.title) {
                    switch link {
                    case .goUnlimited: Task { await premium.open(entry: .cupoLine) }
                    case .manage: showsManageSubscriptions = true
                    }
                }
                .font(KartaDesign.FontToken.cupoCount())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .underline(color: KartaDesign.ColorToken.ink)
            }
        } else {
            Text(cupoLine.text)
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
        }
    }

    /// The wordmark left and the controls right (`shopping-cookbook-door.png`):
    /// the Select pill while the cookbook holds a recipe, the list button
    /// with its left-to-buy badge and the door — the pressed one goes back
    /// to For You, the unpressed one swaps between cookbook and list. In
    /// selection mode the buttons give way to the pressed Done.
    private var header: some View {
        HStack {
            Text("karta")
                .font(KartaDesign.FontToken.wordmark())
                .tracking(KartaDesign.type.wordmarkTracking)
                .foregroundStyle(KartaDesign.ColorToken.brand)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if presentation.isSelecting {
                Button {
                    store.send(.endCookbookSelection)
                } label: {
                    Text("Done")
                        .font(KartaDesign.FontToken.button())
                        .foregroundStyle(KartaDesign.ColorToken.card)
                        .padding(.horizontal, KartaDesign.space.selectPillX)
                        .frame(height: KartaDesign.space.selectPillHeight)
                        .background {
                            Capsule()
                                .fill(KartaDesign.ColorToken.inkEdge)
                                .offset(y: KartaDesign.space.reverseButtonEdge)
                            Capsule()
                                .fill(KartaDesign.ColorToken.ink)
                            Capsule()
                                .strokeBorder(
                                    KartaDesign.ColorToken.ink,
                                    lineWidth: KartaDesign.elevation.backFrameLineWidth
                                )
                        }
                }
                .accessibilityLabel("Done selecting")
            } else {
                HStack(spacing: KartaDesign.space.doorGap) {
                    if presentation.canSelect && !store.state.showsShoppingList {
                        Button {
                            store.send(.beginCookbookSelection)
                        } label: {
                            Text("Select")
                                .font(KartaDesign.FontToken.button())
                                .foregroundStyle(KartaDesign.ColorToken.ink)
                                .padding(.horizontal, KartaDesign.space.selectPillX)
                                .frame(height: KartaDesign.space.selectPillHeight)
                                .background {
                                    Capsule()
                                        .fill(KartaDesign.ColorToken.buttonEdge)
                                        .offset(y: KartaDesign.space.reverseButtonEdge)
                                    Capsule()
                                        .fill(KartaDesign.ColorToken.card)
                                    Capsule()
                                        .strokeBorder(
                                            KartaDesign.ColorToken.line,
                                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                                        )
                                }
                        }
                        .accessibilityLabel("Select recipes")
                    }

                    listButton
                    doorButton
                }
            }
        }
    }

    /// The list's own door: same 40 pt tactile circle, list icon inside,
    /// pressed while the list is open — tapping it there goes back to For
    /// You, as the pressed door does.
    private var listButton: some View {
        let pressed = store.state.showsShoppingList
        return Button {
            if pressed {
                if store.state.shoppingToast != nil {
                    store.send(.shopping(.dismissToast))
                }
                store.send(.shopping(.closeList))
                onClose()
            } else {
                store.send(.shopping(.openList))
            }
        } label: {
            ShoppingListGlyph(
                ink: pressed ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.ink
            )
            .frame(width: KartaDesign.space.doorGlyph, height: KartaDesign.space.doorGlyph)
            .frame(width: KartaDesign.space.doorButton, height: KartaDesign.space.doorButton)
            .background {
                if pressed {
                    Circle()
                        .fill(KartaDesign.ColorToken.inkEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Circle()
                        .fill(KartaDesign.ColorToken.ink)
                    Circle()
                        .strokeBorder(
                            KartaDesign.ColorToken.ink,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                } else {
                    Circle()
                        .fill(KartaDesign.ColorToken.buttonEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Circle()
                        .fill(KartaDesign.ColorToken.card)
                    Circle()
                        .strokeBorder(
                            KartaDesign.ColorToken.line,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                // The rows left to buy, as the filter badge — only while
                // the list is closed (the boards draw no badge pressed).
                if !pressed, let badge = store.state.shoppingPresentation.badge {
                    Text("\(badge)")
                        .font(KartaDesign.FontToken.filterBadge())
                        .foregroundStyle(KartaDesign.ColorToken.card)
                        .padding(.horizontal, KartaDesign.space.filterBadgeOutset)
                        .frame(minWidth: KartaDesign.space.filterBadge)
                        .frame(height: KartaDesign.space.filterBadge)
                        .background(
                            KartaDesign.ColorToken.brand,
                            in: Circle()
                        )
                        .overlay(
                            Circle().strokeBorder(
                                KartaDesign.ColorToken.paper,
                                lineWidth: KartaDesign.space.filterBadgeRing
                            )
                        )
                        .offset(
                            x: KartaDesign.space.filterBadgeOutset,
                            y: -KartaDesign.space.filterBadgeOutset
                        )
                }
            }
        }
        .accessibilityLabel(pressed ? "Back to For You" : "Open your shopping list")
    }

    /// The cookbook door: pressed on the cookbook (tap → For You), resting
    /// on the list (tap → back to the cookbook).
    private var doorButton: some View {
        let pressed = !store.state.showsShoppingList
        return Button {
            if pressed {
                onClose()
            } else {
                if store.state.shoppingToast != nil {
                    store.send(.shopping(.dismissToast))
                }
                store.send(.shopping(.closeList))
            }
        } label: {
            CookbookBoxGlyph(
                checked: false,
                ink: pressed ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.ink
            )
            .frame(width: KartaDesign.space.doorGlyph, height: KartaDesign.space.doorGlyph)
            .frame(width: KartaDesign.space.doorButton, height: KartaDesign.space.doorButton)
            .background {
                if pressed {
                    Circle()
                        .fill(KartaDesign.ColorToken.inkEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Circle()
                        .fill(KartaDesign.ColorToken.ink)
                    Circle()
                        .strokeBorder(
                            KartaDesign.ColorToken.ink,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                } else {
                    Circle()
                        .fill(KartaDesign.ColorToken.buttonEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Circle()
                        .fill(KartaDesign.ColorToken.card)
                    Circle()
                        .strokeBorder(
                            KartaDesign.ColorToken.line,
                            lineWidth: KartaDesign.elevation.backFrameLineWidth
                        )
                }
            }
        }
        .accessibilityLabel(pressed ? "Back to For You" : "Back to your cookbook")
    }

    /// The floating ink bar of selection mode (`shopping-cookbook-select.png`):
    /// "N selected" on the left, one cream Remove pill on the right — Remove
    /// is the only action and sits at 45 % with nothing selected.
    private var selectionBar: some View {
        HStack(spacing: KartaDesign.space.toastPadding) {
            Text(presentation.selectionBarText)
                .font(KartaDesign.FontToken.toastTitle())
                .foregroundStyle(KartaDesign.ColorToken.card)
            Spacer(minLength: KartaDesign.space.toastPadding)
            Button {
                store.send(.removeCookbookSelection)
            } label: {
                Label("Remove", systemImage: "trash")
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
            .disabled(!presentation.canRemoveSelection)
            .opacity(presentation.canRemoveSelection ? 1 : KartaDesign.paywall.disabledOpacity)
            .accessibilityLabel("Remove the selected recipes")
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
    }

    private var switchView: some View {
        HStack(spacing: 0) {
            ForEach(CookbookHalf.allCases, id: \.self) { candidate in
                Button {
                    lastHalf = candidate.rawValue
                } label: {
                    Text(candidate.title(in: presentation))
                        .font(candidate == half
                            ? KartaDesign.FontToken.switchActive()
                            : KartaDesign.FontToken.switchResting())
                        .foregroundStyle(candidate == half
                            ? KartaDesign.ColorToken.ink
                            : KartaDesign.ColorToken.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KartaDesign.space.chipY + 2)
                        .background {
                            if candidate == half {
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
            }
        }
        .padding(KartaDesign.space.switchTrackInset)
        .background(
            KartaDesign.ColorToken.creamLine,
            in: RoundedRectangle(
                cornerRadius: KartaDesign.space.switchTrackRadius,
                style: .continuous
            )
        )
    }

    private func grid(rows: [CookbookPresentation.Row]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: KartaDesign.space.cookbookGridGap),
                    GridItem(.flexible(), spacing: KartaDesign.space.cookbookGridGap)
                ],
                spacing: KartaDesign.space.cookbookGridGap
            ) {
                ForEach(rows, id: \.recipeID) { row in
                    let selected = presentation.selectedRecipeIDs.contains(row.recipeID)
                    CookbookGridCard(
                        row: row,
                        manifest: manifest,
                        isSelecting: presentation.isSelecting,
                        isSelected: selected
                    )
                    // The unselected drop to 75 % once something is picked.
                    .opacity(presentation.isSelecting
                             && !presentation.selectedRecipeIDs.isEmpty
                             && !selected ? 0.75 : 1)
                    .onTapGesture {
                        if presentation.isSelecting {
                            store.send(.toggleCookbookSelection(row.recipeID))
                        } else {
                            onOpenRecipe(row)
                        }
                    }
                    .contextMenu {
                        // Share sits above Remove while the app has a
                        // base URL; with none it never appears.
                        if canShare(row) {
                            Button {
                                onShare(row)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button(role: .destructive) {
                            onUnsaveFromGrid(row)
                        } label: {
                            Label("Remove from cookbook", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        // The card shadow must not be clipped by the scroll bounds.
        .scrollClipDisabled()
    }

    /// The contract decides whether this row can share (needs a base URL
    /// and a recipe still in the catalogue).
    private func canShare(_ row: CookbookPresentation.Row) -> Bool {
        guard let recipe = recipes.first(where: { $0.id == row.recipeID })
        else { return false }
        return ShareLinks.payload(for: recipe, in: store) != nil
    }

    private func emptyState(title: String, body: String) -> some View {
        VStack(spacing: KartaDesign.space.cookbookBlockGap) {
            CookbookBoxGlyph(ink: KartaDesign.ColorToken.mutedStroke)
                .frame(width: KartaDesign.space.emptyIcon, height: KartaDesign.space.emptyIcon)
            Text(title)
                .font(KartaDesign.FontToken.emptyTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
            Text(body)
                .font(KartaDesign.FontToken.emptyBody())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// One saved recipe in the cookbook grid: photo, title, time, and the crimson
/// intolerance tag when a saved recipe contains a new Intolerancia. In
/// selection mode it carries the 26 pt check circle and, when selected,
/// the ink ring (`shopping-cookbook-select.png`).
private struct CookbookGridCard: View {
    let row: CookbookPresentation.Row
    let manifest: MediaAssetManifest
    var isSelecting = false
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.chipGap) {
            RecipePhoto(reference: row.photo, manifest: manifest)
                .frame(height: KartaDesign.space.cookbookGridPhotoHeight)
                .clipShape(RoundedRectangle(
                    cornerRadius: KartaDesign.space.cookbookGridPhotoRadius,
                    style: .continuous
                ))

            Text(row.name)
                .font(KartaDesign.FontToken.gridTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .lineLimit(2)

            HStack(spacing: KartaDesign.space.chipGap) {
                Text(row.timeLabel)
                    .font(KartaDesign.FontToken.gridMeta())
                    .tracking(1)
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                if let intoleranceTag = row.intoleranceTag {
                    Text(intoleranceTag)
                        .font(KartaDesign.FontToken.gridMeta())
                        .foregroundStyle(KartaDesign.ColorToken.alertInk)
                        .padding(.vertical, KartaDesign.space.intoleranceTagY)
                        .padding(.horizontal, KartaDesign.space.intoleranceTagX)
                        .background(
                            KartaDesign.ColorToken.alert,
                            in: RoundedRectangle(
                                cornerRadius: KartaDesign.radius.cue,
                                style: .continuous
                            )
                        )
                }
                Spacer(minLength: 0)
            }
        }
        .padding(KartaDesign.space.cookbookGridCardPadding)
        .padding(.bottom, KartaDesign.space.cookbookGridCardBottom - KartaDesign.space.cookbookGridCardPadding)
        .background(
            KartaDesign.ColorToken.card,
            in: RoundedRectangle(
                cornerRadius: KartaDesign.radius.photo,
                style: .continuous
            )
        )
        .shadow(
            color: KartaDesign.ColorToken.frontShadow,
            radius: KartaDesign.elevation.backShadowRadius,
            y: KartaDesign.elevation.backShadowY
        )
        .accessibilityElement(children: .combine)
        .overlay(alignment: .topLeading) {
            if isSelecting {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(KartaDesign.ColorToken.ink)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(KartaDesign.ColorToken.card)
                    } else {
                        Circle()
                            .fill(KartaDesign.ColorToken.inkEdge.opacity(0.3))
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                }
                .frame(
                    width: KartaDesign.space.selectionCircle,
                    height: KartaDesign.space.selectionCircle
                )
                .padding(KartaDesign.space.selectionCircleInset)
                .accessibilityHidden(true)
            }
        }
        .overlay {
            if isSelecting && isSelected {
                RoundedRectangle(
                    cornerRadius: KartaDesign.radius.photo,
                    style: .continuous
                )
                .strokeBorder(
                    KartaDesign.ColorToken.ink,
                    lineWidth: KartaDesign.space.selectionRing
                )
            }
        }
        .accessibilityHint(isSelecting
            ? (isSelected ? "Double-tap to unselect." : "Double-tap to select.")
            : "Double-tap to open. Touch and hold to remove from cookbook.")
    }
}

/// The Undo toast: `ink` fill, "Removed from cookbook" over the recipe's name
/// (or the new ceiling after a downgrade), a cream Undo pill, about 5 seconds.
/// Never a confirmation (`docs/design/karta-v1.md` → *Toast*, *Undo*).
struct UnsaveToastView: View {
    let toast: UnsaveToast
    let onUndo: () -> Void
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
            Button("Undo", action: onUndo)
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
        // Each removal gets its own ~5 s: a second unsave restarts the timer.
        .task(id: toast) {
            // The toast stays about five seconds; the receipt is transient.
            try? await Task.sleep(for: .seconds(KartaDesign.space.toastDuration))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}
