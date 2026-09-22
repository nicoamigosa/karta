import Foundation
@testable import KartaCore

struct TestClock: KartaClock {
    let now: Date
}

let testClock = TestClock(now: Date(timeIntervalSince1970: 1_000_000))
let testRecentWindow: TimeInterval = 7 * 24 * 60 * 60

func viewEntries(for recipeIDs: Set<String>) -> [ViewEntry] {
    recipeIDs.map { ViewEntry(recipeID: $0, date: testClock.now) }
}

func cookEntries(for recipeIDs: Set<String>) -> [CookEntry] {
    recipeIDs.map { CookEntry(recipeID: $0, date: testClock.now) }
}
