import Foundation

public enum TechniqueClipDecodingError: Error, Equatable, LocalizedError, Sendable {
    case emptyClipID(title: String)
    case emptyClipTitle(clipID: String)
    case nonPositiveSeconds(clipID: String, title: String, value: Int)
    case duplicateClipID(String)

    public var errorDescription: String? {
        switch self {
        case let .emptyClipID(title):
            return "Technique clip ('\(title)') has an empty id"
        case let .emptyClipTitle(clipID):
            return "Technique clip '\(clipID)' has an empty title"
        case let .nonPositiveSeconds(clipID, title, value):
            return "Technique clip '\(clipID)' ('\(title)') has non-positive duration '\(value)'"
        case let .duplicateClipID(id):
            return "Technique clip catalog contains duplicate clip id '\(id)'"
        }
    }
}

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

    public init(clips: [TechniqueClip]) throws {
        var ids = Set<String>()
        for clip in clips {
            guard !clip.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TechniqueClipDecodingError.emptyClipID(title: clip.title)
            }
            guard !clip.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TechniqueClipDecodingError.emptyClipTitle(clipID: clip.id)
            }
            guard clip.seconds > 0 else {
                throw TechniqueClipDecodingError.nonPositiveSeconds(
                    clipID: clip.id,
                    title: clip.title,
                    value: clip.seconds
                )
            }
            guard ids.insert(clip.id).inserted else {
                throw TechniqueClipDecodingError.duplicateClipID(clip.id)
            }
        }
        self.byID = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
    }

    /// The clip a step references, or `nil` if the step is text-only (or the id
    /// is unknown).
    public func clip(for step: CookingStep) -> TechniqueClip? {
        guard let id = step.clipID else { return nil }
        return byID[id]
    }

    /// Decodes a clip library from raw JSON. Pure: no I/O, easy to unit test.
    public static func decode(from data: Data) throws -> TechniqueClipLibrary {
        let clips = try JSONDecoder().decode([TechniqueClip].self, from: data)
        return try TechniqueClipLibrary(clips: clips)
    }
}
