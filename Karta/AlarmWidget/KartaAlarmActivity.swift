import AlarmKit
import SwiftUI
import WidgetKit

/// Lock Screen / Dynamic Island Temporizador (ADR 0014): renders
/// `AlarmAttributes<KartaAlarmMetadata>` countdown, paused and alert states.
/// The pause/resume/stop affordances are the system's alarm controls; the
/// app observes `alarmUpdates` and turns them into the same store actions.
struct KartaAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<KartaAlarmMetadata>.self) { context in
            LockScreenView(state: context.state, attributes: context.attributes)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    LockScreenView(state: context.state, attributes: context.attributes)
                        .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                IslandCompact(state: context.state)
            } minimal: {
                IslandCompact(state: context.state)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: AlarmPresentationState
    let attributes: AlarmAttributes<KartaAlarmMetadata>

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            HStack {
                Text(attributes.presentation.countdown?.title ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(countdown.fireDate, style: .timer)
                    .font(.title2.monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
        case .paused(let paused):
            HStack {
                Text(attributes.presentation.paused?.title ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(Self.remaining(paused))
                    .font(.title2.monospacedDigit())
            }
        case .alert:
            HStack {
                Text(attributes.presentation.alert.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("Time's up")
                    .font(.title3)
            }
        @unknown default:
            Text(attributes.presentation.alert.title)
                .font(.headline)
        }
    }

    /// The frozen countdown of a paused alarm, formatted m:ss.
    static func remaining(_ paused: AlarmPresentationState.Mode.Paused) -> String {
        let seconds = Int(
            (paused.totalCountdownDuration - paused.previouslyElapsedDuration)
                .rounded(.up)
        )
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct IslandCompact: View {
    let state: AlarmPresentationState

    var body: some View {
        if case .countdown(let countdown) = state.mode {
            Text(countdown.fireDate, style: .timer)
                .monospacedDigit()
                .font(.caption)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 60)
        } else {
            Image(systemName: "timer")
        }
    }
}
