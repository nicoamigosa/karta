import Foundation

/// The time source for rules that depend on the current date.
public protocol KartaClock: Sendable {
    var now: Date { get }
}

/// A recipe that was actually shown to the user, with the date of its first
/// view.
public struct ViewEntry: Codable, Equatable, Sendable {
    public let recipeID: String
    public let date: Date

    public init(recipeID: String, date: Date) {
        self.recipeID = recipeID
        self.date = date
    }
}

/// The view history, keeping the first date at which each recipe was viewed.
public struct ViewHistory: Codable, Equatable, Sendable {
    public private(set) var entries: [ViewEntry]

    public init(entries: [ViewEntry] = []) {
        self.entries = entries
    }

    /// Record a view without renewing an existing recipe's date.
    public mutating func recordView(recipeID: String, at date: Date) {
        guard !entries.contains(where: { $0.recipeID == recipeID }) else { return }
        entries.append(ViewEntry(recipeID: recipeID, date: date))
    }
}

/// A recipe that was cooked, with the date of the event.
public struct CookEntry: Codable, Equatable, Sendable {
    public let recipeID: String
    public let date: Date
    public let wasInferred: Bool

    public init(recipeID: String, date: Date, wasInferred: Bool = false) {
        self.recipeID = recipeID
        self.date = date
        self.wasInferred = wasInferred
    }

    public init(event: CookedEvent, date: Date) {
        self.init(recipeID: event.recipeID, date: date, wasInferred: event.wasInferred)
    }
}
