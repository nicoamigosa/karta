import Foundation
import KartaCore

/// Transient sheet contract. The shell owns StoreKit and reports its products and outcomes.
public struct Paywall: Equatable, Sendable {
    public enum Feature: Equatable, Sendable {
        case unlimitedCookbook, shoppingList, freeForGood

        public var title: String {
            switch self {
            case .unlimitedCookbook: "Unlimited cookbook"
            case .shoppingList: "Shopping list"
            case .freeForGood: "Free for good"
            }
        }
        public var detail: String {
            switch self {
            case .unlimitedCookbook: "No cap. Keep every recipe worth making again."
            case .shoppingList: "Any recipe becomes a list you tick off at the store."
            case .freeForGood: "The feed, cooking and your intolerance filters."
            }
        }
    }

    /// Remove shoppingList here if #153 question 6 excludes it before launch.
    public static let features: [Feature] = [.unlimitedCookbook, .shoppingList, .freeForGood]
    public enum FooterLink: Equatable, Sendable {
        case restorePurchases, termsOfUse, privacyPolicy

        public var title: String {
            switch self {
            case .restorePurchases: "Restore purchases"
            case .termsOfUse: "Terms of Use"
            case .privacyPolicy: "Privacy Policy"
            }
        }
    }
    public static let footer: [FooterLink] = [.restorePurchases, .termsOfUse, .privacyPolicy]
    public static let dismissTitle = "Not now"

    public enum Entry: Equatable, Sendable {
        case cap(Recipe)
        case cupoLine
        case sixthSaveToast
        case worldMenu
    }

    public enum Plan: Equatable, Sendable { case yearly, monthly }

    public enum Trial: Equatable, Sendable {
        case available(days: Int)
        case used
        case none
    }

    public struct Product: Equatable, Sendable {
        public let plan: Plan
        public let price: Decimal
        public let displayPrice: String
        public let currencyCode: String
        public let localeIdentifier: String
        public let trial: Trial

        public init(plan: Plan, price: Decimal, displayPrice: String,
                    currencyCode: String, localeIdentifier: String, trial: Trial) {
            self.plan = plan
            self.price = price
            self.displayPrice = displayPrice
            self.currencyCode = currencyCode
            self.localeIdentifier = localeIdentifier
            self.trial = trial
        }

        public var name: String { plan == .yearly ? "Yearly" : "Monthly" }
        public var period: String { plan == .yearly ? "per year" : "per month" }
        public var detail: String {
            guard plan == .yearly else { return "Billed every month" }
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: localeIdentifier)
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            let equivalent = formatter.string(from: NSDecimalNumber(decimal: price / 12)) ?? ""
            return "\(equivalent) a month, billed yearly"
        }
    }

    public enum Phase: Equatable, Sendable { case ready, buying, restoring, failed, pending, welcome }
    public internal(set) var phase: Phase = .ready
    fileprivate var phaseBeforeWaiting: Phase?
    public var isDisabled: Bool { phase == .buying || phase == .restoring }
    public var canClose: Bool { !isDisabled }
    public var canPurchase: Bool { (phase == .ready || phase == .failed) && chosenProduct != nil }
    public var note: String? {
        switch phase {
        case .failed: "The App Store didn't answer. Check your connection and try again. You haven't been charged."
        case .pending: "Waiting for approval. Premium turns on by itself as soon as it's approved."
        default: nil
        }
    }

    public var title: String { phase == .welcome ? "Welcome to \(PremiumPlan.name)" : "Keep every recipe you like" }
    public internal(set) var savedRecipeName: String?
    public var message: String? {
        guard phase == .welcome else { return nil }
        return (savedRecipeName.map { "\($0) is saved. " } ?? "") + "Keep every recipe you like from now on."
    }

    public var chosenProduct: Product? { plans.first { $0.plan == selectedPlan } }
    public var buttonTitle: String? {
        if phase == .welcome { return "Done" }
        if isDisabled { return "Waiting for the App Store…" }
        if phase == .failed { return "Try again" }
        if phase == .pending { return "Close" }
        guard let product = chosenProduct else { return nil }
        if case let .available(days) = product.trial { return "Start \(days)-day free trial" }
        return "Subscribe for \(product.displayPrice) a \(selectedPlan == .yearly ? "year" : "month")"
    }
    public var renewalLine: String? {
        guard let product = chosenProduct else { return nil }
        let renewal = "Renews automatically until you cancel; cancel in Settings at least 24 hours before it renews."
        switch product.trial {
        case let .available(days):
            return "\(days) days free, then \(product.displayPrice) a \(selectedPlan == .yearly ? "year" : "month"). \(renewal)"
        case .used:
            return "Your free trial was already used on this Apple ID. \(renewal)"
        case .none:
            return renewal
        }
    }

    public let plans: [Product]
    public var savingsBadge: String? {
        guard let yearly = plans.first(where: { $0.plan == .yearly }),
              let monthly = plans.first(where: { $0.plan == .monthly }),
              yearly.currencyCode == monthly.currencyCode,
              yearly.price >= 0, monthly.price > 0 else { return nil }
        var saving = (1 - yearly.price / (12 * monthly.price)) * 100
        guard saving >= 1 else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &saving, 0, .down)
        return "SAVE \(NSDecimalNumber(decimal: rounded).intValue)%"
    }

    public let entry: Entry
    public let countLabel: String
    public internal(set) var selectedPlan: Plan = .yearly
}

