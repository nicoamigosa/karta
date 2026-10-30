import CoreText
import SwiftUI
import UIKit
import KartaCore

enum KartaDesign {
    enum ColorToken {
        static let paper = Color(hex: 0xF3EBDD)
        static let card = Color(hex: 0xFFFAF0)
        static let line = Color(hex: 0xE4D5BD)
        static let ink = Color(hex: 0x4E1A12)
        static let inkMuted = Color(hex: 0x7A4A3C)
        static let brand = Color(hex: 0xA5432D)
        static let cardEdges = [
            Color(hex: 0xEADDC7),
            Color(hex: 0xE3D3B9),
            Color(hex: 0xDCCAAD),
            Color(hex: 0xD5C1A2)
        ]
        static let buttonEdge = Color(hex: 0xE0CFB3)
        static let brandEdge = Color(hex: 0x7E2F1F)
        static let frontShadow = Color(
            red: 80 / 255,
            green: 50 / 255,
            blue: 25 / 255,
            opacity: 0.45
        )
        static let backShadow = Color(
            red: 80 / 255,
            green: 50 / 255,
            blue: 25 / 255,
            opacity: 0.35
        )
        static let buttonShadow = Color(
            red: 80 / 255,
            green: 50 / 255,
            blue: 25 / 255,
            opacity: 0.25
        )
        /// Intolerance flag (colder and darker than any suit; no warning icon).
        static let alert = Color(hex: 0xB3122E)
        static let alertInk = Color(hex: 0xFFFAF0)
        /// Cookbook switch track / toast second line (`#EADDC7`).
        static let creamLine = Color(hex: 0xEADDC7)
        /// Empty-state icon stroke and Undo pill edge (`#C9B79C`).
        static let mutedStroke = Color(hex: 0xC9B79C)
        /// The pressed cookbook door's darker 2 pt edge.
        static let inkEdge = Color(hex: 0x2E0F0A)
        /// The filter tracks' inset background (`#EADDC7`, same as the
        /// cookbook switch's `creamLine`; `track` in tokens.json).
        static let track = Color(hex: 0xEADDC7)
        /// Near-black ground behind the technique clip in full screen.
        static let videoGround = Color(hex: 0x190D08)
        /// The unloaded portion of the clip's progress line and scrubber.
        static let videoTrack = Color.white.opacity(0.3)

        /// Scrim under the cookbook-full sheet.
        static let scrim = Color(
            red: 46 / 255,
            green: 26 / 255,
            blue: 18 / 255,
            opacity: 0.55
        )
    }

    enum FontToken {
        static func wordmark() -> Font {
            display(size: 30, relativeTo: .title1, weight: 900)
        }

        static func rank() -> Font {
            display(size: 40, relativeTo: .largeTitle, weight: 900)
        }

        static func suitLabel() -> Font {
            display(
                name: "Fraunces-Italic",
                size: 20,
                relativeTo: .title3,
                weight: 600
            )
        }

        static func cardTitle() -> Font {
            display(size: 33, relativeTo: .largeTitle, weight: 700)
        }

        static func rankUnit() -> Font {
            .custom("Figtree", size: 11, relativeTo: .caption)
                .weight(.heavy)
        }

        static func chip() -> Font {
            .custom("Figtree", size: 14, relativeTo: .body)
                .weight(.bold)
        }

        static func button() -> Font {
            .custom("Figtree", size: 14, relativeTo: .body)
                .weight(.bold)
        }

        /// Outcome labels on the Cierre card (Figtree 700, 14 → footnote).
        static func cookOutcomeLabel() -> Font {
            .custom("Figtree", size: 14, relativeTo: .footnote)
                .weight(.bold)
        }

        /// The Cierre's primary Finish label (Figtree 800, 17 → body, per the
        /// spec's Dynamic Type table).
        static func cookFinishLabel() -> Font {
            .custom("Figtree", size: 17, relativeTo: .body)
                .weight(.heavy)
        }

        static func body() -> Font {
            .custom("Figtree", size: 16, relativeTo: .body)
        }

        static func rowName() -> Font {
            .custom("Figtree", size: 15, relativeTo: .body)
                .weight(.bold)
        }

        static func rowQuantity() -> Font {
            .custom("Figtree", size: 15, relativeTo: .body)
                .weight(.medium)
        }

