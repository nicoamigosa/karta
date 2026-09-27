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

        static func body() -> Font {
            .custom("Figtree", size: 16, relativeTo: .body)
        }

        static func hint() -> Font {
            .custom("Figtree", size: 13, relativeTo: .caption)
                .weight(.semibold)
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
        static let pill: CGFloat = 999
    }

    enum type {
        static let displaySoftAxis: UInt32 = 0x534F4654
        static let displayWeightAxis: UInt32 = 0x77676874
        static let displaySoft: CGFloat = 100
        static let wordmarkTracking: CGFloat = -0.8
        static let rankUnitTracking: CGFloat = 1.2
        static let cardTitleTracking: CGFloat = -0.6
        static let rankMinimumScale: CGFloat = 0.68
        static let cardTitleMinimumScale: CGFloat = 0.72
        static let rankLineLimit = 1
        static let cardTitleLineLimit = 2
    }

    enum space {
        static let screenX: CGFloat = 22
        static let headerToDeck: CGFloat = 22
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
        static let reverseButtonHit: CGFloat = 32
        static let reversePhotoEdge: CGFloat = 76
        static let reverseRowGap: CGFloat = 10
        static let stepDisc: CGFloat = 22
        static let stepCueY: CGFloat = 3
        static let backFrameInset: CGFloat = 9
        static let onboarding: CGFloat = 28
        static let onboardingGap: CGFloat = 24
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
                chipInk: Color(hex: 0x6B4A10)
            )
        case .lunch:
            SuitTokens(
                back: Color(hex: 0x7C9A6D),
                edge: Color(hex: 0x58724A),
                chip: Color(hex: 0xDCE6D2),
                chipInk: Color(hex: 0x3F5A34)
            )
        case .dinner:
            SuitTokens(
                back: Color(hex: 0xC8553D),
                edge: Color(hex: 0x9E3E2B),
                chip: Color(hex: 0xF4CDBF),
                chipInk: Color(hex: 0x7E2F1F)
            )
        case .dessert:
            SuitTokens(
                back: Color(hex: 0xC2677A),
                edge: Color(hex: 0x9C4459),
                chip: Color(hex: 0xF4D3D9),
                chipInk: Color(hex: 0x7A2E40)
            )
        }
    }
}

struct SuitTokens {
    let back: Color
    let edge: Color
    let chip: Color
    let chipInk: Color
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
