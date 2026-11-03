import SwiftUI
import StoreKit
import KartaCore
import KartaPresentation

/// The 18 pt "list" icon of the shopping list — two check lines over a
/// bullet line, drawn like the door and filter glyphs
/// (`docs/design/karta-v1.md` → *The shopping list* → *The door*). The same
/// glyph at 64 pt anchors the empty state and at 36 the sheet circles.
struct ShoppingListGlyph: View {
    var ink: Color = KartaDesign.ColorToken.ink

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let stroke = side * 0.09
            Canvas { context, size in
                let rows: [CGFloat] = [0.16, 0.48, 0.8]
                for row in 0..<2 {
                    let y = size.height * rows[row]
                    var check = Path()
                    check.move(to: CGPoint(x: size.width * 0.06, y: y))
                    check.addLine(to: CGPoint(x: size.width * 0.14, y: y + size.height * 0.09))
                    check.addLine(to: CGPoint(x: size.width * 0.32, y: y - size.height * 0.09))
                    context.stroke(check, with: .color(ink), style: StrokeStyle(
                        lineWidth: stroke, lineCap: .round, lineJoin: .round))
                    var line = Path()
                    line.move(to: CGPoint(x: size.width * 0.44, y: y + stroke / 2))
                    line.addLine(to: CGPoint(x: size.width * 0.94, y: y + stroke / 2))
                    context.stroke(line, with: .color(ink), style: StrokeStyle(
                        lineWidth: stroke, lineCap: .round))
                }
                let y = size.height * rows[2]
                let ring = CGRect(
                    x: size.width * 0.06, y: y - size.height * 0.05,
                    width: size.width * 0.16, height: size.width * 0.16
                )
                context.stroke(Path(ellipseIn: ring), with: .color(ink),
                               style: StrokeStyle(lineWidth: stroke * 0.8))
                var line = Path()
                line.move(to: CGPoint(x: size.width * 0.44, y: y + stroke / 2))
                line.addLine(to: CGPoint(x: size.width * 0.94, y: y + stroke / 2))
                context.stroke(line, with: .color(ink), style: StrokeStyle(
                    lineWidth: stroke, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The list itself, rendered in place of the cookbook's grid under the same
/// header (`shopping-list.png`, `shopping-empty.png`, `shopping-ax1.png`).
/// Everything on it — aisles, rows, chips, badge, switch, Done shopping —
/// comes verbatim from `ShoppingListPresentation`; the view only draws.
struct ShoppingListView: View {
    let recipes: [Recipe]
    let store: KartaStore
    /// See list / Undo / Review on the shopping toast; the parent owns the
    /// cross-surface part of See list (closing the reverse, opening here).
    let onSeeList: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var presentation: ShoppingListPresentation {
        store.state.shoppingPresentation
    }

    /// From AX1 a row keeps no single line: the name wraps, the total moves
    /// under it, the recipe line hides and the checkbox grows to 32 pt.
    private var isAX1: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: KartaDesign.space.listBlockGap) {
            if presentation.isEmpty {
                emptyState
            } else {
                header
                chips
                if presentation.showsAutoAddSwitch {
                    autoAddRow
                }
                rows
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                if presentation.canFinishShopping {
                    doneShopping
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let toast = store.state.shoppingToast,
                   store.state.navigation.routes.isEmpty {
                    ShoppingToastView(toast: toast, onAction: { action in
                        shoppingAction(action)
                    }, onExpire: {
                        store.send(.shopping(.dismissToast))
                    })
                    .padding(
                        .bottom,
                        presentation.canFinishShopping
                            ? KartaDesign.space.ctaHeight + KartaDesign.space.cardGap
                            : KartaDesign.space.toastBottomInset
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, presentation.canFinishShopping
                     ? 0
                     : KartaDesign.space.toastSideMargin - KartaDesign.space.screenX)
        }
        .animation(.easeOut(duration: 0.25), value: presentation.canFinishShopping)
        .animation(.easeOut(duration: 0.25), value: store.state.shoppingToast)
    }

    /// What the toast's pill does in this surface; See list delegates to the
    /// parent because it also has to close whatever covered the cookbook.
    private func shoppingAction(_ action: ShoppingToast.Action) {
        switch action {
        case .seeList: onSeeList()
        case .undo: store.send(.shopping(.undo))
        case let .review(id): store.send(.shopping(.review(id)))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Shopping list")
                .font(KartaDesign.FontToken.shoppingTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
            Text(presentation.countLabel)
                .font(KartaDesign.FontToken.body())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
        }
    }

    /// One chip per recipe on the list: the suit dot, the name and an 11 pt
    /// ✕ that removes it (with Undo). They wrap at the default size and
    /// scroll sideways at AX1 (`shopping-ax1.png`).
    @ViewBuilder
    private var chips: some View {
        if isAX1 {
            ScrollView(.horizontal) {
                HStack(spacing: KartaDesign.space.chipGap) {
                    ForEach(presentation.recipes, id: \.recipeID) { entry in
                        chip(entry)
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        } else {
            FlowChips(spacing: KartaDesign.space.chipGap) {
                ForEach(presentation.recipes, id: \.recipeID) { entry in
                    chip(entry)
                }
            }
        }
    }

    private func chip(_ entry: ShoppingList.Entry) -> some View {
        HStack(spacing: KartaDesign.space.rankGap) {
            if let recipe = recipes.first(where: { $0.id == entry.recipeID }) {
                Circle()
                    .fill(KartaDesign.suit(recipe.primaryCourse).back)
                    .frame(
                        width: KartaDesign.space.shoppingChipDot,
                        height: KartaDesign.space.shoppingChipDot
                    )
            }
            Text(entry.recipeName)
                .font(KartaDesign.FontToken.shoppingChip())
                .foregroundStyle(KartaDesign.ColorToken.ink)
                .lineLimit(1)
            Button {
                store.send(.shopping(.removeRecipe(entry.recipeID)))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(
                        size: KartaDesign.space.shoppingChipX,
                        weight: .bold
                    ))
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Remove \(entry.recipeName) from your list")
        }
        .padding(.leading, KartaDesign.space.saveButtonX)
        .padding(.trailing, KartaDesign.space.rankGap)
        .frame(height: KartaDesign.space.shoppingChipHeight)
        .background {
            Capsule()
                .fill(KartaDesign.ColorToken.card)
                .overlay(
                    Capsule().strokeBorder(
                        KartaDesign.ColorToken.line,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
                )
        }
        .accessibilityElement(children: .contain)
    }

    /// The "Add recipes when I save them" row — the only place this setting
    /// lives; premium only, and never on the empty list.
    private var autoAddRow: some View {
        HStack(spacing: KartaDesign.space.cardGap) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Add recipes when I save them")
                    .font(KartaDesign.FontToken.autoAddTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                Text("Ingredients go on this list as you save.")
                    .font(KartaDesign.FontToken.autoAddBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            }
            Spacer(minLength: KartaDesign.space.cardGap)
            Toggle(
                "Add recipes when I save them",
                isOn: Binding(
                    get: { store.state.addRecipesAsSaved },
                    set: { store.send(.shopping(.setAutoAdd($0))) }
                )
            )
            .labelsHidden()
            .tint(KartaDesign.ColorToken.ink)
        }
        .padding(.vertical, KartaDesign.space.autoAddRowY)
        .padding(.leading, KartaDesign.space.autoAddRowLeading)
        .padding(.trailing, KartaDesign.space.autoAddRowX)
        .background(
            KartaDesign.ColorToken.card,
            in: RoundedRectangle(
                cornerRadius: KartaDesign.space.autoAddRowRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: KartaDesign.space.autoAddRowRadius,
                style: .continuous
            )
            .strokeBorder(
                KartaDesign.ColorToken.line,
                lineWidth: KartaDesign.elevation.backFrameLineWidth
            )
        )
    }

    /// The aisles in the contract's order, then the Got it divider and the
    /// ticked rows. Scrolling leaves room for Done shopping's fade.
    private var rows: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(presentation.groups, id: \.aisle) { group in
                    Text(group.title.uppercased())
                        .font(KartaDesign.FontToken.aisleHeading())
                        .tracking(KartaDesign.space.aisleHeadingTracking)
                        .foregroundStyle(KartaDesign.ColorToken.brandEdge)
                        .padding(.top, KartaDesign.space.aisleHeadingTop)
                        .padding(.bottom, KartaDesign.space.aisleHeadingBottom)

                    ForEach(group.rows, id: \.purchaseKey) { row in
                        shoppingRow(row)
                    }
                }

                if !presentation.gotIt.isEmpty {
                    gotItDivider
                    ForEach(presentation.gotIt, id: \.purchaseKey) { row in
                        shoppingRow(row)
                    }
                }
            }
            .padding(.bottom, presentation.canFinishShopping
                     ? KartaDesign.space.ctaHeight + KartaDesign.space.cardGap
                     : KartaDesign.space.cardGap)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    /// A row per Clave de compra: checkbox, name over its recipes, total on
    /// the right. Ticking moves it under Got it and strikes it through.
    private func shoppingRow(_ row: ShoppingList.Row) -> some View {
        Button {
            store.send(.shopping(.toggleRow(row.purchaseKey)))
        } label: {
            HStack(alignment: .top, spacing: KartaDesign.space.listRowGap) {
                checkbox(ticked: row.isTicked)
                    .padding(.top, row.isTicked ? 0 : 1)

                if isAX1 {
                    VStack(alignment: .leading, spacing: 2) {
                        rowTitle(row)
                        Text(row.total)
                            .font(KartaDesign.FontToken.shoppingRowTotal())
                            .foregroundStyle(row.isTicked
                                ? KartaDesign.ColorToken.tickedInk
                                : KartaDesign.ColorToken.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: KartaDesign.space.listRowGap) {
                        VStack(alignment: .leading, spacing: 2) {
                            rowTitle(row)
                            Text(row.recipeNames)
                                .font(KartaDesign.FontToken.shoppingRowRecipes())
                                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: KartaDesign.space.listRowGap)
                        Text(row.total)
                            .font(KartaDesign.FontToken.shoppingRowTotal())
                            .foregroundStyle(row.isTicked
                                ? KartaDesign.ColorToken.tickedInk
                                : KartaDesign.ColorToken.inkMuted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
            .frame(minHeight: KartaDesign.space.listRowMin, alignment: .top)
            .padding(.vertical, KartaDesign.space.rankGap)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(KartaDesign.ColorToken.track)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.isTicked
            ? "\(row.name), \(row.total), ticked"
            : "\(row.name), \(row.total)")
        .accessibilityHint(row.isTicked ? "Unticks the row" : "Ticks the row")
    }

    private func rowTitle(_ row: ShoppingList.Row) -> some View {
        Text(row.name)
            .font(KartaDesign.FontToken.shoppingRowName())
            .foregroundStyle(row.isTicked
                ? KartaDesign.ColorToken.tickedInk
                : KartaDesign.ColorToken.ink)
            .strikethrough(row.isTicked,
                           color: KartaDesign.ColorToken.tickedInk)
    }

    private func checkbox(ticked: Bool) -> some View {
        let side = isAX1 ? KartaDesign.space.listCheckboxAX : KartaDesign.space.listCheckbox
        return ZStack {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.listCheckboxRadius,
                style: .continuous
            )
            .fill(ticked ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.card)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.listCheckboxRadius,
                style: .continuous
            )
            .strokeBorder(
                ticked ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.line,
                lineWidth: 2
            )
            if ticked {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(KartaDesign.ColorToken.card)
            }
        }
        .frame(width: side, height: side)
    }

    /// The "Got it · N" divider: a rule, a centred check and the count —
    /// never an aisle heading (`shopping-list-got-it.png`).
    private var gotItDivider: some View {
        HStack(spacing: KartaDesign.space.cardGap) {
            Rectangle().fill(KartaDesign.ColorToken.line).frame(height: 1)
            HStack(spacing: KartaDesign.space.rankGap) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text(presentation.gotItTitle)
                    .font(KartaDesign.FontToken.gotItLabel())
            }
            .foregroundStyle(KartaDesign.ColorToken.inkMuted)
            .fixedSize()
            Rectangle().fill(KartaDesign.ColorToken.line).frame(height: 1)
        }
        .padding(.top, KartaDesign.space.aisleHeadingTop)
        .padding(.bottom, KartaDesign.space.aisleHeadingBottom)
        .accessibilityElement(children: .combine)
    }

    /// The primary button, pinned over a paper fade while something is
    /// ticked; it clears the ticked rows with Undo (`shopping-list-got-it.png`).
    private var doneShopping: some View {
        Button {
            store.send(.shopping(.doneShopping))
        } label: {
            Text("Done shopping")
                .font(KartaDesign.FontToken.ctaLabel())
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
        .padding(.bottom, KartaDesign.space.doneShoppingBottom)
        .background {
            LinearGradient(
                colors: [
                    KartaDesign.ColorToken.paper.opacity(0),
                    KartaDesign.ColorToken.paper
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: KartaDesign.space.ctaHeight + KartaDesign.space.filterScrollFade)
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Done shopping")
    }

    /// `shopping-empty.png`: the list icon at 64 pt in the muted stroke,
    /// the heading and the hint — no button.
    private var emptyState: some View {
        VStack(spacing: KartaDesign.space.cookbookBlockGap) {
            ShoppingListGlyph(ink: KartaDesign.ColorToken.mutedStroke)
                .frame(width: KartaDesign.space.emptyIcon, height: KartaDesign.space.emptyIcon)
            Text("Nothing on your list")
                .font(KartaDesign.FontToken.emptyTitle())
                .foregroundStyle(KartaDesign.ColorToken.ink)
            Text("Tap Add to list on a saved recipe and its ingredients land here, sorted by aisle.")
                .font(KartaDesign.FontToken.emptyBody())
                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A wrapping row of recipe chips at the default text size; at AX1 the
/// chips scroll sideways instead (`FlowLayout` copy, chip-sized).
private struct FlowChips: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The shopping toast: same chrome as the Undo toast — `ink` fill, two
/// lines, a cream pill — but its action is whatever the contract names
/// (See list, Undo, Review), ~5 seconds (`shopping-reverse-on-list.png`,
/// `shopping-save-auto.png`, `shopping-list-done-undo.png`).
struct ShoppingToastView: View {
    let toast: ShoppingToast
    let onAction: (ShoppingToast.Action) -> Void
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
            if let action = toast.action {
                Button(action.title) {
                    onAction(action)
                }
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
        .task(id: toast) {
            try? await Task.sleep(for: .seconds(KartaDesign.space.toastDuration))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}

/// Shared bottom-sheet chrome for the shopping sheets: scrim, grabber,
/// `card` fill with the 28 pt top radius the spec gives K3's sheet.
private struct ShoppingSheetChrome<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            KartaDesign.ColorToken.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: KartaDesign.paywall.grabberGap) {
                Capsule()
                    .fill(KartaDesign.ColorToken.creamLine)
                    .frame(
                        width: KartaDesign.paywall.grabberWidth,
                        height: KartaDesign.paywall.grabberHeight
                    )
                    .padding(.top, KartaDesign.paywall.topPadding)

                content()
            }
            .padding(.horizontal, KartaDesign.paywall.sidePadding)
            .padding(.bottom, KartaDesign.space.cardBottom)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: KartaDesign.paywall.topRadius,
                    topTrailingRadius: KartaDesign.paywall.topRadius,
                    style: .continuous
                )
                .fill(KartaDesign.ColorToken.card)
                .ignoresSafeArea(edges: .bottom)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height > 60 { onDismiss() }
            })
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.isModal)
    }
}

/// The primary brand button shared by the shopping sheets (same chrome as
/// the reverse's Start cooking / the list's Done shopping).
private struct ShoppingPrimaryButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KartaDesign.FontToken.ctaLabel())
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
        .disabled(disabled)
        .opacity(disabled ? KartaDesign.paywall.disabledOpacity : 1)
    }
}

/// The tactile secondary button shared by the shopping sheets ("Not now",
/// "Only when I ask") — same chrome as K3's.
private struct ShoppingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(KartaDesign.FontToken.button())
            .foregroundStyle(KartaDesign.ColorToken.ink)
            .frame(maxWidth: .infinity)
            .frame(height: KartaDesign.space.notNowHit)
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

/// The sheet the **Add to list** pill opens (`shopping-add-sheet.png`):
/// K3's sheet with a row per visible ingredient — checked by default except
/// pantry basics and leftovers, whose rows say why — and the tick-count
/// primary button. Dismissing it (scrim, swipe) adds nothing.
struct ShoppingAddSheetView: View {
    let sheet: ShoppingAddSheet
    let store: KartaStore

    var body: some View {
        ShoppingSheetChrome {
            store.send(.shopping(.dismissSheet))
        } content: {
            VStack(alignment: .leading, spacing: KartaDesign.space.listBlockGap) {
                Text(sheet.title)
                    .font(KartaDesign.FontToken.shoppingSheetTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                Text(sheet.subtitle)
                    .font(KartaDesign.FontToken.shoppingSheetSubtitle())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)

                ScrollView {
                    VStack(spacing: KartaDesign.space.shoppingSheetRowGap) {
                        ForEach(sheet.rows, id: \.ingredient.id) { row in
                            sheetRow(row)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 320)

                ShoppingPrimaryButton(
                    title: sheet.buttonTitle,
                    disabled: !sheet.canConfirm
                ) {
                    store.send(.shopping(.confirm))
                }
            }
            .padding(.top, KartaDesign.space.cookbookBlockGap - KartaDesign.paywall.grabberGap)
        }
    }

    private func sheetRow(_ row: ShoppingAddSheet.Row) -> some View {
        let selected = sheet.selectedKeys.contains(row.ingredient.purchaseKey)
        return Button {
            store.send(.shopping(.toggleChoice(row.ingredient.purchaseKey)))
        } label: {
            HStack(alignment: .top, spacing: KartaDesign.space.listRowGap) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: KartaDesign.space.listCheckboxRadius,
                        style: .continuous
                    )
                    .fill(selected ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.card)
                    RoundedRectangle(
                        cornerRadius: KartaDesign.space.listCheckboxRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        selected ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.line,
                        lineWidth: 2
                    )
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(KartaDesign.ColorToken.card)
                    }
                }
                .frame(
                    width: KartaDesign.space.listCheckbox,
                    height: KartaDesign.space.listCheckbox
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.ingredient.name)
                        .font(KartaDesign.FontToken.shoppingRowName())
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                    if let hint = row.hint {
                        Text(hint)
                            .font(KartaDesign.FontToken.shoppingRowRecipes().weight(.bold))
                            .foregroundStyle(KartaDesign.ColorToken.brandEdge)
                    }
                }
                Spacer(minLength: KartaDesign.space.listRowGap)
                Text(row.quantity)
                    .font(KartaDesign.FontToken.shoppingRowTotal())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected
            ? "\(row.ingredient.name), \(row.quantity), on the list"
            : "\(row.ingredient.name), \(row.quantity)")
        .accessibilityHint(selected ? "Takes it off" : "Adds it")
    }
}

/// The one-time question after the first addition's toast goes away
/// (`shopping-ask-auto.png`): the list icon in a 72 pt `chip` circle, the
/// question, the primary **Yes, every time** and the tactile **Only when I
/// ask**. Every other dismissal leaves the switch off.
struct ShoppingAutoAddQuestionView: View {
    let store: KartaStore

    var body: some View {
        ShoppingSheetChrome {
            store.send(.shopping(.answerAutoAdd(false)))
        } content: {
            VStack(spacing: KartaDesign.space.cookbookBlockGap) {
                Circle()
                    .fill(KartaDesign.ColorToken.creamLine)
                    .frame(
                        width: KartaDesign.space.sheetIconCircle,
                        height: KartaDesign.space.sheetIconCircle
                    )
                    .overlay {
                        ShoppingListGlyph()
                            .frame(
                                width: KartaDesign.space.sheetIconCircle / 2,
                                height: KartaDesign.space.sheetIconCircle / 2
                            )
                    }

                Text(ShoppingAutoAddQuestion.title)
                    .font(KartaDesign.FontToken.shoppingSheetTitle())
                    .foregroundStyle(KartaDesign.ColorToken.ink)
                    .multilineTextAlignment(.center)

                Text(ShoppingAutoAddQuestion.message)
                    .font(KartaDesign.FontToken.sheetBody())
                    .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                    .multilineTextAlignment(.center)

                ShoppingPrimaryButton(title: ShoppingAutoAddQuestion.primaryTitle) {
                    store.send(.shopping(.answerAutoAdd(true)))
                }
                ShoppingSecondaryButton(title: ShoppingAutoAddQuestion.dismissTitle) {
                    store.send(.shopping(.answerAutoAdd(false)))
                }
            }
            .padding(.top, KartaDesign.space.cookbookBlockGap - KartaDesign.paywall.grabberGap)
        }
    }
}

/// One sheet identity for the shopping entry: the free-plan invitation
/// (`shopping-free.png`) grows into the paywall with the `.shoppingList`
/// entry, exactly as K3 grows into the cap paywall — the container stays
/// while the content cross-fades.
struct ShoppingEntrySheet: View {
    let store: KartaStore
    let premium: PremiumController

    /// The grown paywall once See plans opened it for the list entry.
    private var paywall: Paywall? {
        guard let paywall = store.state.paywall,
              case .shoppingList = paywall.entry else { return nil }
        return paywall
    }

    var body: some View {
        ShoppingSheetChrome(onDismiss: dismiss) {
            ZStack {
                if let paywall {
                    PaywallSheetContent(
                        paywall: paywall,
                        store: store,
                        premium: premium,
                        onClose: dismiss
                    )
                    .transition(.opacity)
                } else {
                    VStack(spacing: KartaDesign.space.cookbookBlockGap) {
                        Circle()
                            .fill(KartaDesign.ColorToken.creamLine)
                            .frame(
                                width: KartaDesign.space.sheetIconCircle,
                                height: KartaDesign.space.sheetIconCircle
                            )
                            .overlay {
                                ShoppingListGlyph()
                                    .frame(
                                        width: KartaDesign.space.sheetIconCircle / 2,
                                        height: KartaDesign.space.sheetIconCircle / 2
                                    )
                            }

                        Text(ShoppingInvitation.title)
                            .font(KartaDesign.FontToken.shoppingSheetTitle())
                            .foregroundStyle(KartaDesign.ColorToken.ink)
                            .multilineTextAlignment(.center)

                        Text(ShoppingInvitation.message)
                            .font(KartaDesign.FontToken.sheetBody())
                            .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                            .multilineTextAlignment(.center)

                        ShoppingPrimaryButton(title: ShoppingInvitation.primaryTitle) {
                            Task { await premium.open(entry: .shoppingList) }
                        }
                        ShoppingSecondaryButton(title: ShoppingInvitation.dismissTitle) {
                            dismiss()
                        }
                    }
                    .padding(.top, KartaDesign.space.cookbookBlockGap - KartaDesign.paywall.grabberGap)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: paywall != nil)
    }

    private func dismiss() {
        if let paywall {
            guard paywall.canClose else { return }
            store.send(.paywall(.close))
        }
        store.send(.shopping(.dismissInvitation))
    }
}