public enum PaywallAction: Sendable {
    case open(Paywall.Entry, plans: [Paywall.Product])
    case purchaseStarted
    case purchaseCancelled
    case purchaseFailed
    case purchasePending
    case purchaseSucceeded(Entitlement)
    case restoreFound(Entitlement)
    case restoreFoundNothing
    case dismissRestoreToast
    case restoreStarted
    case selectPlan(Paywall.Plan)
    case close
}

extension KartaReducer {
    static func reducePaywall(_ state: inout KartaState, action: PaywallAction) {
        switch action {
        case let .open(entry, products):
            guard state.entitlement == .free, state.paywall == nil,
                  let ceiling = state.cookbook.saveCap else { return }
            if case let .cap(recipe) = entry {
                guard state.cookbook.isAtCap, !state.cookbook.isSaved(recipe.id),
                      state.canOpenRecipe(recipe) else { return }
            }
            state.restoreToast = nil
            state.paywall = Paywall(
                plans: [Paywall.Plan.yearly, .monthly].compactMap { plan in products.first { $0.plan == plan } },
                entry: entry,
                countLabel: "\(state.cookbook.savedIDs.count) OF \(ceiling) SAVED"
            )
        case let .purchaseSucceeded(entitlement):
            guard let sheet = state.paywall, sheet.phase == .buying || sheet.phase == .pending else { return }
            finishPaywall(&state, entitlement: entitlement)
        case let .restoreFound(entitlement):
            guard state.paywall?.phase == .restoring else { return }
            finishPaywall(&state, entitlement: entitlement)
        case .restoreFoundNothing:
            guard let sheet = state.paywall, sheet.phase == .restoring else { return }
            state.paywall?.phase = sheet.phaseBeforeWaiting ?? .ready
            state.paywall?.phaseBeforeWaiting = nil
            state.restoreToast = RestoreToast()
        case .dismissRestoreToast:
            state.restoreToast = nil
        case .purchaseStarted:
            guard let sheet = state.paywall, sheet.canPurchase else { return }
            state.paywall?.phaseBeforeWaiting = sheet.phase
            state.paywall?.phase = .buying
        case .restoreStarted:
            guard let sheet = state.paywall, !sheet.isDisabled, sheet.phase != .welcome else { return }
            state.paywall?.phaseBeforeWaiting = sheet.phase
            state.restoreToast = nil
            state.paywall?.phase = .restoring
        case .purchaseCancelled:
            guard let sheet = state.paywall, sheet.phase == .buying else { return }
            state.paywall?.phase = sheet.phaseBeforeWaiting ?? .ready
            state.paywall?.phaseBeforeWaiting = nil
        case .purchaseFailed:
            guard state.paywall?.phase == .buying else { return }
            state.paywall?.phase = .failed
            state.paywall?.phaseBeforeWaiting = nil
        case .purchasePending:
            guard state.paywall?.phase == .buying else { return }
            state.paywall?.phase = .pending
            state.paywall?.phaseBeforeWaiting = nil
        case let .selectPlan(plan):
            guard let sheet = state.paywall, !sheet.isDisabled, sheet.phase != .welcome else { return }
            guard state.paywall?.plans.contains(where: { $0.plan == plan }) == true else { return }
            state.paywall?.selectedPlan = plan
        case .close:
            guard state.paywall?.canClose == true else { return }
            state.paywall = nil
        }
    }
}

extension KartaReducer {
    private static func finishPaywall(_ state: inout KartaState, entitlement: Entitlement) {
        guard entitlement != .free else { return }
        reduce(&state, action: .entitlementChanged(entitlement))
        if case let .cap(recipe) = state.paywall?.entry {
            reduce(&state, action: .saveRecipe(recipe.id))
            if state.cookbook.isSaved(recipe.id) { state.paywall?.savedRecipeName = recipe.name }
        }
        state.paywall?.phase = .welcome
        state.paywall?.phaseBeforeWaiting = nil
    }
}

/// A transient toast with no action; dismiss after the shell has shown it.
public struct RestoreToast: Equatable, Sendable {
    public var title: String { "Nothing to restore" }
    public var secondLine: String { "No Karta subscription on this Apple ID" }
}