        static func stepText() -> Font {
            .custom("Figtree", size: 15, relativeTo: .body)
        }

        static func stepCue() -> Font {
            .custom("Figtree", size: 12, relativeTo: .caption)
                .weight(.heavy)
        }

        static func ctaLabel() -> Font {
            .custom("Figtree", size: 17, relativeTo: .headline)
                .weight(.heavy)
        }

        static func hint() -> Font {
            .custom("Figtree", size: 13, relativeTo: .caption)
                .weight(.semibold)
        }

        /// The Paso's full instruction, readable from ~half a meter.
        static func cookStep() -> Font {
            display(size: 28, relativeTo: .title1, weight: 600)
        }

        /// The Paso's ingredient names and quantities, enlarged for cooking.
        static func cookIngredient() -> Font {
            .custom("Figtree", size: 19, relativeTo: .title3)
                .weight(.bold)
        }

        static func cookQuantity() -> Font {
            .custom("Figtree", size: 19, relativeTo: .title3)
                .weight(.medium)
        }

        /// Cooking session Resumen (Fraunces 700, 34/39, tracking −0.4).
        static func cookSummary() -> Font {
            display(size: 34, relativeTo: .largeTitle, weight: 700)
        }

        /// Cooking session Detalle (Figtree 500, 17/24).
        static func cookDetail() -> Font {
            .custom("Figtree", size: 17, relativeTo: .body)
                .weight(.medium)
        }

        /// Cooking session Temporizador readout (Fraunces 900, 36, tabular).
        static func cookTimer() -> Font {
            display(size: 36, relativeTo: .largeTitle, weight: 900)
        }

        /// T1 Temporizador digits (Fraunces 900, 28 → `.title1`, tabular).
        static func cookTimerDigits() -> Font {
            display(size: 28, relativeTo: .title1, weight: 900)
        }

        /// T1 *Time's up* (Fraunces 900, 26 → `.title1`).
        static func cookTimerDone() -> Font {
            display(size: 26, relativeTo: .title1, weight: 900)
        }

        /// T1 status label — TIMER / LEFT / PAUSED (Figtree 800, 11 →
        /// `.caption2`, tracking 1.2).
        static func cookTimerLabel() -> Font {
            .custom("Figtree", size: 11, relativeTo: .caption2)
                .weight(.heavy)
        }

        /// The Stop pill label of a finished Temporizador (Figtree 800, 15 →
        /// `.callout`, close to the sheet's button scale).
        static func cookTimerStopLabel() -> Font {
            .custom("Figtree", size: 15, relativeTo: .callout)
                .weight(.heavy)
        }

        /// Bottom-sheet title — Leave cooking?, Alarms are off (Resumen
        /// style: Fraunces 700, 28 → `.title1`).
        static func cookSheetTitle() -> Font {
            display(size: 28, relativeTo: .title1, weight: 700)
        }

        /// Cookbook grid card title (Fraunces 700, 17/20).
        static func gridTitle() -> Font {
            display(size: 17, relativeTo: .headline, weight: 700)
        }

        /// Cookbook grid time / intolerance tag (Figtree 800, 12).
        static func gridMeta() -> Font {
            .custom("Figtree", size: 12, relativeTo: .caption)
                .weight(.heavy)
        }

        /// Cookbook switch, active segment (Figtree 800, 14).
        static func switchActive() -> Font {
            .custom("Figtree", size: 14, relativeTo: .body)
                .weight(.heavy)
        }

        /// Cookbook switch, resting segment (Figtree 700, 14).
        static func switchResting() -> Font {
            .custom("Figtree", size: 14, relativeTo: .body)
                .weight(.bold)
        }

        /// Cupo count line under the switch (Figtree 700, 13).
        static func cupoCount() -> Font {
            .custom("Figtree", size: 13, relativeTo: .footnote)
                .weight(.bold)
        }

        /// Multi-choice filter track segment, on (Figtree 800, 13 → body).
        static func trackOn() -> Font {
            .custom("Figtree", size: 13, relativeTo: .body)
                .weight(.heavy)
        }

        /// Multi-choice filter track segment, off (Figtree 700, 13 → body).
        static func trackOff() -> Font {
            .custom("Figtree", size: 13, relativeTo: .body)
                .weight(.bold)
        }

