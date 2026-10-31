import Foundation

/// App Store entitlement reported by the shell. Presentation never infers expiry
/// from a clock: the shell reports a new value when the App Store changes it.
public enum Entitlement: Equatable, Sendable {
    case free
    case trial(endsAt: Date)
    case premium
}

/// Placeholder plan name until the product decision in #153.
public enum PremiumPlan {
    public static let name = "Premium"
    public static var goPremiumTitle: String { "Go \(name)" }
}

extension KartaState {
    /// All upgrade ways in use this policy; an unresolved launch offers none.
    public var showsGoPremium: Bool { entitlement == .free }
}

extension KartaStore {
    public var showsGoPremium: Bool { state.showsGoPremium }
}
