import Foundation

/// An exact, positive rational amount. Catalog spelling uses whole numbers,
/// fractions or mixed numbers; arithmetic never goes through floating point.
public struct IngredientAmount: Equatable, Sendable {
    public let numerator: Int
    public let denominator: Int

    public init(_ text: String) throws {
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        func whole(_ value: Substring) -> Int? {
            guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(value)
        }
        var numerator: Int
        var denominator = 1
        if parts.count == 1, let value = whole(parts[0]) {
            numerator = value
        } else {
            guard parts.count == 1 || parts.count == 2 else {
                throw RecipeDecodingError.invalidIngredientAmount(value: text)
            }
            let fraction = parts.last!.split(separator: "/", omittingEmptySubsequences: false)
            guard fraction.count == 2, let n = whole(fraction[0]), let d = whole(fraction[1]),
                  n > 0, d > 0 else {
                throw RecipeDecodingError.invalidIngredientAmount(value: text)
            }
            numerator = n
            denominator = d
            if parts.count == 2 {
                guard let w = whole(parts[0]), w > 0, n < d else {
                    throw RecipeDecodingError.invalidIngredientAmount(value: text)
                }
                let product = w.multipliedReportingOverflow(by: d)
                let sum = product.partialValue.addingReportingOverflow(n)
                guard !product.overflow, !sum.overflow else {
                    throw RecipeDecodingError.invalidIngredientAmount(value: text)
                }
                numerator = sum.partialValue
            }
        }
        guard numerator > 0 else { throw RecipeDecodingError.invalidIngredientAmount(value: text) }
        self.init(numerator: numerator, denominator: denominator)
    }

    private init(numerator: Int, denominator: Int) {
        let divisor = Self.gcd(numerator, denominator)
        self.numerator = numerator / divisor
        self.denominator = denominator / divisor
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    public var text: String {
        let whole = numerator / denominator
        let remainder = numerator % denominator
        if remainder == 0 { return String(whole) }
        let fraction = "\(remainder)/\(denominator)"
        return whole == 0 ? fraction : "\(whole) \(fraction)"
    }

    public func adding(_ other: Self) throws -> Self {
        let divisor = Self.gcd(denominator, other.denominator)
        let left = numerator.multipliedReportingOverflow(by: other.denominator / divisor)
        let right = other.numerator.multipliedReportingOverflow(by: denominator / divisor)
        let sum = left.partialValue.addingReportingOverflow(right.partialValue)
        let bottom = denominator.multipliedReportingOverflow(by: other.denominator / divisor)
        guard !left.overflow, !right.overflow, !sum.overflow, !bottom.overflow else {
            throw RecipeDecodingError.invalidIngredientAmount(value: "Amount total exceeds integer capacity")
        }
        return Self(numerator: sum.partialValue, denominator: bottom.partialValue)
    }
}

public enum IngredientUnit: String, Codable, CaseIterable, Sendable {
    case cup, tbsp, tsp, oz, lb
    case flOz = "fl oz"
    case small, medium, large, clove, head, slice, link, sprig, can, piece

    fileprivate func text(for amount: IngredientAmount) -> String {
        guard amount.numerator > amount.denominator else { return rawValue }
        switch self {
        case .cup, .clove, .head, .slice, .link, .sprig, .can, .piece: return rawValue + "s"
        default: return rawValue
        }
    }
}

public enum UnmeasuredQuantity: String, Codable, CaseIterable, Sendable {
    case toTaste = "to taste"
    case forFrying = "as needed for frying"
    case pinch = "a pinch"
    case fewSprigs = "a few sprigs"
}

public enum IngredientForm: String, Codable, CaseIterable, Sendable {
    case packed, grated, shaved, cooked
}

/// Declaration order is the shopping-list order.
public enum Aisle: String, Codable, CaseIterable, Comparable, Sendable {
    case produce
    case meatAndFish = "meat-and-fish"
    case dairyAndEggs = "dairy-and-eggs"
    case bakery, pantry, spices, frozen, other

    public static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

public struct IngredientQuantity: Codable, Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case measured(IngredientAmount, IngredientUnit?)
        case unmeasured(UnmeasuredQuantity)
    }
    public let content: Content
    public let form: IngredientForm?
    public let approximateWeight: String?