        /// Mundo menu row name (Figtree 800, 16).
        static func mundoName() -> Font {
            .custom("Figtree", size: 16, relativeTo: .body)
                .weight(.heavy)
        }

        /// Line under the Mundo menu row name (Figtree 600, 13).
        static func mundoLine() -> Font {
            .custom("Figtree", size: 13, relativeTo: .footnote)
                .weight(.semibold)
        }

        /// Filter-button badge count (Figtree 800, 11).
        static func filterBadge() -> Font {
            .custom("Figtree", size: 11, relativeTo: .caption2)
                .weight(.heavy)
        }

        /// The filter panel's "Filters" title (Fraunces 700, 24 → title2).
        static func filterPanelTitle() -> Font {
            display(size: 24, relativeTo: .title2, weight: 700)
        }

        /// Track section headings and their right-hand note (Figtree 800, 12).
        static func filterHeading() -> Font {
            .custom("Figtree", size: 12, relativeTo: .footnote)
                .weight(.heavy)
        }

        /// The "Always free" note next to NEVER SHOW ME (Figtree 700, 12).
        static func filterMeta() -> Font {
            .custom("Figtree", size: 12, relativeTo: .footnote)
                .weight(.bold)
        }

        /// Empty-state heading (Fraunces 700, 22).
        static func emptyTitle() -> Font {
            display(size: 22, relativeTo: .title2, weight: 700)
        }

        /// Empty-state body (Figtree 600, 15/22).
        static func emptyBody() -> Font {
            .custom("Figtree", size: 15, relativeTo: .body)
                .weight(.semibold)
        }

        /// Intolerance note on the reverse (Figtree 800, 14).
        static func intoleranceNote() -> Font {
            .custom("Figtree", size: 14, relativeTo: .body)
                .weight(.heavy)
        }

        /// Undo toast title (Figtree 800, 15).
        static func toastTitle() -> Font {
            .custom("Figtree", size: 15, relativeTo: .body)
                .weight(.heavy)
        }

        /// Undo toast second line (Figtree 600, 13).
        static func toastSecondLine() -> Font {
            .custom("Figtree", size: 13, relativeTo: .footnote)
                .weight(.semibold)
        }

        /// Sheet count under "Your cookbook is full" (Figtree 800, 13, tracked).
        static func sheetCount() -> Font {
            .custom("Figtree", size: 13, relativeTo: .footnote)
                .weight(.heavy)
        }

        /// Sheet body line (Figtree 500, 15).
        static func sheetBody() -> Font {
            .custom("Figtree", size: 15, relativeTo: .body)
                .weight(.medium)
        }

        private static func display(
            name: String = "Fraunces",
            size: CGFloat,
            relativeTo textStyle: UIFont.TextStyle,
            weight: CGFloat
        ) -> Font {
            var descriptor = CTFontDescriptorCreateWithNameAndSize(
                name as CFString,
                size
            )
            descriptor = CTFontDescriptorCreateCopyWithVariation(
                descriptor,
                NSNumber(value: KartaDesign.type.displaySoftAxis),
                KartaDesign.type.displaySoft
            )
            descriptor = CTFontDescriptorCreateCopyWithVariation(
                descriptor,
                NSNumber(value: KartaDesign.type.displayWeightAxis),
                weight
            )
            let scaledSize = UIFontMetrics(forTextStyle: textStyle)
                .scaledValue(for: size)
            return Font(CTFontCreateWithFontDescriptor(
                descriptor,
                scaledSize,
                nil
            ))
        }
    }

    enum radius {
        static let card: CGFloat = 26
        static let cardBackFrame: CGFloat = 18
        static let photo: CGFloat = 18
        static let chip: CGFloat = 12
        static let cue: CGFloat = 8
        static let cta: CGFloat = 18
        static let pill: CGFloat = 999
    }

    enum type {
        static let displaySoftAxis: UInt32 = 0x534F4654
        static let displayWeightAxis: UInt32 = 0x77676874
        static let displaySoft: CGFloat = 100
        static let wordmarkTracking: CGFloat = -0.8
        /// Tracking of the filter panel's section headings (1.2 per spec).
        static let filterHeadingTracking: CGFloat = 1.2
        static let rankUnitTracking: CGFloat = 1.2
        static let cardTitleTracking: CGFloat = -0.6
        static let rankMinimumScale: CGFloat = 0.68
        static let cardTitleMinimumScale: CGFloat = 0.72
        static let rankLineLimit = 1
        static let cardTitleLineLimit = 2
    }

