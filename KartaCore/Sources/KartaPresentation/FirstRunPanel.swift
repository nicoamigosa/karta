import KartaCore

/// Session-only edits. Only Show my cards commits these two answers.
public struct FirstRunPanel: Equatable, Sendable {
    public let title = "Two quick questions"
    public let subtitle = "Change them anytime in Filters."
    public let actionLabel = "Show my cards"
    public let householdLine = "Every size still shows up. Yours come first."
    public private(set) var intolerances: Set<Allergen> = []
    public private(set) var householdSize: Int?

    public var canShowCards: Bool { householdSize != nil }
    public var controls: FilterPanelPresentation {
        FilterPanelPresentation(draft: FilterDraft(),
                                safetyProfile: SafetyProfile(intolerances: intolerances),
                                householdSize: householdSize)
    }

    public var intoleranceLine: String {
        let labels = controls.intolerances.filter(\.isOn).map(\.label)
        guard let last = labels.last else {
            return householdSize == nil ? "Tap any you never eat, or none."
                : "Nothing hidden: you eat all five. Change it anytime here."
        }
        let names = labels.count == 1 ? last : labels.dropLast().joined(separator: ", ") + " and " + last
        return "\(names) will never show up. Change it anytime here."
    }

    mutating func toggle(_ allergen: Allergen) {
        if !intolerances.insert(allergen).inserted { intolerances.remove(allergen) }
    }

    mutating func chooseHousehold(_ size: Int) {
        guard (1...5).contains(size) else { return }
        householdSize = size
    }
}
