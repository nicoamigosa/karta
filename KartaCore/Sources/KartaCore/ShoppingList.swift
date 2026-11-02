import Foundation

/// Retains the chosen recipe shares, including metadata for unavailable recipes.
/// Quantities are for the recipe's declared servings; no scaling or conversions.
public struct ShoppingList: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let recipeID: String
        public let recipeName: String
        public fileprivate(set) var ingredients: [Ingredient]
    }
    public struct Row: Equatable, Sendable {
        public let purchaseKey: String
        public let name: String
        public let aisle: Aisle
        public let recipeNames: String
        public let total: String
        public let isTicked: Bool
    }
    public private(set) var entries: [Entry] = []
    public private(set) var tickedKeys: Set<String> = []
    public init() {}
    init(entries: [Entry], tickedKeys: Set<String>) {
        self.entries = entries
        self.tickedKeys = tickedKeys
        pruneTicks()
    }

    public var rows: [Row] {
        var keys: [String] = []
        for ingredient in entries.flatMap(\.ingredients) where !keys.contains(ingredient.purchaseKey) {
            keys.append(ingredient.purchaseKey)
        }
        return keys.compactMap { key in
            let shares = entries.flatMap(\.ingredients).filter { $0.purchaseKey == key }
            guard let first = shares.first else { return nil }
            // Overflow keeps every exact share visible instead of losing the row.
            let total = (try? IngredientQuantity.total(shares.map(\.structuredQuantity)))
                ?? shares.compactMap { try? IngredientQuantity.total([$0.structuredQuantity]) }.joined(separator: " + ")
            return Row(purchaseKey: key, name: first.name, aisle: first.aisle,
                       recipeNames: entries.filter { $0.ingredients.contains { $0.purchaseKey == key } }
                        .map(\.recipeName).joined(separator: " · "),
                       total: total, isTicked: tickedKeys.contains(key))
        }.enumerated().sorted {
            $0.element.aisle == $1.element.aisle ? $0.offset < $1.offset : $0.element.aisle < $1.element.aisle
        }.map(\.element)
    }

    public func contains(_ recipeID: String) -> Bool { entries.contains { $0.recipeID == recipeID } }

    @discardableResult
    public mutating func update(recipe: Recipe, purchaseKeys: Set<String>, intolerances: Set<Allergen>) -> Undo? {
        let before = self
        let ingredients = recipe.visibleIngredients(for: intolerances).filter {
            !$0.isOptional && $0.allergens.isDisjoint(with: intolerances) && purchaseKeys.contains($0.purchaseKey)
        }
        if let index = entries.firstIndex(where: { $0.recipeID == recipe.id }) {
            if ingredients.isEmpty { entries.remove(at: index) }
            else { entries[index] = Entry(recipeID: recipe.id, recipeName: recipe.name, ingredients: ingredients) }
        } else if !ingredients.isEmpty {
            entries.append(Entry(recipeID: recipe.id, recipeName: recipe.name, ingredients: ingredients))
        }
        pruneTicks()
        return before == self ? nil : Undo(before: before, after: self)
    }

    public mutating func toggle(_ key: String) {
        guard rows.contains(where: { $0.purchaseKey == key }) else { return }
        if !tickedKeys.insert(key).inserted { tickedKeys.remove(key) }
    }

    /// Opaque receipt restores the removed shares and their original positions.
    public struct Undo: Equatable, Sendable {
        fileprivate let before: ShoppingList
        fileprivate let after: ShoppingList
    }
    public mutating func removeRecipe(_ id: String) -> Undo? {
        guard contains(id) else { return nil }
        let before = self
        entries.removeAll { $0.recipeID == id }
        pruneTicks()
        return Undo(before: before, after: self)
    }
    public mutating func doneShopping() -> Undo? {
        guard !tickedKeys.isEmpty else { return nil }
        let before = self
        for index in entries.indices {
            entries[index].ingredients.removeAll { tickedKeys.contains($0.purchaseKey) }
        }
        entries.removeAll { $0.ingredients.isEmpty }
        pruneTicks()
        return Undo(before: before, after: self)
    }
    public mutating func undo(_ receipt: Undo) {
        // An expired receipt cannot overwrite newer shopping changes.
        guard self == receipt.after else { return }
        self = receipt.before
    }
    private mutating func pruneTicks() {
        tickedKeys.formIntersection(Set(entries.flatMap(\.ingredients).map(\.purchaseKey)))
    }
}