    private init(content: Content, form: IngredientForm?, approximateWeight: String?) {
        self.content = content
        self.form = form
        self.approximateWeight = approximateWeight
    }

    public static func measured(
        _ amount: IngredientAmount, unit: IngredientUnit? = nil,
        form: IngredientForm? = nil, approximateWeight: String? = nil
    ) -> Self {
        Self(content: .measured(amount, unit), form: form, approximateWeight: approximateWeight)
    }

    public static func unmeasured(
        _ wording: UnmeasuredQuantity, form: IngredientForm? = nil, approximateWeight: String? = nil
    ) -> Self {
        Self(content: .unmeasured(wording), form: form, approximateWeight: approximateWeight)
    }

    /// The single renderer used by both reverse ingredients and shopping totals.
    public var text: String {
        var text: String
        switch content {
        case let .measured(amount, unit):
            text = amount.text + (unit.map { " " + $0.text(for: amount) } ?? "")
        case let .unmeasured(wording): text = wording.rawValue
        }
        if let form { text += " " + form.rawValue }
        if let approximateWeight { text += " (" + approximateWeight + ")" }
        return text
    }

    private enum CodingKeys: String, CodingKey { case amount, unit, unmeasured, form, approximateWeight }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let amount = try c.decodeIfPresent(String.self, forKey: .amount)
        let wording = try c.decodeIfPresent(String.self, forKey: .unmeasured)
        guard (amount != nil) != (wording != nil) else {
            throw RecipeDecodingError.invalidIngredientQuantity
        }
        let unit = try c.decodeIfPresent(String.self, forKey: .unit)
        let decodedUnit = try unit.map { value in
            guard let unit = IngredientUnit(rawValue: value) else {
                throw RecipeDecodingError.unknownIngredientUnit(value: value)
            }
            return unit
        }
        if let amount {
            content = .measured(try IngredientAmount(amount), decodedUnit)
        } else {
            guard unit == nil else { throw RecipeDecodingError.invalidIngredientQuantity }
            guard let value = UnmeasuredQuantity(rawValue: wording!) else {
                throw RecipeDecodingError.unknownUnmeasuredQuantity(value: wording!)
            }
            content = .unmeasured(value)
        }
        form = try c.decodeIfPresent(String.self, forKey: .form).map { value in
            guard let form = IngredientForm(rawValue: value) else {
                throw RecipeDecodingError.unknownIngredientForm(value: value)
            }
            return form
        }
        approximateWeight = try c.decodeIfPresent(String.self, forKey: .approximateWeight)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch content {
        case let .measured(amount, unit):
            try c.encode(amount.text, forKey: .amount)
            try c.encodeIfPresent(unit, forKey: .unit)
        case let .unmeasured(wording): try c.encode(wording, forKey: .unmeasured)
        }
        try c.encodeIfPresent(form, forKey: .form)
        try c.encodeIfPresent(approximateWeight, forKey: .approximateWeight)
    }
}

extension IngredientQuantity {
    /// The caller groups by Clave de compra first. Units retain first-seen order;
    /// unmeasured wordings follow them, once each. No unit conversion occurs.
    public static func total(_ quantities: [Self]) throws -> String {
        var measured: [(IngredientUnit?, IngredientAmount)] = []
        var unmeasured: [UnmeasuredQuantity] = []
        for quantity in quantities {
            switch quantity.content {
            case let .measured(amount, unit):
                if let index = measured.firstIndex(where: { $0.0 == unit }) {
                    measured[index].1 = try measured[index].1.adding(amount)
                } else {
                    measured.append((unit, amount))
                }
            case let .unmeasured(wording):
                if !unmeasured.contains(wording) { unmeasured.append(wording) }
            }
        }
        let form = quantities.first?.form
        let sharedForm = quantities.allSatisfy { $0.form == form } ? form : nil
        return (measured.map { Self.measured($0.1, unit: $0.0, form: sharedForm).text }
            + unmeasured.map { Self.unmeasured($0, form: sharedForm).text }).joined(separator: " + ")
    }
}
