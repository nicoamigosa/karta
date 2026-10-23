import SwiftUI
import KartaCore
import KartaPresentation

/// One row of the Mundo menu: the Mundo plus the screen copy fixed by the
/// signed-off boards (`docs/design/karta-v1.md` → *The Mundo menu*).
struct MundoRow: Identifiable, Equatable {
    let world: World
    let title: String
    let subtitle: String

    var id: World { world }
}

/// The Mundo menu's row order and copy. The Mundo list itself is
/// `World.allCases` from `KartaPresentation`; the presentation layer does not
/// yet expose the row copy, so the strings pinned by the spec live next to the
/// view that renders them.
enum MundoMenu {
    static func title(for world: World) -> String {
        switch world {
        case .forYou: "For You"
        case .leftovers: "Leftovers"
        }
    }

    static func rows() -> [MundoRow] {
        World.allCases.map { world in
            switch world {
            case .forYou:
                MundoRow(
                    world: world,
                    title: title(for: world),
                    subtitle: "Your deck for today"
                )
            case .leftovers:
                MundoRow(
                    world: world,
                    title: title(for: world),
                    subtitle: "Reuse what you cooked"
                )
            }
        }
    }
}

/// The feed header row shared by both Mundos (`docs/design/karta-v1.md` →
/// *The feed header*): wordmark on the left; on the right, 10 pt apart, the
/// filter button with its badge, the Mundo pill and the cookbook door. The
/// filter button is drawn here; its panel is issue #6.
struct FeedHeader: View {
    let store: KartaStore
    let mundoMenuOpen: Bool
    let onToggleMundoMenu: () -> Void
    let onOpenCookbook: () -> Void
    /// Opens the filter panel (issue #6). A no-op until the panel exists.
    var onFilter: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            Text("karta")
                .font(KartaDesign.FontToken.wordmark())
                .tracking(KartaDesign.type.wordmarkTracking)
                .foregroundStyle(KartaDesign.ColorToken.brand)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            HStack(spacing: KartaDesign.space.headerButtonGap) {
                FilterButton(
                    appliedCount: store.state.appliedFilterCount,
                    pressed: false,
                    action: onFilter
                )

                MundoPill(
                    title: MundoMenu.title(for: store.state.navigation.world),
                    pressed: mundoMenuOpen,
                    action: onToggleMundoMenu
                )

                Button(action: onOpenCookbook) {
                    CookbookBoxGlyph(ink: KartaDesign.ColorToken.ink)
                        .frame(
                            width: KartaDesign.space.doorGlyph,
                            height: KartaDesign.space.doorGlyph
                        )
                        .frame(
                            width: KartaDesign.space.doorButton,
                            height: KartaDesign.space.doorButton
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
                .accessibilityLabel("Open your cookbook")
            }
        }
        .frame(height: KartaDesign.space.headerRowHeight)
        .padding(.horizontal, KartaDesign.space.screenX)
    }
}

