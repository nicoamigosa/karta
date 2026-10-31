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
    let onUndo: (UnsaveToast) -> Void
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, KartaDesign.space.screenX)
        .background(KartaDesign.ColorToken.paper.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast = store.unsaveToast(recipes: recipes) {
                UnsaveToastView(toast: toast, onUndo: {
                    onUndo(toast)
                }, onExpire: {
                    store.send(.dismissUnsaveToast)
                })
                .padding(.horizontal, KartaDesign.space.toastSideMargin)
                .padding(.bottom, KartaDesign.space.toastBottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.unsaveToast(recipes: recipes))
        .manageSubscriptionsSheet(
            isPresented: $showsManageSubscriptions,
            subscriptionGroupID: PremiumProductIDs.subscriptionGroupID
        )
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

    /// The wordmark left and the door button right, pressed: same box icon,
    /// `ink` fill — tapping it again goes back to For You (board *H3*).
    private var header: some View {
        HStack {
            Text("karta")
                .font(KartaDesign.FontToken.wordmark())
                .tracking(KartaDesign.type.wordmarkTracking)
                .foregroundStyle(KartaDesign.ColorToken.brand)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onClose) {
                CookbookBoxGlyph(checked: false, ink: KartaDesign.ColorToken.card)
                    .frame(width: KartaDesign.space.doorGlyph, height: KartaDesign.space.doorGlyph)
                    .frame(width: KartaDesign.space.doorButton, height: KartaDesign.space.doorButton)
                    .background {
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
                    }
            }
            .accessibilityLabel("Back to For You")
        }
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
                    CookbookGridCard(row: row, manifest: manifest)
                        .onTapGesture {
                            onOpenRecipe(row)
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
/// intolerance tag when a saved recipe contains a new Intolerancia.
private struct CookbookGridCard: View {
    let row: CookbookPresentation.Row
    let manifest: MediaAssetManifest

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
        .accessibilityHint("Double-tap to open. Touch and hold to remove from cookbook.")
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
