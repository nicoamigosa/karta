import Testing
import Foundation
@testable import KartaCore

/// Reusable technique clips referenced by id from non-obvious steps.
@Suite("Technique clips")
struct TechniqueClipTests {

    private func makeLibrary() throws -> TechniqueClipLibrary {
        try TechniqueClipLibrary(clips: [
            TechniqueClip(id: "dice-onion", title: "How to dice an onion", seconds: 6),
            TechniqueClip(id: "check-chicken", title: "Is the chicken done?", seconds: 5),
        ])
    }

    @Test("A step referencing a clip resolves it; a plain step stays text-only")
    func resolvesClipOrTextOnly() throws {
        let library = try makeLibrary()
        let withClip = CookingStep(text: "Dice the onion", clipID: "dice-onion")
        let textOnly = CookingStep(text: "Stir")

        let clip = try #require(library.clip(for: withClip))
        #expect(clip.title == "How to dice an onion")
        #expect(library.clip(for: textOnly) == nil)
    }

    @Test("The same clip is shared across recipes by id, never duplicated")
    func sameClipSharedAcrossRecipes() throws {
        let library = try makeLibrary()
        let stepInRecipeA = CookingStep(text: "Dice onion for the soup", clipID: "dice-onion")
        let stepInRecipeB = CookingStep(text: "Dice onion for the curry", clipID: "dice-onion")

        let clipA = try #require(library.clip(for: stepInRecipeA))
        let clipB = try #require(library.clip(for: stepInRecipeB))
        #expect(clipA == clipB) // one shared clip, referenced by id
    }

    @Test("An unknown clip id resolves to nothing rather than crashing")
    func unknownClipID() throws {
        let library = try makeLibrary()
        let step = CookingStep(text: "Mystery move", clipID: "does-not-exist")
        #expect(step.text == "Mystery move")
        #expect(library.clip(for: step) == nil)
    }

    @Test("Clip decoding rejects duplicate clip ids")
    func duplicateClipIDsFailWithContext() throws {
        let json = """
        [
            { "id": "repeat-clip", "title": "First", "seconds": 5 },
            { "id": "repeat-clip", "title": "Second", "seconds": 6 }
        ]
        """

        do {
            _ = try TechniqueClipLibrary.decode(from: Data(json.utf8))
            Issue.record("Expected duplicate clip ids to be rejected")
        } catch let error as TechniqueClipDecodingError {
            #expect(error == .duplicateClipID("repeat-clip"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Clip decoding rejects empty clip ids")
    func emptyClipIDFailsWithContext() throws {
        let json = "[{ \"id\": \" \", \"title\": \"Dice onion\", \"seconds\": 5 }]"

        do {
            _ = try TechniqueClipLibrary.decode(from: Data(json.utf8))
            Issue.record("Expected an empty clip id to be rejected")
        } catch let error as TechniqueClipDecodingError {
            #expect(error == .emptyClipID(title: "Dice onion"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Clip decoding rejects empty clip titles")
    func emptyClipTitleFailsWithContext() throws {
        let json = "[{ \"id\": \"dice-onion\", \"title\": \" \", \"seconds\": 5 }]"

        do {
            _ = try TechniqueClipLibrary.decode(from: Data(json.utf8))
            Issue.record("Expected an empty clip title to be rejected")
        } catch let error as TechniqueClipDecodingError {
            #expect(error == .emptyClipTitle(clipID: "dice-onion"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Clip decoding rejects non-positive durations")
    func nonPositiveClipDurationFailsWithContext() throws {
        let json = "[{ \"id\": \"dice-onion\", \"title\": \"Dice onion\", \"seconds\": 0 }]"

        do {
            _ = try TechniqueClipLibrary.decode(from: Data(json.utf8))
            Issue.record("Expected a non-positive clip duration to be rejected")
        } catch let error as TechniqueClipDecodingError {
            #expect(error == .nonPositiveSeconds(
                clipID: "dice-onion",
                title: "Dice onion",
                value: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
