import Foundation
import KartaCore

/// Both Cookbook halves, ready for the shell's grid. Which half is shown is
/// a shell preference, not presentation state or part of the user snapshot.
public struct CookbookPresentation: Equatable, Sendable {
    public let isSelecting: Bool
    public let selectedRecipeIDs: Set<String>
    public let canSelect: Bool
    public var selectionBarText: String {
        selectedRecipeIDs.isEmpty ? "Select recipes" : "\(selectedRecipeIDs.count) selected"
    }
    public var canRemoveSelection: Bool { isSelecting && !selectedRecipeIDs.isEmpty }
    public let cupoLine: CupoLine?
    /// Compatibility for the existing shell. New rendering uses cupoLine so only
    /// its link is underlined and tappable.
    @available(*, deprecated, message: "Use cupoLine.text and cupoLine.link")
    public var cupoCountLine: String? { cupoLine?.text }

    public struct CupoLine: Equatable, Sendable {
        public let text: String
        public let link: Link?

        public enum Link: Equatable, Sendable {
            case goUnlimited
            case manage
            public var title: String {
                switch self {
                case .goUnlimited: "Go unlimited"
                case .manage: "Manage"
                }
            }
        }
    }
    public let repertoire: [Row]
    public let wantToTry: [Row]
    public var repertoireCount: Int { repertoire.count }
    public var wantToTryCount: Int { wantToTry.count }

    public struct Row: Equatable, Sendable {
        public let recipeID: String
        public let name: String
        public let photo: MediaReference
        public let timeLabel: String
        public let intoleranceTag: String?

        fileprivate init(entry: Cookbook.Entry) {
            let recipe = entry.recipe
            intoleranceTag = IntoleranceWarning.tag(for: entry.containedIntolerances)
            recipeID = recipe.id
            name = recipe.name
            photo = recipe.heroPhoto
            timeLabel = "\(recipe.totalMinutes) MIN"
        }
    }

    fileprivate init(
        cookbook: Cookbook, cookHistory: [CookEntry], recipes: [Recipe],
        intolerances: Set<Allergen>, entitlement: Entitlement?, showsGoPremium: Bool,
        timeZone: TimeZone, isSelecting: Bool, selectedRecipeIDs: Set<String>
    ) {
        self.canSelect = !cookbook.savedIDs.isEmpty
        self.isSelecting = isSelecting
        self.selectedRecipeIDs = selectedRecipeIDs.intersection(cookbook.savedIDs)
        switch entitlement {
        case let .trial(endsAt):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "MMM d"
            cupoLine = CupoLine(text: "Free trial until \(formatter.string(from: endsAt))", link: .manage)
        case .premium:
            cupoLine = CupoLine(text: PremiumPlan.name, link: .manage)
        case .free, nil:
            if let ceiling = cookbook.saveCap,
               entitlement == nil || ceiling > Cookbook.freeSaveCap
                || ceiling - cookbook.savedIDs.count <= 2 {
                cupoLine = CupoLine(
                    text: "\(cookbook.savedIDs.count) of \(ceiling) saved on the free plan",
                    link: showsGoPremium ? .goUnlimited : nil
                )
            } else {
                cupoLine = nil
            }
        }
        let repertoireIDs = Set(cookbook.repertoireIDs(cookHistory: cookHistory))
        let wantToTryIDs = Set(cookbook.wantToTryIDs(cookHistory: cookHistory))
        // The Cookbook retains deliberate saves independently of feed filters.
        // Default resolution still excludes missing and unreviewed recipes.
        let savedRecipes = cookbook.recipes(from: recipes, filters: FeedFilters(intolerances: intolerances))
        repertoire = savedRecipes.filter { repertoireIDs.contains($0.id) }.map(Row.init)
        wantToTry = savedRecipes.filter { wantToTryIDs.contains($0.id) }.map(Row.init)
    }
}

extension KartaState {
    public func cookbookPresentation(recipes: [Recipe], timeZone: TimeZone = .current) -> CookbookPresentation {
        CookbookPresentation(
            cookbook: cookbook, cookHistory: cookHistory, recipes: recipes,
            intolerances: safetyProfile.intolerances, entitlement: entitlement,
            showsGoPremium: showsGoPremium, timeZone: timeZone,
            isSelecting: isSelectingCookbook, selectedRecipeIDs: selectedCookbookRecipeIDs
        )
    }
}

extension KartaStore {
    public func cookbookPresentation(recipes: [Recipe], timeZone: TimeZone = .current) -> CookbookPresentation {
        state.cookbookPresentation(recipes: recipes, timeZone: timeZone)
    }
}

/// The shell supplies toast duration and Undo interaction, without confirmation.
public struct UnsaveToast: Equatable, Sendable {
    public let title: String
    public let secondLine: String
    public let recipeIDs: [String]
    /// Compatibility for the single-recipe removal shell.
    public var recipeID: String { recipeIDs[0] }
}

extension KartaState {
    public func unsaveToast(recipes: [Recipe]) -> UnsaveToast? {
        guard navigation.routes.isEmpty, let removal = pendingUnsave else { return nil }
        let secondLine: String
        if let previous = removal.previousCeiling, let current = removal.newCeiling,
           previous > Cookbook.freeSaveCap, current < previous {
            secondLine = "Your cookbook now holds \(current) recipes"
        } else {
            let names = removal.recipeIDs.compactMap { id in
                recipes.first(where: { $0.id == id })?.name
            }
            guard !names.isEmpty else { return nil }
            secondLine = names.prefix(3).joined(separator: ", ")
                + (names.count > 3 ? " and \(names.count - 3) more" : "")
        }
        return UnsaveToast(
            title: removal.recipeIDs.count == 1
                ? "Removed from cookbook" : "\(removal.recipeIDs.count) recipes removed",
            secondLine: secondLine, recipeIDs: removal.recipeIDs
        )
    }
}

extension KartaStore {
    public func unsaveToast(recipes: [Recipe]) -> UnsaveToast? {
        state.unsaveToast(recipes: recipes)
    }
}

/// Count carried by the rejected save, ready for the Cookbook-full sheet.
public struct CookbookFullPresentation: Equatable, Sendable {
    public let savedCount: Int
    public let ceiling: Int
    public var countLabel: String { "\(savedCount) OF \(ceiling) SAVED" }
    public var explanation: String {
        if ceiling > Cookbook.freeSaveCap {
            return "Your cookbook keeps all \(ceiling) recipes on the free plan. Go unlimited to add more."
        }
        return "Free cookbooks hold \(Cookbook.freeSaveCap) recipes. Go unlimited to keep every recipe you like."
    }
}

extension KartaState {
    public var blockedByCap: CookbookFullPresentation? {
        guard case let .blockedByCap(saved, ceiling) = lastSaveResult else { return nil }
        return CookbookFullPresentation(savedCount: saved, ceiling: ceiling)
    }
}

extension KartaStore {
    public var blockedByCap: CookbookFullPresentation? { state.blockedByCap }
}
