import SwiftUI
import KartaCore
import KartaPresentation

/// The technique clip full screen (`cooking-clip-fullscreen.png`): a
/// near-black `videoGround`, the clip fitted to the width and centred, the
/// collapse button and title block on top, and the scrubber, times and
/// 64 pt play/pause circle at the bottom. Always without sound or a sound
/// control; the chrome hides after 2 s while the clip plays and a tap
/// brings it back. Collapse or swipe down returns to the Paso paused at
/// the same point.
struct ClipFullScreenOverlay: View {
    let controller: ClipPlaybackController
    /// The clip's display name (from the presentation's clip chip data).
    let clipName: String
    /// The Resumen of the Paso the clip belongs to.
    let pasoSummary: String
    /// 1-based Paso number, as in "step 4".
    let stepNumber: Int

    var body: some View {
        ZStack {
            KartaDesign.ColorToken.videoGround.ignoresSafeArea()

            if let player = controller.player {
                ClipPlayerSurface(player: player, gravity: .resizeAspect)
                    .ignoresSafeArea()
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { controller.fullScreenTapped() }
                .simultaneousGesture(swipeDown)

            if controller.controlsVisible {
                controls
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: controller.controlsVisible)
        .foregroundStyle(KartaDesign.ColorToken.card)
    }

    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: KartaDesign.cooking.dragMinimumDistance)
            .onEnded { value in
                guard value.translation.height > KartaDesign.cooking.swipeThreshold,
                      abs(value.translation.height) > abs(value.translation.width)
                else { return }
                controller.collapseFullScreen()
            }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: KartaDesign.cooking.cardInset - 4) {
                Button {
                    controller.collapseFullScreen()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KartaDesign.ColorToken.card)
                        .frame(
                            width: KartaDesign.cooking.clipCollapseButton,
                            height: KartaDesign.cooking.clipCollapseButton
                        )
                        .background(
                            Circle().fill(KartaDesign.ColorToken.card.opacity(0.16))
                        )
                }
                .accessibilityLabel("Close full screen")

                VStack(alignment: .leading, spacing: 2) {
                    Text(clipName)
                        .font(.custom("Figtree", size: 15, relativeTo: .subheadline).weight(.heavy))
                        .foregroundStyle(KartaDesign.ColorToken.card)
                    Text("\(pasoSummary) · step \(stepNumber)")
                        .font(.custom("Figtree", size: 13, relativeTo: .footnote).weight(.semibold))
                        .foregroundStyle(KartaDesign.ColorToken.card.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, KartaDesign.cooking.clipChromeX)
            .padding(.top, KartaDesign.cooking.clipChromeTopGap)

            Spacer(minLength: 0)

            VStack(spacing: KartaDesign.cooking.clipControlsGap) {
                HStack(spacing: KartaDesign.cooking.clipTimeGap) {
                    Text(clipTimeLabel(controller.elapsedSeconds))
                    ClipScrubber(controller: controller)
                    Text(clipTimeLabel(controller.durationSeconds))
                }
                .font(.custom("Figtree", size: 13, relativeTo: .footnote).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(KartaDesign.ColorToken.card)

                Button {
                    controller.fullScreenPlayTapped()
                } label: {
                    Image(systemName: controller.phase == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(KartaDesign.ColorToken.ink)
                        .frame(
                            width: KartaDesign.cooking.clipFullScreenCircle,
                            height: KartaDesign.cooking.clipFullScreenCircle
                        )
                        .background(Circle().fill(KartaDesign.ColorToken.card))
                }
                .accessibilityLabel(
                    controller.phase == .playing
                        ? "Pause technique clip" : "Play technique clip"
                )
            }
            .padding(.bottom, KartaDesign.cooking.clipChromeBottomGap)
        }
    }
}

/// The full-screen scrubber: elapsed time, a `card` fill and knob over a
/// `videoTrack` track, and the total time. Dragging or tapping seeks.
struct ClipScrubber: View {
    let controller: ClipPlaybackController

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(KartaDesign.ColorToken.videoTrack)
                    .frame(height: KartaDesign.cooking.clipScrubberTrack)
                Capsule()
                    .fill(KartaDesign.ColorToken.card)
                    .frame(
                        width: geometry.size.width * controller.fraction,
                        height: KartaDesign.cooking.clipScrubberTrack
                    )
                Circle()
                    .fill(KartaDesign.ColorToken.card)
                    .frame(
                        width: KartaDesign.cooking.clipScrubberKnob,
                        height: KartaDesign.cooking.clipScrubberKnob
                    )
                    .offset(x: geometry.size.width * controller.fraction
                            - KartaDesign.cooking.clipScrubberKnob / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        controller.seek(
                            toFraction: value.location.x / geometry.size.width
                        )
                    }
            )
        }
        .frame(height: KartaDesign.cooking.clipScrubberKnob)
        .accessibilityElement()
        .accessibilityLabel("Clip progress")
        .accessibilityValue("\(clipTimeLabel(controller.elapsedSeconds)) of \(clipTimeLabel(controller.durationSeconds))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                controller.seek(toFraction: controller.fraction + 0.1)
            case .decrement:
                controller.seek(toFraction: controller.fraction - 0.1)
            @unknown default:
                break
            }
        }
    }
}
