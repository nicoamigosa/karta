import KartaCore

/// Both Cookbook halves, ready for the shell's grid. Which half is shown is
/// a shell preference, not presentation state or part of the user snapshot.
public struct CookbookPresentation: Equatable, Sendable {
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
