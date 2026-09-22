import Foundation

/// A short (~6s), reusable technique clip (e.g. "how to dice an onion"). Shared
/// across many recipes — steps reference it by `id` rather than owning bespoke
/// per-recipe video.
public struct TechniqueClip: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let seconds: Int

    public init(id: String, title: String, seconds: Int) {
        self.id = id
        self.title = title
        self.seconds = seconds
    }
}

/// The shared catalog of technique clips, keyed by id. Resolving a step's clip
/// goes through here, so a clip referenced by many recipes exists only once.
public struct TechniqueClipLibrary: Equatable, Sendable {
    private let byID: [String: TechniqueClip]

    public init(clips: [TechniqueClip]) {
        self.byID = Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The clip a step references, or `nil` if the step is text-only (or the id
    /// is unknown).
    public func clip(for step: CookingStep) -> TechniqueClip? {
        guard let id = step.clipID else { return nil }
        return byID[id]
    }

    /// Decodes a clip library from raw JSON. Pure: no I/O, easy to unit test.
    public static func decode(from data: Data) throws -> TechniqueClipLibrary {
        TechniqueClipLibrary(clips: try JSONDecoder().decode([TechniqueClip].self, from: data))
    }
}
