import Foundation
import KartaCore

/// A Temporizador for the shell to mirror in AlarmKit. Absence cancels its alarm.
public struct TimerAlarm: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case running(endsAt: TimeInterval)
        case paused(remaining: TimeInterval)
        case finished
    }

    public let recipeID: String
    /// Zero-based index in the session's Pasos, matching its progress segments.
    public let stepIndex: Int
    /// The editor-written Resumen, used as the alarm title.
    public let summary: String
    public let recipeName: String
    public let state: State
}

extension KartaState {
    /// All alarms in Paso order, including finished alarms until Stop.
    /// AlarmKit mirrors this projection; it does not own the countdown.
    public func timerAlarms(now: TimeInterval) -> [TimerAlarm] {
        guard let session, !session.isExited else { return [] }
        return session.steps.indices.compactMap { index in
            guard let timer = session.timers[index] else { return nil }
            let state: TimerAlarm.State
            if let remaining = timer.pausedRemaining {
                state = .paused(remaining: remaining)
            } else if timer.hasFired(at: now) {
                state = .finished
            } else {
                state = .running(endsAt: timer.startedAt + timer.duration)
            }
            return TimerAlarm(
                recipeID: session.recipeID,
                stepIndex: index,
                summary: session.steps[index].summary,
                recipeName: session.recipeName,
                state: state
            )
        }
    }
}