/// The 40 pt tactile circle that opens the filter panel (#6), with the badge
/// of applied non-safety filters on its top-right corner.
private struct FilterButton: View {
    let appliedCount: Int
    /// `ink` fill and border while the panel is open (issue #6).
    let pressed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FilterSlidersGlyph(
                ink: pressed ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.ink,
                field: pressed ? KartaDesign.ColorToken.ink : KartaDesign.ColorToken.card
            )
            .frame(
                width: KartaDesign.space.filterGlyph,
                height: KartaDesign.space.filterGlyph
            )
            .frame(
                width: KartaDesign.space.doorButton,
                height: KartaDesign.space.doorButton
            )
            .background {
                if pressed {
                    Circle()
                        .fill(KartaDesign.ColorToken.inkEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Circle().fill(KartaDesign.ColorToken.ink)
                    Circle().strokeBorder(
                        KartaDesign.ColorToken.ink,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
                } else {
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
        }
        .overlay(alignment: .topTrailing) {
            if appliedCount > 0 {
                Text("\(appliedCount)")
                    .font(KartaDesign.FontToken.filterBadge())
                    .foregroundStyle(KartaDesign.ColorToken.card)
                    .frame(
                        width: KartaDesign.space.filterBadge,
                        height: KartaDesign.space.filterBadge
                    )
                    .background {
                        Circle().fill(KartaDesign.ColorToken.brand)
                        Circle().strokeBorder(
                            KartaDesign.ColorToken.paper,
                            lineWidth: KartaDesign.space.filterBadgeRing
                        )
                    }
                    .offset(
                        x: KartaDesign.space.filterBadgeOutset,
                        y: -KartaDesign.space.filterBadgeOutset
                    )
            }
        }
        .accessibilityLabel(
            appliedCount > 0
                ? "Filters, \(appliedCount) applied"
                : "Filters"
        )
    }
}

/// The Mundo pill: current Mundo's name and a chevron, pressed (`ink` fill,
/// chevron up) while the Mundo menu is open.
private struct MundoPill: View {
    let title: String
    let pressed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KartaDesign.space.rankGap) {
                Text(title)
                    .font(KartaDesign.FontToken.switchActive())
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(pressed ? 180 : 0))
            }
            .fixedSize()
            .foregroundStyle(
                pressed ? KartaDesign.ColorToken.card : KartaDesign.ColorToken.ink
            )
            .padding(.horizontal, KartaDesign.space.saveButtonX)
            .frame(height: KartaDesign.space.doorButton)
            .background {
                if pressed {
                    Capsule()
                        .fill(KartaDesign.ColorToken.inkEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Capsule().fill(KartaDesign.ColorToken.ink)
                    Capsule().strokeBorder(
                        KartaDesign.ColorToken.ink,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
                } else {
                    Capsule()
                        .fill(KartaDesign.ColorToken.buttonEdge)
                        .offset(y: KartaDesign.space.reverseButtonEdge)
                    Capsule().fill(KartaDesign.ColorToken.card)
                    Capsule().strokeBorder(
                        KartaDesign.ColorToken.line,
                        lineWidth: KartaDesign.elevation.backFrameLineWidth
                    )
                }
            }
        }
        .accessibilityLabel("\(title), mundo menu")
    }
}

/// The Mundo menu under the pill (`docs/design/karta-v1.md` → *The Mundo
/// menu*): 252 pt wide, right edge on the pill's right edge. Selecting a row
/// switches Mundo through `.selectWorld(_:)`; tapping the current row, the
/// pill or the scrim only closes it.
struct MundoMenuView: View {
    let store: KartaStore
    let onSelect: (World) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(MundoMenu.rows()) { row in
                let current = row.world == store.state.navigation.world
                Button {
                    if !current {
                        onSelect(row.world)
                    }
                    onDismiss()
                } label: {
                    HStack(spacing: KartaDesign.space.mundoRowPadding) {
                        MundoGlyph(world: row.world)
                            .frame(
                                width: KartaDesign.space.mundoRowIcon,
                                height: KartaDesign.space.mundoRowIcon
                            )

                        VStack(alignment: .leading, spacing: 0) {
                            Text(row.title)
                                .font(KartaDesign.FontToken.mundoName())
                                .foregroundStyle(KartaDesign.ColorToken.ink)
                            Text(row.subtitle)
                                .font(KartaDesign.FontToken.hint())
                                .foregroundStyle(KartaDesign.ColorToken.inkMuted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(KartaDesign.ColorToken.ink)
                                .frame(
                                    width: KartaDesign.space.mundoRowCheck,
                                    height: KartaDesign.space.mundoRowCheck
                                )
                        }
                    }
                    .padding(KartaDesign.space.mundoRowPadding)
                    .frame(height: KartaDesign.space.mundoRowHeight)
                    .background {
                        if current {
                            RoundedRectangle(
                                cornerRadius: KartaDesign.space.mundoRowRadius,
                                style: .continuous
                            )
                            .fill(KartaDesign.ColorToken.paper)
                        }
                    }
                    .contentShape(RoundedRectangle(
                        cornerRadius: KartaDesign.space.mundoRowRadius,
                        style: .continuous
                    ))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(KartaDesign.space.mundoMenuPadding)
        .frame(width: KartaDesign.space.mundoMenuWidth)
        .background {
            RoundedRectangle(
                cornerRadius: KartaDesign.space.mundoMenuRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.buttonEdge)
            .offset(y: KartaDesign.space.menuEdge)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.mundoMenuRadius,
                style: .continuous
            )
            .fill(KartaDesign.ColorToken.card)
            RoundedRectangle(
                cornerRadius: KartaDesign.space.mundoMenuRadius,
                style: .continuous
            )
            .strokeBorder(
                KartaDesign.ColorToken.line,
                lineWidth: KartaDesign.elevation.backFrameLineWidth
            )
        }
        .shadow(
            color: KartaDesign.ColorToken.frontShadow,
            radius: KartaDesign.elevation.menuShadowRadius,
            y: KartaDesign.elevation.menuShadowY
        )
    }
}

/// The 26 pt line icon of a Mundo menu row: two cards fanned for For You, a
/// bowl with steam for Leftovers.
private struct MundoGlyph: View {
    let world: World

