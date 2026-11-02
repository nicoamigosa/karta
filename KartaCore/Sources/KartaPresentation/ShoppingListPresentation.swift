import Foundation
import KartaCore

public struct ShoppingAddSheet: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let ingredient: Ingredient
        public let hint: String?
        public var quantity: String { ingredient.quantity }
    }
    public let recipe: Recipe
    public let rows: [Row]
    public internal(set) var selectedKeys: Set<String>
    public let isReview: Bool
    public var title: String { "Add to your list" }
    public var subtitle: String { "Untick what you already have." }
    public var canConfirm: Bool { isReview || !selectedKeys.isEmpty }
    public var buttonTitle: String {
        isReview ? "Update list" : selectedKeys.isEmpty ? "Nothing to add" : "Add \(selectedKeys.count) to list"
    }

    init(recipe: Recipe, state: KartaState, recipes: [Recipe], now: Date, review: Bool) {
        self.recipe = recipe
        isReview = review
        let leftovers = PurchasePolicy.leftovers(recipes: recipes, cooks: state.cookHistory, now: now,
                                                intolerances: state.safetyProfile.intolerances)
        rows = recipe.visibleIngredients(for: state.safetyProfile.intolerances).filter {
            !$0.isOptional && $0.allergens.isDisjoint(with: state.safetyProfile.intolerances)
        }.map { Row(ingredient: $0, hint: leftovers[$0.purchaseKey].map { "Left from your \($0)" }) }
        selectedKeys = review
            ? Set(state.shoppingList.entries.first { $0.recipeID == recipe.id }?.ingredients.map(\.purchaseKey) ?? [])
            : Set(rows.filter { !PurchasePolicy.pantryBasics.contains($0.ingredient.purchaseKey) && $0.hint == nil }
                .map(\.ingredient.purchaseKey))
    }
}

public enum ShoppingAction: Sendable {
    case openAdd(String)
    case review(String)
    case toggleChoice(String)
    case confirm
    case dismissSheet
    case toggleRow(String)
    case doneShopping
    case removeRecipe(String)
    case undo
    case dismissToast
    case setAutoAdd(Bool)
    case answerAutoAdd(Bool)
    case openList
    case closeList
    case dismissInvitation
    case seePlans([Paywall.Product])
}

extension KartaReducer {
    static func reduceShopping(_ state: inout KartaState, action: ShoppingAction, recipes: [Recipe], now: Date?) {
        switch action {
        case let .openAdd(id), let .review(id):
            guard let now, state.cookbook.isSaved(id), let recipe = recipes.first(where: { $0.id == id }),
                  state.canOpenRecipe(recipe) else { return }
            guard state.hasShoppingPremium else {
                if state.entitlement == .free { state.showsShoppingInvitation = true }
                return
            }
            let review: Bool
            if case .review = action { review = true } else { review = false }
            state.shoppingSheet = ShoppingAddSheet(recipe: recipe, state: state, recipes: recipes, now: now, review: review)
        case let .toggleChoice(key):
            guard state.shoppingSheet?.rows.contains(where: { $0.ingredient.purchaseKey == key }) == true else { return }
            if state.shoppingSheet?.selectedKeys.contains(key) == true { state.shoppingSheet?.selectedKeys.remove(key) }
            else { state.shoppingSheet?.selectedKeys.insert(key) }
        case .confirm:
            guard state.hasShoppingPremium, let sheet = state.shoppingSheet, sheet.canConfirm,
                  state.cookbook.isSaved(sheet.recipe.id) else { return }
            state.shoppingUndo = nil
            let receipt = state.shoppingList.update(recipe: sheet.recipe, purchaseKeys: sheet.selectedKeys, intolerances: state.safetyProfile.intolerances)
            registerFirstShoppingAdd(&state)
            if sheet.isReview {
                state.shoppingUndo = receipt
                state.shoppingToast = ShoppingToast(
                    title: sheet.selectedKeys.isEmpty ? "Removed from your list" : "Updated your list",
                    secondLine: sheet.recipe.name, action: receipt == nil ? nil : .undo)
            } else {
                state.shoppingToast = ShoppingToast(title: "Added to your list",
                    secondLine: "\(sheet.selectedKeys.count) \(sheet.selectedKeys.count == 1 ? "item" : "items") · \(sheet.recipe.name)", action: .seeList)
            }
            state.shoppingSheet = nil
        case .dismissSheet:
            state.shoppingSheet = nil
        case let .toggleRow(key):
            state.shoppingUndo = nil
            state.shoppingList.toggle(key)
        case .doneShopping:
            let rows = state.shoppingList.rows.filter(\.isTicked)
            guard !rows.isEmpty else { return }
            state.shoppingUndo = state.shoppingList.doneShopping()
            state.shoppingToast = ShoppingToast(title: "\(rows.count) \(rows.count == 1 ? "item" : "items") cleared",
                                                secondLine: ShoppingText.names(rows.map(\.name), limit: 3), action: .undo)
        case let .removeRecipe(id):
            guard let entry = state.shoppingList.entries.first(where: { $0.recipeID == id }) else { return }
            state.shoppingUndo = state.shoppingList.removeRecipe(id)
            state.shoppingToast = ShoppingToast(title: "Removed from your list", secondLine: entry.recipeName, action: .undo)
        case .undo:
            if let receipt = state.shoppingUndo { state.shoppingList.undo(receipt) }
            state.shoppingUndo = nil
            state.shoppingToast = nil
        case .openList:
            if state.hasShoppingPremium || !state.shoppingList.entries.isEmpty { state.showsShoppingList = true }
            else if state.entitlement == .free { state.showsShoppingInvitation = true }
        case .closeList:
            state.showsShoppingList = false
        case .dismissInvitation:
            state.showsShoppingInvitation = false
        case .seePlans(let products):
            guard state.showsShoppingInvitation else { return }
            reduce(&state, action: .paywall(.open(.shoppingList, plans: products)))
        case .setAutoAdd(let enabled):
            guard state.hasShoppingPremium else { return }
            state.addRecipesAsSaved = enabled
        case .answerAutoAdd(let enabled):
            guard state.showsAutoAddQuestion else { return }
            state.showsAutoAddQuestion = false
            state.addRecipesAsSaved = enabled && state.hasShoppingPremium
        case .dismissToast:
            if state.askAfterShoppingToast && state.hasShoppingPremium {
                state.showsAutoAddQuestion = true
            }
            state.askAfterShoppingToast = false
            state.shoppingToast = nil
            state.shoppingUndo = nil
        }
    }
}

