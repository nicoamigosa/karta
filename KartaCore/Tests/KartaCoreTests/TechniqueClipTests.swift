import Testing
@testable import KartaCore

/// Reusable technique clips referenced by id from non-obvious steps.
@Suite("Technique clips")
struct TechniqueClipTests {

    private let library = TechniqueClipLibrary(clips: [
        TechniqueClip(id: "dice-onion", title: "How to dice an onion", seconds: 6),
        TechniqueClip(id: "check-chicken", title: "Is the chicken done?", seconds: 5),
    ])

    @Test("A step referencing a clip resolves it; a plain step stays text-only")
    func resolvesClipOrTextOnly() {
        let withClip = CookingStep(text: "Dice the onion", clipID: "dice-onion")
        let textOnly = CookingStep(text: "Stir")

        #expect(library.clip(for: withClip)?.title == "How to dice an onion")
        #expect(library.clip(for: textOnly) == nil)
    }

    @Test("The same clip is shared across recipes by id, never duplicated")
    func sameClipSharedAcrossRecipes() {
        let stepInRecipeA = CookingStep(text: "Dice onion for the soup", clipID: "dice-onion")
        let stepInRecipeB = CookingStep(text: "Dice onion for the curry", clipID: "dice-onion")

        let clipA = library.clip(for: stepInRecipeA)
        let clipB = library.clip(for: stepInRecipeB)
        #expect(clipA == clipB) // one shared clip, referenced by id
    }

    @Test("An unknown clip id resolves to nothing rather than crashing")
    func unknownClipID() {
        let step = CookingStep(text: "Mystery move", clipID: "does-not-exist")
        #expect(library.clip(for: step) == nil)
    }
}
