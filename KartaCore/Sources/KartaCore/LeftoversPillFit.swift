import Foundation

/// Default-size catalog check for the signed 318 pt row (ADR 0018).
public enum LeftoversPillFit {
    public static func pillWidth(_ text: String) -> Double {
        // 9 left + 16 bowl + 6 gap + 13 right.
        44 + width(text, advances: extraBold, pointSize: 13.5)
    }

    public static func availableWidth(for recipe: Recipe) -> Double {
        let difficulty: String = switch recipe.difficulty {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
        // Two chips, each with 8 pt horizontal insets; two 8 pt gaps.
        return 318 - 48 - width("Serves \(recipe.servings)", advances: bold, pointSize: 14)
            - width(difficulty, advances: bold, pointSize: 14)
    }

    public static func validate(_ recipes: [Recipe]) throws {
        for recipe in recipes {
            var keys = Set<String>()
            let candidates = recipe.ingredients.filter {
                !$0.isOptional && !PurchasePolicy.pantryBasics.contains($0.purchaseKey)
                    && keys.insert($0.purchaseKey).inserted
            }
            // Every key may be the first match; all other distinct keys may also match.
            // Maximize the measured suffix rather than assuming proportional digits.
            let suffix = candidates.count > 1 ? (1..<candidates.count).map { " + \($0)" }
                .max { width($0, advances: extraBold, pointSize: 13.5) < width($1, advances: extraBold, pointSize: 13.5) }! : ""
            for ingredient in candidates {
                guard pillWidth(ingredient.shortName + suffix) <= availableWidth(for: recipe) else {
                    throw RecipeCatalogDecodingError.leftoversPillDoesNotFit(recipeID: recipe.id, ingredientID: ingredient.id)
                }
            }
        }
    }

    private static func width(_ text: String, advances: [Int], pointSize: Double) -> Double {
        var units = 0
        for scalar in text.unicodeScalars {
            // An unmeasured glyph must never silently pass the catalog check.
            guard (32...126).contains(scalar.value) else { return .infinity }
            units += advances[Int(scalar.value) - 32]
        }
        return Double(units) / 1000 * pointSize
    }

    // Unhinted advance widths, ASCII U+0020...U+007E in 1000 font units/em.
    // Derived using system FreeType FT_Set_Var_Design_Coordinates(wght=700/800),
    // FT_Get_Char_Index and FT_Get_Advance(FT_LOAD_NO_SCALE), not pixel bounding boxes.
    // Reproduce from repository root: python3 scripts/figtree-advances.py
    // Source: Karta/Resources/Fonts/Figtree.ttf
    // SHA256: 26ad3db9b31ff7dde67a91ff515d022d2f495cd506590699cf264f0bfe6fb714
    // No kerning/shaping adjustment; conservative sum of advances. Signed round-4
    // reference: coconut cream + 2 = 161.0855 pt; Serves 6 / Medium gap = 163.012 pt.
    private static let bold: [Int] = [
        238, 312, 412, 631, 554, 813, 647, 245, 382, 382, 488, 632, 257, 408, 248,
        432, 648, 422, 579, 556, 633, 581, 580, 556, 612, 580, 301, 305, 632, 632,
        632, 513, 992, 714, 612, 725, 700, 589, 554, 743, 750, 289, 552, 666, 537,
        857, 773, 787, 603, 789, 645, 607, 584, 704, 722, 985, 679, 647, 632, 344,
        432, 344, 581, 434, 263, 533, 596, 546, 595, 554, 393, 601, 570, 262, 291,
        538, 246, 872, 568, 581, 601, 592, 379, 466, 402, 568, 556, 835, 536, 576,
        477, 394, 256, 394, 667,
    ]
    private static let extraBold: [Int] = [
        234, 319, 454, 632, 550, 825, 649, 266, 396, 396, 491, 636, 272, 404, 267,
        452, 652, 426, 588, 561, 639, 584, 586, 564, 611, 586, 324, 326, 636, 636,
        636, 518, 993, 732, 613, 727, 705, 587, 559, 735, 749, 297, 570, 692, 545,
        863, 773, 792, 614, 793, 654, 603, 599, 702, 736, 996, 709, 666, 628, 353,
        452, 353, 595, 432, 283, 540, 600, 548, 600, 560, 404, 608, 575, 276, 301,
        562, 258, 881, 573, 582, 605, 598, 398, 479, 414, 573, 573, 859, 564, 599,
        471, 398, 256, 398, 713,
    ]
}
