import Foundation
import KartaCore

/// The shell renders the returned reverse; navigation and Apertura are already recorded.
public enum RecipeLinkOpening: Equatable, Sendable {
    case reverse(RecipeReversePresentation)
    case gone
    case notOffered(RecipeLinkNotOfferedReason)
    case ignored
}

/// One-shot Feed notice; its lifetime and animation belong to the shell.
public struct RecipeGoneNotice: Equatable, Sendable {
    public let title = "This recipe is no longer on Karta"
    public let message = "Here's your deck instead."

    public init() {}
}

/// One-shot Feed notice. The shell owns timing, VoiceOver and layout, and sends
/// dismissRecipeNotOfferedNotice on timeout, swipe or accessibility dismissal.
public struct RecipeNotOfferedNotice: Equatable, Sendable {
    public enum Icon: Equatable, Sendable { case shield, magnifier }
    public let reason: RecipeLinkNotOfferedReason

    public init(reason: RecipeLinkNotOfferedReason) { self.reason = reason }

    public var title: String {
        switch reason {
        case .allergensNotChecked: "We haven't checked this recipe's allergens yet"
        case let .intolerances(allergens): "This recipe has \(Self.names(allergens)), which you avoid"
        case let .intolerancesUnanswered(allergens): "This recipe has \(Self.names(allergens))"
        }
    }

    public var message: String {
        hasAction ? "Tell Karta what you avoid to open it." : "Here's your deck instead."
    }

    public var icon: Icon { reason == .allergensNotChecked ? .magnifier : .shield }
    public var duration: TimeInterval { hasAction ? 8 : 5 }
    public var hasAction: Bool {
        if case .intolerancesUnanswered = reason { return true }
        return false
    }
    public var buttonTitle: String? { hasAction ? "Set mine" : nil }
    /// Uses the existing first-run entry point; answering never reopens the link.
    public var action: OnboardingAction? { hasAction ? .setMine : nil }

    private static func names(_ allergens: Set<Allergen>) -> String {
        let names = allergens.map(\.rawValue).sorted()
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