    enum space {
        static let screenX: CGFloat = 22
        /// The feed header row's height and its gap under the top safe area
        /// (*The feed header*, signed 2026-10-23).
        static let headerRowHeight: CGFloat = 44
        static let headerTopGap: CGFloat = 6
        static let headerToDeck: CGFloat = 20
        static let cardTop: CGFloat = 12
        static let cardX: CGFloat = 12
        static let cardBottom: CGFloat = 18
        static let cardGap: CGFloat = 12
        static let cardTextInset: CGFloat = 8
        static let rankGap: CGFloat = 4
        static let chipGap: CGFloat = 8
        static let chipY: CGFloat = 7
        static let chipX: CGFloat = 12
        static let reverseCardX: CGFloat = 10
        static let reverseCardY: CGFloat = 30
        static let reverseButtonHit: CGFloat = 40
        static let reverseButtonEdge: CGFloat = 2
        static let saveButtonX: CGFloat = 14
        static let saveIconGap: CGFloat = 6
        static let leaderMin: CGFloat = 8
        static let stepLeading: CGFloat = 4
        static let ctaHeight: CGFloat = 54
        static let ctaGap: CGFloat = 10
        static let ctaEdge: CGFloat = 3
        static let reverseCloseGlyph: CGFloat = 14
        static let saveGlyph: CGFloat = 16
        static let ctaGlyph: CGFloat = 18
        static let reversePhotoEdge: CGFloat = 76
        static let reverseRowGap: CGFloat = 10
        static let stepDisc: CGFloat = 22
        static let stepCueY: CGFloat = 3
        static let backFrameInset: CGFloat = 9
        static let onboarding: CGFloat = 28
        static let onboardingGap: CGFloat = 24
        static let cookbookBlockGap: CGFloat = 18
        static let cookbookGridGap: CGFloat = 12
        static let cookbookGridCardPadding: CGFloat = 8
        static let cookbookGridCardBottom: CGFloat = 12
        static let cookbookGridPhotoHeight: CGFloat = 118
        static let cookbookGridPhotoRadius: CGFloat = 12
        static let switchTrackRadius: CGFloat = 14
        static let switchTrackInset: CGFloat = 4
        static let switchSegmentRadius: CGFloat = 11
        static let doorButton: CGFloat = 40
        static let doorGlyph: CGFloat = 18
        static let doorGap: CGFloat = 10
        static let emptyIcon: CGFloat = 64
        static let intoleranceTagY: CGFloat = 2
        static let intoleranceTagX: CGFloat = 7
        static let intoleranceNoteY: CGFloat = 10
        static let intoleranceNoteX: CGFloat = 12
        static let intoleranceNoteRadius: CGFloat = 14
        static let toastRadius: CGFloat = 18
        static let toastPadding: CGFloat = 12
        static let toastLeading: CGFloat = 16
        static let toastUndoHit: CGFloat = 40
        static let toastSideMargin: CGFloat = 22
        static let toastBottomInset: CGFloat = 40
        static let toastDuration: TimeInterval = 5
        /// Feed header controls and the Mundo menu (boards *A* of Ronda 1).
        static let headerButtonGap: CGFloat = 10
        static let filterGlyph: CGFloat = 18
        static let filterGlyphStroke: CGFloat = 1.7
        static let filterBadge: CGFloat = 20
        static let filterBadgeOutset: CGFloat = 5
        static let filterBadgeRing: CGFloat = 2
        static let mundoMenuTopGap: CGFloat = 10
        static let mundoMenuWidth: CGFloat = 252
        static let mundoMenuRadius: CGFloat = 18
        static let mundoMenuPadding: CGFloat = 6
        static let mundoRowHeight: CGFloat = 62
        static let mundoRowRadius: CGFloat = 13
        static let mundoRowPadding: CGFloat = 12
        static let mundoRowIcon: CGFloat = 26
        static let mundoRowCheck: CGFloat = 18
        static let menuEdge: CGFloat = 2
        /// The filter panel (#6): radius 24, 10 pt from the sides and 10 pt
        /// below the header row, 16 pt inner padding, 14 pt between blocks.
        static let filterPanelRadius: CGFloat = 24
        static let filterPanelInset: CGFloat = 10
        static let filterPanelTopGap: CGFloat = 10
        static let filterPanelPadding: CGFloat = 16
        static let filterBodyPaddingY: CGFloat = 14
        static let filterBlockGap: CGFloat = 14
        static let filterHeadingGap: CGFloat = 8
        static let filterResetHeight: CGFloat = 34
        /// Footer: 14 pt above the button, 16 pt to the sides and below.
        static let filterFooterTopPadding: CGFloat = 14
        static let filterFooterPadding: CGFloat = 16
        static let filterScrollFade: CGFloat = 32
        static let neverShowRadius: CGFloat = 16
        static let neverShowPadding: CGFloat = 12
        static let neverShowGap: CGFloat = 9
        static let trackSegmentHeight: CGFloat = 40
        /// Horizontal breathing room a stacked-form label is granted before
        /// the fit check decides it does not fit its equal share.
        static let trackLabelSlack: CGFloat = 4
        static let trackRowHeight: CGFloat = 48
        static let shieldHeading: CGFloat = 14
        static let panelPointer: CGFloat = 12
        /// Diagonal of the 12 pt pointer square: the peak's base width and
        /// twice its height (~17 pt).
        static let panelPeak: CGFloat = panelPointer * CGFloat(2).squareRoot()
        /// Empty-state side margin (36 pt per *Empty states*).
        static let emptyStateX: CGFloat = 36
        static let sheetTopRadius: CGFloat = 26
        static let sheetHandleWidth: CGFloat = 36
        static let sheetHandleHeight: CGFloat = 5
        static let fanCardWidth: CGFloat = 26
        static let fanCardHeight: CGFloat = 34
        static let notNowHit: CGFloat = 48
    }

