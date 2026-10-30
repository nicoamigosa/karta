import AVFoundation
import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Technique clip playback (#12)")
struct ClipPlaybackTests {

    /// The Spanish-tortilla Paso that declares `cuajar-tortilla` (step 4),
    /// with a debug clip library pointing at the bundled debug video.
    @MainActor
    private func clipPresentation(
        source: MediaReference,
        manifest: MediaAssetManifest
    ) throws -> (CookingStepPresentation.Clip, ClipPlaybackController) {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first { $0.id == "spanish-tortilla" })
        let library = try TechniqueClipLibrary(clips: [
            TechniqueClip(
                id: "cuajar-tortilla",
                title: "Flip the tortilla",
                seconds: 6,
                source: source
            )
        ])
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 2
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.startCooking(recipe, startedAt: 0))
        while store.session?.currentIndex != 3 {
            store.send(.nextStep(now: 0))
        }
        let clip = try #require(
            store.cookingStepPresentation(for: recipe, clips: library, now: 0)?.clip
        )
        let controller = ClipPlaybackController(
            resolver: MediaResolver(manifest: manifest, baseURL: nil),
            bundle: Bundle(for: ClipPlaybackController.self)
        )
        return (clip, controller)
    }

    @MainActor
    private func waitForPhase(
        _ expected: ClipPlaybackController.Phase,
        on controller: ClipPlaybackController,
        timeout: TimeInterval = 8
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while controller.phase != expected {
            #expect(Date() < deadline, "phase stayed \(controller.phase)")
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    @Test("A bundled clip loads, plays muted and toggles pause/resume")
    @MainActor
    func bundledClipPlays() async throws {
        let (clip, controller) = try clipPresentation(
            source: .local("clips/debug.mp4"),
            manifest: MediaAssetManifest(["clips/debug.mp4": "debug-clip.mp4"])
        )
        controller.play(clip: clip)
        try await waitForPhase(.playing, on: controller)
        #expect(controller.player?.isMuted == true)

        controller.windowTapped()
        #expect(controller.phase == .paused)

        controller.windowTapped()
        #expect(controller.phase == .playing)

        controller.expand()
        #expect(controller.isFullScreen)
        #expect(controller.phase == .paused)

        controller.collapseFullScreen()
        #expect(!controller.isFullScreen)
        #expect(controller.phase == .paused)

        controller.stop()
        #expect(controller.phase == .idle)
        #expect(controller.player == nil)
    }

    @Test("A source that cannot resolve ends in the unavailable state")
    @MainActor
    func missingAssetFails() async throws {
        let (clip, controller) = try clipPresentation(
            source: .local("clips/absent.mp4"),
            manifest: MediaAssetManifest([:])
        )
        controller.play(clip: clip)
        try await waitForPhase(.failed, on: controller)
        // No retry: after a failure the window offers no way back to play.
        controller.play(clip: clip)
        #expect(controller.phase == .failed)
    }

    @Test("A bundled resource missing from the bundle ends unavailable")
    @MainActor
    func missingFileFails() async throws {
        let (clip, controller) = try clipPresentation(
            source: .local("clips/ghost.mp4"),
            manifest: MediaAssetManifest(["clips/ghost.mp4": "clips/ghost.mp4"])
        )
        controller.play(clip: clip)
        try await waitForPhase(.failed, on: controller)
    }

    @Test("Seeking clamps the fraction to the clip's bounds")
    @MainActor
    func seekClamps() async throws {
        let (clip, controller) = try clipPresentation(
            source: .local("clips/debug.mp4"),
            manifest: MediaAssetManifest(["clips/debug.mp4": "debug-clip.mp4"])
        )
        controller.play(clip: clip)
        try await waitForPhase(.playing, on: controller)
        controller.seek(toFraction: 1.5)
        #expect(controller.fraction <= 1)
        controller.seek(toFraction: -1)
        #expect(controller.fraction >= 0)
    }

    @Test("Time labels read m:ss")
    func timeLabels() {
        #expect(clipTimeLabel(0) == "0:00")
        #expect(clipTimeLabel(3.2) == "0:04")
        #expect(clipTimeLabel(6) == "0:06")
        #expect(clipTimeLabel(75) == "1:15")
    }
}
