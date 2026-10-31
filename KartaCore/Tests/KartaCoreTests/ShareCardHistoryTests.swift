import Testing
import KartaCore

@Suite("Share card rule")
struct ShareCardHistoryTests {
    @Test("A retired share card cannot be revived by a late close action", arguments: [3, Int.max])
    func retirementIsPermanent(dismissals: Int) {
        var history = ShareCardHistory(shownRecipeIDs: ["old"], consecutiveDismissals: dismissals)
        history.close(for: "new", as: .shared)
        #expect(history.shownRecipeIDs == ["old"])
        #expect(history.consecutiveDismissals == dismissals)
        #expect(!history.offersCard(for: CookedEvent(recipeID: "next", outcome: .thumbsUp, wasInferred: false)))
    }

    @Test("Sharing resets the dismissal streak and keeps previously shown recipes retired")
    func sharingResetsStreak() {
        var history = ShareCardHistory()
        history.close(for: "one", as: .dismissed)
        history.close(for: "two", as: .dismissed)
        history.close(for: "three", as: .shared)
        #expect(history.consecutiveDismissals == 0)
        #expect(!history.offersCard(for: CookedEvent(recipeID: "one", outcome: .thumbsUp, wasInferred: false)))
        for id in ["four", "five", "six"] {
            #expect(history.offersCard(for: CookedEvent(recipeID: id, outcome: .thumbsUp, wasInferred: false)))
            history.close(for: id, as: .dismissed)
        }
        #expect(!history.offersCard(for: CookedEvent(recipeID: "seven", outcome: .thumbsUp, wasInferred: false)))
    }

    @Test("Only an explicit Good answer triggers the share card", arguments: [
        CookedEvent(recipeID: "one", outcome: nil, wasInferred: true),
        CookedEvent(recipeID: "one", outcome: .thumbsDown, wasInferred: false),
        CookedEvent(recipeID: "one", outcome: .photo, wasInferred: false),
        CookedEvent(recipeID: "one", outcome: .thumbsUp, wasInferred: true),
    ])
    func otherOutcomes(event: CookedEvent) {
        #expect(!ShareCardHistory().offersCard(for: event))
    }

    @Test("Three consecutive dismissals retire the share card")
    func dismissalLimit() {
        var history = ShareCardHistory()
        for id in ["one", "two", "three"] {
            #expect(history.offersCard(for: CookedEvent(recipeID: id, outcome: .thumbsUp, wasInferred: false)))
            history.close(for: id, as: .dismissed)
        }
        #expect(history.consecutiveDismissals == 3)
        #expect(!history.offersCard(for: CookedEvent(recipeID: "four", outcome: .thumbsUp, wasInferred: false)))
    }
}
