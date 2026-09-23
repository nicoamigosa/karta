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

/// A recipe that the user explicitly opened, with the date of that decision.
public struct OpenEntry: Codable, Equatable, Sendable {
    public let recipeID: String
    public let date: Date

    public init(recipeID: String, date: Date) {
        self.recipeID = recipeID
        self.date = date
    }
}

/// The view history, keeping first view dates and explicit openings separately.
public struct ViewHistory: Codable, Equatable, Sendable {
    public private(set) var entries: [ViewEntry]
    public private(set) var openings: [OpenEntry]

    public init(entries: [ViewEntry] = [], openings: [OpenEntry] = []) {
        self.entries = entries
        self.openings = openings
    }

    /// Record a view without renewing an existing recipe's date.
    public mutating func recordView(recipeID: String, at date: Date) {
        guard !entries.contains(where: { $0.recipeID == recipeID }) else { return }
        entries.append(ViewEntry(recipeID: recipeID, date: date))
    }

    /// Record an explicit opening, even when the recipe already has a view.
    public mutating func recordOpen(recipeID: String, at date: Date) {
        openings.append(OpenEntry(recipeID: recipeID, date: date))
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
