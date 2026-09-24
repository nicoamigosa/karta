import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Media load state")
struct MediaLoadStateTests {

    @Test("A superseded response cannot overwrite the active request")
    func lateResponseIsDiscarded() throws {
        var loader = MediaLoadStateMachine<ResolvedMedia>()
        let first = loader.begin()
        let second = loader.begin()
        let staleValue = ResolvedMedia.remote(URL(string: "https://img.karta.app/old.jpg")!)

        loader.succeed(staleValue, for: first)
        #expect(loader.state == .loading(requestID: second))

        loader.fail(.requestFailed("offline"), for: second)
        #expect(loader.state == .failed(
            requestID: second,
            error: .requestFailed("offline")
        ))
    }

    @Test("Missing resources, failures and retry are distinct observable states")
    func missingFailureAndRetryStatesDiffer() {
        var loader = MediaLoadStateMachine<ResolvedMedia>()
        let request = loader.begin()

        loader.fail(.missingResource("hero"), for: request)
        #expect(loader.state == .failed(
            requestID: request,
            error: .missingResource("hero")
        ))

        let retry = loader.retry()
        #expect(retry != request)
        #expect(loader.state == .loading(requestID: retry))
    }
}