extension KartaState {
    public var hasShoppingPremium: Bool {
        switch entitlement { case .premium?, .trial?: true; default: false }
    }
}

public struct ShoppingToast: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case seeList, undo, review(String)
        public var title: String {
            switch self { case .seeList: "See list"; case .undo: "Undo"; case .review: "Review" }
        }
    }
    public let title: String
    public let secondLine: String
    public let action: Action?
}

public struct ShoppingListPresentation: Equatable, Sendable {
    public struct Group: Equatable, Sendable {
        public let aisle: Aisle
        public var title: String {
            switch aisle {
            case .produce: "Produce"; case .meatAndFish: "Meat & fish"; case .dairyAndEggs: "Dairy & eggs"
            case .bakery: "Bakery"; case .pantry: "Pantry"; case .spices: "Spices"; case .frozen: "Frozen"; case .other: "Other"
            }
        }
        public let rows: [ShoppingList.Row]
    }
    public let groups: [Group]
    public let gotIt: [ShoppingList.Row]
    public let recipes: [ShoppingList.Entry]
    public let badge: Int?
    public let showsAutoAddSwitch: Bool
    public var isEmpty: Bool { recipes.isEmpty }
    public var canFinishShopping: Bool { !gotIt.isEmpty }
    public var gotItTitle: String { "Got it · \(gotIt.count)" }
    public var toBuyCount: Int { groups.reduce(0) { $0 + $1.rows.count } }
    public var countLabel: String {
        "\(recipes.count) \(recipes.count == 1 ? "recipe" : "recipes") · \(toBuyCount) \(gotIt.isEmpty ? "to buy" : "left to buy")"
    }
    init(state: KartaState) {
        let rows = state.shoppingList.rows
        gotIt = rows.filter(\.isTicked)
        groups = Aisle.allCases.compactMap { aisle in
            let inAisle = rows.filter { $0.aisle == aisle && !$0.isTicked }
            return inAisle.isEmpty ? nil : Group(aisle: aisle, rows: inAisle)
        }
        recipes = state.shoppingList.entries
        let left = rows.filter { !$0.isTicked }.count
        badge = state.hasShoppingPremium && left > 0 ? left : nil
        showsAutoAddSwitch = state.hasShoppingPremium && !recipes.isEmpty
    }
}

extension KartaState {
    public var shoppingPresentation: ShoppingListPresentation { ShoppingListPresentation(state: self) }
}

/// Shared grammar for the signed shopping toasts.
enum ShoppingText {
    static func names(_ names: [String], limit: Int = .max) -> String {
        let visible = Array(names.prefix(limit))
        let rest = names.count - visible.count
        let parts = visible + (rest > 0 ? ["\(rest) more"] : [])
        if parts.count <= 1 { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " and " + parts.last!
    }
}

extension KartaReducer {
    static func registerFirstShoppingAdd(_ state: inout KartaState) {
        guard !state.shoppingList.entries.isEmpty, !state.hasAskedAutoAdd else { return }
        state.hasAskedAutoAdd = true
        state.askAfterShoppingToast = true
    }

    static func autoAddSavedRecipe(_ state: inout KartaState, recipe: Recipe, recipes: [Recipe], now: Date) {
        let sheet = ShoppingAddSheet(recipe: recipe, state: state, recipes: recipes, now: now, review: false)
        state.shoppingUndo = nil
        guard !sheet.selectedKeys.isEmpty else {
            state.shoppingToast = ShoppingToast(title: "Saved · nothing to buy", secondLine: "You have the rest.", action: nil)
            return
        }
        state.shoppingList.update(recipe: recipe, purchaseKeys: sheet.selectedKeys, intolerances: state.safetyProfile.intolerances)
        registerFirstShoppingAdd(&state)
        let names = sheet.rows.filter { sheet.selectedKeys.contains($0.ingredient.purchaseKey) }.map { $0.ingredient.name }
        state.shoppingToast = ShoppingToast(
            title: "Saved · \(sheet.selectedKeys.count) \(sheet.selectedKeys.count == 1 ? "item" : "items") on your list",
            secondLine: ShoppingText.names(names) + ". You have the rest.", action: .review(recipe.id))
    }
}

public enum ShoppingInvitation {
    public static let title = "Let Karta write your list"
    public static let message = "Add a recipe and Premium puts what you need on one list, sorted by aisle and added up."
    public static let primaryTitle = "See plans"
    public static let dismissTitle = "Not now"
}

public enum ShoppingAutoAddQuestion {
    public static let title = "Add recipes as you save them?"
    public static let message = "Every recipe you save will put its ingredients on your list. You can turn this off in your list."
    public static let primaryTitle = "Yes, every time"
    public static let dismissTitle = "Only when I ask"
}

extension KartaState {
    /// One sheet identity through invitation → paywall growth, like the cap entry.
    public var shoppingEntryIsPresented: Bool {
        showsShoppingInvitation || paywall?.entry == .shoppingList
    }
}
