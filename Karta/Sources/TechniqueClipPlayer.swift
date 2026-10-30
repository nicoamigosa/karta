import AVFoundation
import SwiftUI
import KartaCore
import KartaPresentation

/// Shell-side playback of a Paso's technique clip (issue #12): resolution
/// through `MediaResolver`, the request lifecycle through
/// `MediaLoadStateMachine` (#45) and rendering through `AVPlayerLayer`.
/// The clip always plays muted and once; pausing, resuming and full screen
/// are playback concerns that live here, not in the store.
@Observable @MainActor
final class ClipPlaybackController {
    /// What the media window draws for a Paso that declares a clip.
    enum Phase: Equatable {
        /// Photo, chip and 60 pt play circle.
        case idle
        /// Play tapped; the circle keeps its glyph until the 0.3 s spinner.
        case loading
        /// The clip fills the window, no circle, progress line running.
        case playing
        /// Frozen frame; play circle plus the expand button.
        case paused
        /// Photo stays, the chip reads *Clip unavailable*, no retry.
        case failed
    }

    private(set) var phase: Phase = .idle
    /// Loading/failure truth: the presentation state machine, so a late
    /// response never flips a request that was already superseded.
    private var machine = MediaLoadStateMachine<URL>()
    private(set) var player: AVPlayer?
    /// Spinner inside the play circle, shown only after 0.3 s of loading.
    private(set) var showsSpinner = false
    private(set) var isFullScreen = false
    /// Whether the full-screen chrome (top bar, scrubber, circle) is drawn;
    /// it hides after 2 s while the clip plays and a tap brings it back.
    private(set) var controlsVisible = true

    private(set) var fraction: Double = 0
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var durationSeconds: TimeInterval = 0

    private let resolver: MediaResolver
    private let bundle: Bundle
    /// Artificial load delay, used by debug seeds to reach the spinner.
    private let loadDelay: TimeInterval

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?
    private var spinnerTask: Task<Void, Never>?
    private var hideControlsTask: Task<Void, Never>?

