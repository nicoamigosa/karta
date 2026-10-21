import KartaCore

/// Both Cookbook halves, ready for the shell's grid. Which half is shown is
/// a shell preference, not presentation state or part of the user snapshot.
public struct CookbookPresentation: Equatable, Sendable {
    public let cupoCountLine: String?
    public let repertoire: [Row]
    public let wantToTry: [Row]
    public var repertoireCount: Int { repertoire.count }
    public var wantToTryCount: Int { wantToTry.count }

    public struct Row: Equatable, Sendable {
        public let recipeID: String
        public let name: String
        public let photo: MediaReference
        public let timeLabel: String

        fileprivate init(recipe: Recipe) {
            recipeID = recipe.id
            name = recipe.name
            photo = recipe.heroPhoto
            timeLabel = "\(recipe.totalMinutes) MIN"
        }
    }

    fileprivate init(cookbook: Cookbook, cookHistory: [CookEntry], recipes: [Recipe]) {
        if let ceiling = cookbook.saveCap, ceiling - cookbook.savedIDs.count <= 2 {
            cupoCountLine = "\(cookbook.savedIDs.count) of \(ceiling) saved on the free plan"
        } else {
            cupoCountLine = nil
        }
        let repertoireIDs = Set(cookbook.repertoireIDs(cookHistory: cookHistory))
        let wantToTryIDs = Set(cookbook.wantToTryIDs(cookHistory: cookHistory))
        // The Cookbook retains deliberate saves independently of feed filters.
        // Default resolution still excludes missing and unreviewed recipes.
        let savedRecipes = cookbook.recipes(from: recipes)
        repertoire = savedRecipes.filter { repertoireIDs.contains($0.id) }.map(Row.init)
        wantToTry = savedRecipes.filter { wantToTryIDs.contains($0.id) }.map(Row.init)
    }
}

extension KartaState {
    public func cookbookPresentation(recipes: [Recipe]) -> CookbookPresentation {
        CookbookPresentation(cookbook: cookbook, cookHistory: cookHistory, recipes: recipes)
    }
}

extension KartaStore {
    public func cookbookPresentation(recipes: [Recipe]) -> CookbookPresentation {
        state.cookbookPresentation(recipes: recipes)
    }
}

/// The shell supplies toast duration and Undo interaction, without confirmation.
public struct UnsaveToast: Equatable, Sendable {
    public let title: String
    public let secondLine: String
    public let recipeID: String
}

extension KartaState {
    public func unsaveToast(recipes: [Recipe]) -> UnsaveToast? {
        guard let removal = pendingUnsave else { return nil }
        let secondLine: String
        if let previous = removal.previousCeiling, let current = removal.newCeiling,
           previous > Cookbook.freeSaveCap, current < previous {
            secondLine = "Your cookbook now holds \(current) recipes"
        } else {
            guard let recipe = recipes.first(where: { $0.id == removal.recipeID }) else { return nil }
            secondLine = recipe.name
        }
        return UnsaveToast(
            title: "Removed from cookbook", secondLine: secondLine, recipeID: removal.recipeID
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