    enum save {
        static let duration: TimeInterval = 0.8
        static let lidOpenDelay: TimeInterval = 0
        static let lidOpenDuration: TimeInterval = 0.18
        static let cardDropDelay: TimeInterval = 0.15
        static let cardDropDuration: TimeInterval = 0.25
        static let lidCloseDelay: TimeInterval = 0.42
        static let lidCloseDuration: TimeInterval = 0.18
        static let savedSwapDelay: TimeInterval = 0.58
        static let bumpScale: CGFloat = 1.07
        static let checkDrawDelay: TimeInterval = 0.62
        static let checkDrawDuration: TimeInterval = 0.18
    }

    enum deck {
        static let backCardCount = 2
        static let visibleCardCount = backCardCount + 1
        static let swipeThreshold: CGFloat = 40
        static let dragMinimumDistance: CGFloat = 12
        static let motionDuration: TimeInterval = 0.46
        static let faceRevealDuration: TimeInterval = 0.30
        static let faceRevealDelay: TimeInterval = 0.12
        static let hintFadeDelay: TimeInterval = 3
        static let hintFadeDuration: TimeInterval = 0.6
        static let nudgeDelay: TimeInterval = 0.7
        static let nudgeDuration: TimeInterval = 2.4
        static let nudgePeakFraction = 0.14
        static let nudgeSettleFraction = 0.3
        static let nudgeLiftDuration = nudgeDuration * nudgePeakFraction
        static let nudgeSettleDuration = nudgeDuration * (nudgeSettleFraction - nudgePeakFraction)
        static let nudgeRestDuration = nudgeDuration * (1 - nudgeSettleFraction)
        static let nudgeRepeatCount = 2
        static let nudgeDistance: CGFloat = 72
        static let nudgeRotation: Double = -3
        static let leavingTranslationScale: CGFloat = 1.15
        static let reverseAppearScale: CGFloat = 0.92
        static let leavingRotation: Double = -9
        static let frontBottomInset: CGFloat = 18
        static let back1Left: CGFloat = 4
        static let back1Right: CGFloat = 16
        static let back1Top: CGFloat = 12
        static let back1Bottom: CGFloat = 10
        static let back1Rotation: Double = -4
        static let back2Left: CGFloat = 16
        static let back2Right: CGFloat = 4
        static let back2Top: CGFloat = 20
        static let back2Bottom: CGFloat = 4
        static let back2Rotation: Double = 6
        static let cardEdgeDepth: CGFloat = 4
        static let hintHeight: CGFloat = 24
        static let dragRotationDivisor: CGFloat = 45
    }