    var body: some View {
        switch world {
        case .forYou:
            FannedCardsGlyph()
        case .leftovers:
            BowlGlyph()
        }
    }
}

/// Two cards fanned, the front one solid so it covers the card behind.
private struct FannedCardsGlyph: View {
    var ink: Color = KartaDesign.ColorToken.ink
    var field: Color = KartaDesign.ColorToken.card

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let stroke = side * 0.07
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .stroke(ink, lineWidth: stroke)
                    .frame(width: side * 0.44, height: side * 0.62)
                    .rotationEffect(.degrees(-9))
                    .offset(x: -side * 0.16)
                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .stroke(ink, lineWidth: stroke)
                    .background {
                        RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                            .fill(field)
                    }
                    .frame(width: side * 0.44, height: side * 0.62)
                    .rotationEffect(.degrees(8))
                    .offset(x: side * 0.14, y: side * 0.02)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A bowl with two steam strokes. Shared by the Mundo menu row and the
/// Leftovers placeholder.
struct BowlGlyph: View {
    var ink: Color = KartaDesign.ColorToken.ink

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let stroke = side * 0.075
            BowlShape()
                .stroke(ink, style: StrokeStyle(
                    lineWidth: stroke,
                    lineCap: .round,
                    lineJoin: .round
                ))
                .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct BowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Two short steam strokes rising from the bowl.
        for x in [0.4, 0.6] as [CGFloat] {
            path.move(to: CGPoint(x: rect.width * x, y: rect.height * 0.34))
            path.addCurve(
                to: CGPoint(x: rect.width * x, y: rect.height * 0.12),
                control1: CGPoint(x: rect.width * (x - 0.07), y: rect.height * 0.28),
                control2: CGPoint(x: rect.width * (x + 0.07), y: rect.height * 0.18)
            )
        }
        // The bowl: a rim line with a semicircle body under it.
        path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.5))
        path.addArc(
            center: CGPoint(x: rect.width * 0.5, y: rect.height * 0.5),
            radius: rect.width * 0.34,
            startAngle: .zero,
            endAngle: .degrees(180),
            clockwise: false
        )
        return path
    }
}

/// The two-lines-with-knobs icon of the filter button (18 pt, stroke 1.7).
private struct FilterSlidersGlyph: View {
    var ink: Color = KartaDesign.ColorToken.ink
    /// Fill behind each knob so the track line does not show through.
    var field: Color = KartaDesign.ColorToken.card

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let stroke = KartaDesign.space.filterGlyphStroke
            ZStack {
                SliderTrack(knobX: 0.34, trackY: 0.3, ink: ink, field: field, stroke: stroke)
                SliderTrack(knobX: 0.66, trackY: 0.72, ink: ink, field: field, stroke: stroke)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct SliderTrack: View {
    let knobX: CGFloat
    let trackY: CGFloat
    let ink: Color
    let field: Color
    let stroke: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let y = side * trackY
            let knob = side * 0.3
            ZStack {
                Capsule()
                    .fill(ink)
                    .frame(width: side * 0.94, height: stroke)
                    .offset(y: y - side / 2)
                Circle()
                    .stroke(ink, lineWidth: stroke)
                    .background { Circle().fill(field) }
                    .frame(width: knob, height: knob)
                    .offset(x: side * (knobX - 0.5), y: y - side / 2)
            }
            .frame(width: side, height: side)
        }
    }
}
