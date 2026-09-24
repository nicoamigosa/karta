import Foundation
import Testing
@testable import KartaCore

@Suite("History recording")
struct HistoryTests {

    @Test("Re-recording a view preserves its first date")
    func viewDateIsSetOnlyOnce() {
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let laterDate = Date(timeIntervalSince1970: 2_000)
        var history = ViewHistory()

        history.recordView(recipeID: "r1", at: firstDate)
        history.recordView(recipeID: "r1", at: laterDate)

        #expect(history.entries == [ViewEntry(recipeID: "r1", date: firstDate)])
    }

    @Test("A cooked event becomes a dated cooking entry")
    func cookedEventGetsRecordedDate() {
        let date = Date(timeIntervalSince1970: 3_000)
        let event = CookedEvent(recipeID: "r1", outcome: nil, wasInferred: true)

        let entry = CookEntry(event: event, date: date)

        #expect(entry.recipeID == "r1")
        #expect(entry.date == date)
        #expect(entry.wasInferred)
    }

    @Test("Cooking history preserves explicit and inferred cooks distinctly")
    func historyPreservesCookOrigin() {
        let date = Date(timeIntervalSince1970: 3_000)
        let entries = [
            CookEntry(
                event: CookedEvent(recipeID: "explicit", outcome: .thumbsUp, wasInferred: false),
                date: date
            ),
            CookEntry(
                event: CookedEvent(recipeID: "inferred", outcome: nil, wasInferred: true),
                date: date
            ),
        ]

        #expect(entries.map(\.recipeID) == ["explicit", "inferred"])
        #expect(entries.map(\.wasInferred) == [false, true])
    }
}