    enum cooking {
        static let swipeThreshold: CGFloat = 40
        static let dragMinimumDistance: CGFloat = 12
        /// Card inner edge every block is left-aligned on.
        static let cardInset: CGFloat = 20
        static let headerTop: CGFloat = 16
        static let summaryGap: CGFloat = 16
        static let detailGap: CGFloat = 6
        /// Target baseline-to-baseline heights of the session texts
        /// (spec: Resumen 34/39, Detalle 17/24, ingredient rows 17/23).
        static let summaryLineHeight: CGFloat = 39
        static let detailLineHeight: CGFloat = 24
        static let ingredientLineHeight: CGFloat = 23
        /// The media window is inset 12 pt from the card edges — wider than
        /// the text blocks (cardInset 20).
        static let mediaInset: CGFloat = 12
        static let mediaHeight: CGFloat = 220
        /// The media window gives way down to this height before the body
        /// scrolls; on the finish card the photo never gets smaller either.
        static let mediaMinHeight: CGFloat = 160
        static let mediaRadius: CGFloat = 18
        static let mediaChipInset: CGFloat = 10
        static let mediaChipRadius: CGFloat = 8
        static let playCircle: CGFloat = 60
        /// The technique clip: spinner inside the play circle, 5 pt progress
        /// line along the window's bottom edge, 36 pt expand button 10 pt
        /// from the top right, and the full-screen chrome (44 pt collapse,
        /// 64 pt play/pause, scrubber and 8/24 pt safe-area gaps).
        static let clipSpinnerWidth: CGFloat = 3
        static let clipProgressHeight: CGFloat = 5
        static let clipExpandButton: CGFloat = 36
        static let clipExpandInset: CGFloat = 10
        static let clipCollapseButton: CGFloat = 44
        static let clipFullScreenCircle: CGFloat = 64
        static let clipChromeX: CGFloat = 16
        static let clipChromeTopGap: CGFloat = 8
        static let clipChromeBottomGap: CGFloat = 24
        static let clipControlsGap: CGFloat = 18
        static let clipTimeGap: CGFloat = 10
        static let clipScrubberTrack: CGFloat = 4
        static let clipScrubberKnob: CGFloat = 12
        static let sectionGap: CGFloat = 16
        static let ingredientRowGap: CGFloat = 5
        static let freeSpaceMin: CGFloat = 20
        static let timerTopGap: CGFloat = 14
        /// T1 · Line: the zone is 71 pt whatever the state — a 1 pt rule,
        /// 12 pt, the 44 pt row and 14 pt to the card's bottom edge.
        static let timerRuleHeight: CGFloat = 1
        static let timerProgressHeight: CGFloat = 2
        static let timerRuleToRow: CGFloat = 12
        static let timerButton: CGFloat = 44
        static let timerButtonGap: CGFloat = 8
        static let timerDigitLabelGap: CGFloat = 8
        static let timerZoneHeight: CGFloat = 71
        static let timerLabelTracking: CGFloat = 1.2
        /// The Stop pill of a finished Temporizador: 44 pt high, 20 pt side
        /// padding, `brand` fill over the `brandEdge` edge.
        static let timerStopPadX: CGFloat = 20
        /// Pinned bottom zone: 14 pt on top (under the hairline or the
        /// scroll edge), 20 pt at the sides, 20/14 pt at the bottom edge.
        static let bottomZoneTopGap: CGFloat = 14
        static let bottomZoneHGap: CGFloat = 20
        static let bottomZoneVGap: CGFloat = 20
        static let timerBottomGap: CGFloat = 14
        /// Signalled scroll: the fade at the bottom of the scrolling area
        /// and the "N more ingredients" chip that sits on it.
        static let signalFadeHeight: CGFloat = 32
        static let signalChipHeight: CGFloat = 32
        static let signalChipHInset: CGFloat = 16
        static let signalChipBottomGap: CGFloat = 8
        /// Paso 1 hint floats this far above the card's bottom edge.
        static let swipeHintBottom: CGFloat = 20
        static let swipeHintFadeDelay: TimeInterval = 3
        static let swipeHintFadeDuration: TimeInterval = 0.6
        /// Outcome buttons stack one per row at this height from AX1 up.
        static let outcomeButtonAXHeight: CGFloat = 56
        static let peekCardCount = 2
        static let peek1Offset: CGFloat = -4
        static let peek1Rotation: Double = -1.8
        static let peek2Offset: CGFloat = -8
        static let peek2Rotation: Double = 3.5
        static let segmentWidth: CGFloat = 22
        static let segmentHeight: CGFloat = 6
        static let segmentRadius: CGFloat = 3
        static let segmentGap: CGFloat = 6
        static let timerPillHeight: CGFloat = 26
        static let timerPillRadius: CGFloat = 13
        static let timerPillBorder: CGFloat = 1.5
        static let timerPillHGap: CGFloat = 10
        static let outcomeButtonHeight: CGFloat = 68
        static let outcomeIcon: CGFloat = 22
        static let finishHeight: CGFloat = 56
        /// Horizontal flight of a Paso leaving the stack (deck curve, x axis).
        static let leavingTranslationScale: CGFloat = 1.15
        static let leavingRotation: Double = 9
        /// Bottom sheets in the session (Leave cooking?, Alarms are off):
        /// 20 pt side padding, buttons 56 pt, 16 pt above the bottom safe
        /// area, and the gaps between title, body and buttons.
        static let sheetTitleGap: CGFloat = 8
        static let sheetBodyGap: CGFloat = 24
        static let sheetButtonGap: CGFloat = 12
        static let sheetButtonHeight: CGFloat = 56
        static let sheetBottomGap: CGFloat = 16
        /// The one-second tick that refreshes countdown presentations while
        /// any Temporizador exists.
        static let timerTickSeconds: TimeInterval = 1
    }

