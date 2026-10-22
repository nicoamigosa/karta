import Testing
import KartaCore

@Suite("Cooking session — Cierre")
struct CookingFinishTests {
    @Test("Cierre follows the last Paso while legacy members still describe that Paso")
    func finishNavigation() {
        var session = CookingSession(recipeID: "r1", steps: ["Prepare", "Serve"])
        session.next(at: 10)
        #expect(!session.isOnFinish)
        session.next(at: 20)
        #expect(session.isOnFinish)
        #expect(session.finishReachedAt == 20)
        #expect(session.currentIndex == 1)
        #expect(session.currentStep?.summary == "Serve")
        #expect(session.isOnLastStep)
        #expect(session.showsOutcomePrompt)
        session.next(at: 30)
        #expect(session.isOnFinish)
        #expect(session.finishReachedAt == 20)
        session.previous()
        #expect(!session.isOnFinish)
        #expect(session.currentIndex == 1)
        session.next(at: 40)
        #expect(session.finishReachedAt == 20)
        session.exit()
        session.previous()
        session.next(at: 50)
        #expect(session.isOnFinish)
        #expect(session.isExited)
        #expect(session.respond(.photo) == nil)
    }
    @Test("One Paso reaches Cierre in one advance; an empty session never does")
    func shortSessions() {
        var one = CookingSession(recipeID: "one", steps: ["Serve"])
        one.next(at: 5)
        #expect(one.isOnFinish)
        #expect(one.finishReachedAt == 5)
        one.previous()
        #expect(one.currentIndex == 0)
        #expect(!one.isOnFinish)
        one.next()
        #expect(one.isOnFinish)
        #expect(one.finishReachedAt == 5)

        var empty = CookingSession(recipeID: "empty", steps: [])
        empty.next(at: 5)
        empty.next()
        #expect(!empty.isOnFinish)
        #expect(empty.finishReachedAt == nil)
        #expect(empty.currentStep == nil)
    }

}