    init(
        resolver: MediaResolver,
        bundle: Bundle = .main,
        loadDelay: TimeInterval = 0
    ) {
        self.resolver = resolver
        self.bundle = bundle
        self.loadDelay = loadDelay
        // The clip is always silent and must never duck the cook's music.
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient, options: [.mixWithOthers]
        )
    }

    /// Play tapped on the media window: begin a load request, resolve the
    /// clip's source and hand the item to a muted player.
    func play(clip: CookingStepPresentation.Clip) {
        guard phase == .idle else { return }
        let requestID = machine.begin()
        phase = .loading
        showsSpinner = false

        spinnerTask?.cancel()
        spinnerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.3))
            guard let self, !Task.isCancelled,
                  case .loading = machine.state else { return }
            showsSpinner = true
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                if loadDelay > 0 {
                    try await Task.sleep(for: .seconds(loadDelay))
                }
                let url = try clipURL(clip.source)
                let item = AVPlayerItem(url: url)
                let asset = item.asset
                guard try await asset.load(.isPlayable) else {
                    throw MediaLoadError.requestFailed("Clip is not playable")
                }
                let duration = (try? await asset.load(.duration)) ?? .zero
                guard !Task.isCancelled else { return }
                machine.succeed(url, for: requestID)
                guard case .loaded = machine.state else { return }
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                player.actionAtItemEnd = .pause
                installObservers(on: player, item: item)
                self.player = player
                durationSeconds = max(CMTimeGetSeconds(duration), 0)
                phase = .playing
                player.play()
                scheduleControlsHide()
            } catch is CancellationError {
            } catch let error as MediaLoadError {
                machine.fail(error, for: requestID)
                finishRequest()
            } catch {
                machine.fail(.requestFailed(error.localizedDescription), for: requestID)
                finishRequest()
            }
        }
    }

    /// A tap on the window while the clip plays or is paused; it toggles the
    /// playback and never reaches the card's Paso halves.
    func windowTapped() {
        switch phase {
        case .playing:
            pause()
        case .paused:
            resume()
        case .idle, .loading, .failed:
            break
        }
    }

    func pause() {
        player?.pause()
        if phase == .playing { phase = .paused }
        cancelControlsHide()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        player?.play()
        scheduleControlsHide()
    }

    /// The expand button on the paused window: keep the frame and open the
    /// clip full screen at the same point.
    func expand() {
        guard phase == .paused || phase == .playing else { return }
        pause()
        isFullScreen = true
        controlsVisible = true
    }

    /// Collapse button or swipe down on the full screen: back to the Paso,
    /// paused at the same point.
    func collapseFullScreen() {
        guard isFullScreen else { return }
        pause()
        isFullScreen = false
    }

    /// A tap on the full-screen surface toggles the chrome; it never pauses
    /// from there — the 64 pt circle owns play/pause.
    func fullScreenTapped() {
        controlsVisible.toggle()
        if controlsVisible { scheduleControlsHide() } else { cancelControlsHide() }
    }

    /// Scrubbing the full-screen scrubber.
    func seek(toFraction fraction: Double) {
        guard let player, durationSeconds > 0 else { return }
        let clamped = min(max(fraction, 0), 1)
        let target = durationSeconds * clamped
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        elapsedSeconds = target
        self.fraction = clamped
    }

    /// The 64 pt full-screen play/pause circle.
    func fullScreenPlayTapped() {
        switch phase {
        case .playing: pause()
        case .paused: resume()
        default: break
        }
    }

    /// Changing Paso or leaving the session: release the player and put the
    /// window back to its photo, chip and play circle.
    func stop() {
        loadTask?.cancel()
        spinnerTask?.cancel()
        cancelControlsHide()
        machine.reset()
        teardownPlayer()
        phase = .idle
        fraction = 0
        elapsedSeconds = 0
        durationSeconds = 0
        showsSpinner = false
        isFullScreen = false
        controlsVisible = true
    }

    // MARK: - Internals

    /// Resolves the clip's `MediaReference` through `MediaResolver` and maps
    /// it to a playable URL (`Bundle` for bundled clips, `https` for remote).
    private func clipURL(_ source: MediaReference) throws -> URL {
        let resolved = try resolver.resolve(source)
        switch resolved {
        case let .remote(url):
            return url
        case let .bundle(resource):
            let name = (resource as NSString).deletingPathExtension
            let ext = (resource as NSString).pathExtension
            let directory = (resource as NSString).deletingLastPathComponent
            guard let url = bundle.url(
                forResource: name,
                withExtension: ext.isEmpty ? nil : ext,
                subdirectory: directory.isEmpty ? nil : directory
            ) else {
                throw MediaLoadError.missingResource(resource)
            }
            return url
        }
    }

    private func installObservers(on player: AVPlayer, item: AVPlayerItem) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = CMTimeGetSeconds(time)
                guard seconds.isFinite else { return }
                elapsedSeconds = max(seconds, 0)
                if durationSeconds > 0 {
                    fraction = min(max(seconds / durationSeconds, 0), 1)
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // The clip plays once: when it ends the photo, the chip and
                // the play circle come back, wherever it was showing.
                self?.stop()
            }
        }
    }

    private func teardownPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
    }

    private func finishRequest() {
        phase = machine.state == .idle ? .idle : .failed
        teardownPlayer()
        spinnerTask?.cancel()
        showsSpinner = false
    }

    private func scheduleControlsHide() {
        cancelControlsHide()
        guard isFullScreen else { return }
        hideControlsTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled, phase == .playing else { return }
            controlsVisible = false
        }
    }

    private func cancelControlsHide() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
    }
}

/// A video surface backed by `AVPlayerLayer`: no chrome, no sound control —
/// the clip's chrome is drawn by the window and the full-screen overlay.
struct ClipPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> ClipPlayerUIView {
        let view = ClipPlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: ClipPlayerUIView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
    }
}

final class ClipPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// `m:ss` labels for the full-screen times (`0:03` / `0:06`).
func clipTimeLabel(_ seconds: TimeInterval) -> String {
    let total = Int(ceil(max(seconds, 0)))
    return "\(total / 60):\(String(format: "%02d", total % 60))"
}

/// The clip's loading arc inside the play circle: a `chip` track and a
/// `chipInk` quarter arc spinning forever.
struct ClipSpinnerArc: View {
    let track: Color
    let arc: Color
    @State private var spinning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: KartaDesign.cooking.clipSpinnerWidth)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    arc,
                    style: StrokeStyle(
                        lineWidth: KartaDesign.cooking.clipSpinnerWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(spinning ? 360 : 0))
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .onDisappear { spinning = false }
    }
}