    enum elevation {
        static let edgeLayerCount = 4
        static let edgeLayerOffset: CGFloat = 1
        static let backFrameLineWidth: CGFloat = 1
        static let frontShadowY: CGFloat = 22
        static let frontShadowRadius: CGFloat = 17
        static let backShadowY: CGFloat = 14
        static let backShadowRadius: CGFloat = 11
        static let buttonShadowY: CGFloat = 6
        static let buttonShadowRadius: CGFloat = 6
        /// Mundo menu drop shadow: (0, 18, 34, −10, shadow), the same recipe
        /// as the front Card's.
        static let menuShadowY: CGFloat = 18
        static let menuShadowRadius: CGFloat = 17
    }

    enum layout {
        static let onboardingMaxWidth: CGFloat = 460
    }

    static let deckAnimation = Animation.timingCurve(
        0.22,
        1,
        0.36,
        1,
        duration: deck.motionDuration
    )

    static func suit(_ course: Course) -> SuitTokens {
        switch course {
        case .breakfast:
            SuitTokens(
                back: Color(hex: 0xE3A33B),
                edge: Color(hex: 0xB5761C),
                chip: Color(hex: 0xF6DFAE),
                chipInk: Color(hex: 0x6B4A10),
                chipEdge: Color(hex: 0xE3C27F)
            )
        case .lunch:
            SuitTokens(
                back: Color(hex: 0x7C9A6D),
                edge: Color(hex: 0x58724A),
                chip: Color(hex: 0xDCE6D2),
                chipInk: Color(hex: 0x3F5A34),
                chipEdge: Color(hex: 0xB9C9AA)
            )
        case .dinner:
            SuitTokens(
                back: Color(hex: 0xC8553D),
                edge: Color(hex: 0x9E3E2B),
                chip: Color(hex: 0xF4CDBF),
                chipInk: Color(hex: 0x7E2F1F),
                chipEdge: Color(hex: 0xE2A794)
            )
        case .dessert:
            SuitTokens(
                back: Color(hex: 0xC2677A),
                edge: Color(hex: 0x9C4459),
                chip: Color(hex: 0xF4D3D9),
                chipInk: Color(hex: 0x7A2E40),
                chipEdge: Color(hex: 0xE2A9B3)
            )
        }
    }
}

struct SuitTokens {
    let back: Color
    let edge: Color
    let chip: Color
    let chipInk: Color
    let chipEdge: Color
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
