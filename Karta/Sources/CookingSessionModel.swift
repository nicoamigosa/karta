import CoreGraphics
import Foundation
import KartaCore
import KartaPresentation

/// A navigation intent inside the cooking session, produced by gestures and
/// resolved into store actions by the view. The transitions themselves live in
/// `CookingSession` — the shell only reports which gesture happened.
enum CookingCommand: Equatable {
    case next
    case previous
}

/// The pure decision behind a drag in cooking mode: horizontal swipes move
/// between Pasos (left = next, right = previous, confirmed 2026-10-19).
/// There is no vertical gesture in the session — leaving is only ever the
/// ✕ button, which asks first — so vertical swipes are ignored.
enum CookingGestureDecision {
    static func command(
        translation: CGSize,
        predictedTranslation: CGSize
    ) -> CookingCommand? {
        let width = predictedTranslation.width
        let height = predictedTranslation.height

        guard abs(width) > abs(height),
              abs(width) >= KartaDesign.cooking.swipeThreshold
        else {
            return nil
        }
        return width < 0 ? .next : .previous
    }
}

/// The pure decision behind a tap in cooking mode: the left half of the card
/// goes back a Paso, the right half advances. Buttons (play, timer, outcome,
/// ✕) sit above the tap surface so their taps never navigate.
enum CookingTapDecision {
    static func command(locationX: CGFloat, width: CGFloat) -> CookingCommand? {
        guard width > 0 else { return nil }
        return locationX < width / 2 ? .previous : .next
    }
}

/// The pure decision behind the signalled scroll's *N more ingredients* chip:
/// which FOR THIS STEP rows sit hidden under the fade. `rowBottoms` are the
/// rows' bottom edges measured in the scroll viewport's own coordinate space,
/// so they already move with the scroll — the threshold is simply
/// `viewportHeight - fadeHeight`, with no content offset added.
enum CookingScrollSignal {
    static func hiddenRows(
        rowBottoms: [Int: CGFloat],
        viewportHeight: CGFloat,
        fadeHeight: CGFloat
    ) -> (count: Int, nextIndex: Int?) {
        let threshold = viewportHeight - fadeHeight
        let hidden = rowBottoms.filter { $0.value > threshold }
        return (hidden.count, hidden.keys.min())
    }
}

/// The pure decision behind the cooking overlay: which recipe the active
/// session renders, if the session is still running. An exited session leaves
/// the overlay hidden even while its result remains in the store.
enum CookingRoute {
    static func recipe(
        for session: CookingSession?,
        in recipes: [Recipe]
    ) -> Recipe? {
        guard let session, !session.isExited else { return nil }
        return recipes.first { $0.id == session.recipeID }
    }
}

/// The pure decision behind the in-app *Time's up* sound and haptics: which
/// Temporizadores crossed zero since the last poll. A timer arms itself while
/// it is running and unfired; a paused or stopped timer never fires — paused
/// ones re-arm when they resume. The shell plays the feedback once per index
/// in the returned list.
struct TimerFireDetector {
    private var armed: Set<Int> = []

    mutating func poll(timers: [Int: StepTimer], now: TimeInterval) -> [Int] {
        armed.formIntersection(timers.keys)
        var fired: [Int] = []
        for (index, timer) in timers.sorted(by: { $0.key < $1.key }) {
            if timer.hasFired(at: now) {
                if armed.contains(index) {
                    fired.append(index)
                    armed.remove(index)
                }
            } else if !timer.isPaused {
                armed.insert(index)
            }
        }
        return fired
    }
}

/// The pure decision behind the AlarmKit mirror (ADR 0014): what the shell
/// must change so the system's alarms reflect `KartaState.timerAlarms` — no
/// more, no less. `Observed` is the shell's snapshot of `AlarmManager.alarms`
/// for the ids it manages. The view never decides: it only mirrors.
enum CookingAlarmPlan {
    /// An AlarmKit state the shell observes, in its own words so the diff is
    /// testable without importing AlarmKit.
    enum Observed: Equatable {
        case scheduled
        case countdown
        case paused
        case alerting
    }

    /// One change, in execution order.
    enum Op: Equatable {
        /// Schedule a fresh countdown for the timer (running: seconds until
        /// `endsAt`; paused: the frozen `remaining`, paused right after).
        case schedule(id: UUID, running: Bool, seconds: TimeInterval)
        case pause(id: UUID)
        case resume(id: UUID)
        /// Remove an alarm that no longer maps to a store timer (Stop,
        /// reset, leaving): `stop` while alerting, `cancel` otherwise.
        case remove(id: UUID, alerting: Bool)
    }

    /// Diff desired `TimerAlarm`s (already keyed by alarm id) against the
    /// observed AlarmKit states.
    static func diff(
        desired: [(id: UUID, state: TimerAlarm.State)],
        observed: [UUID: Observed],
        now: TimeInterval
    ) -> [Op] {
        var ops: [Op] = []
        let desiredIDs = Set(desired.map(\.id))

        for entry in desired {
            switch (entry.state, observed[entry.id]) {
            case (.running(let endsAt), nil):
                ops.append(.schedule(
                    id: entry.id, running: true,
                    seconds: max(endsAt - now, 0)
                ))
            case (.paused(let remaining), nil):
                // There is no "schedule paused": the alarm starts counting
                // down and is paused at once.
                ops.append(.schedule(id: entry.id, running: false, seconds: remaining))
            case (.running, .paused):
                ops.append(.resume(id: entry.id))
            case (.paused, .countdown), (.paused, .scheduled):
                ops.append(.pause(id: entry.id))
            case (.finished, .countdown), (.finished, .paused), (.finished, .scheduled):
                // The store reached zero; the system's own fire time is the
                // same end, so the alert arrives on its own.
                break
            case (.finished, nil):
                // Nothing to schedule and nothing to cancel: *Time's up*
                // stays until Stop in the app.
                break
            case (.running(let endsAt), .alerting):
                // A fresh timer reusing the id while the old alert rings:
                // silence it first, then schedule the new countdown.
                ops.append(.remove(id: entry.id, alerting: true))
                ops.append(.schedule(
                    id: entry.id, running: true,
                    seconds: max(endsAt - now, 0)
                ))
            default:
                // Already in agreement (paused↔paused, running↔running,
                // finished↔alerting, or a transient state the next pass
                // settles).
                break
            }
        }

        for (id, state) in observed.sorted(by: { $0.key.uuidString < $1.key.uuidString })
        where !desiredIDs.contains(id) {
            ops.append(.remove(id: id, alerting: state == .alerting))
        }
        return ops
    }

    /// What an AlarmKit-side button asks the store to do. AlarmKit's own
    /// pause, resume and Stop buttons carry no intents: they produce state
    /// transitions the shell observes, and this maps one transition (or an
    /// alerting alarm's removal) to the equivalent Temporizador action.
    /// `nil` means nothing to send.
    enum SystemEffect: Equatable {
        case pause
        case resume
        case stop
    }

    static func systemEffect(old: Observed?, new: Observed?) -> SystemEffect? {
        switch (old, new) {
        case (.countdown, .paused): return .pause
        case (.paused, .countdown): return .resume
        case (.alerting, nil): return .stop
        default: return nil
        }
    }

    /// An AlarmKit landing the mirror caused itself and must not reflect
    /// back into the store. Every op the mirror applies registers the state
    /// AlarmKit settles into (or `.gone` for a cancel/stop); exactly that
    /// landing is then skipped. Without it the mirror cannot tell its own
    /// echo from a Lock Screen press, and both directions lose presses.
    enum ExpectedEcho: Equatable {
        case arrives(Observed)
        case gone

        func matches(_ state: Observed?) -> Bool {
            switch self {
            case .arrives(let target): return state == target
            case .gone: return state == nil
            }
        }
    }

    /// An AlarmKit-side press to mirror into the store.
    struct SystemSend: Equatable {
        let id: UUID
        let effect: SystemEffect
        let stepIndex: Int
    }

    /// Splits an `alarmUpdates` snapshot into echoes of the mirror's own
    /// ops (consumed, never sent) and genuine AlarmKit-side presses (sent
    /// as indexed Temporizador actions). Per managed id:
    /// - an update landing on a registered echo consumes it — whether it
    ///   arrives as a transition or was already the settled state, and a
    ///   later target swallows any echoes AlarmKit coalesced away;
    /// - a transition landing somewhere else is a press: the pending
    ///   echoes for that id are dropped, they can no longer land;
    /// - a no-change update leaves pending echoes alone (still in flight);
    /// - anything else goes through `systemEffect` as before.
    static func classify(
        expected: [UUID: [ExpectedEcho]],
        old: [UUID: Observed],
        new: [UUID: Observed],
        ids: [(id: UUID, stepIndex: Int)]
    ) -> (sends: [SystemSend], expected: [UUID: [ExpectedEcho]]) {
        var expected = expected
        var sends: [SystemSend] = []
        for entry in ids {
            let before = old[entry.id]
            let after = new[entry.id]
            let queue = expected[entry.id] ?? []
            if let hit = queue.firstIndex(where: { $0.matches(after) }) {
                let rest = Array(queue.dropFirst(hit + 1))
                expected[entry.id] = rest.isEmpty ? nil : rest
                continue
            }
            guard before != after else { continue }
            expected[entry.id] = nil
            if let effect = systemEffect(old: before, new: after) {
                sends.append(SystemSend(
                    id: entry.id, effect: effect, stepIndex: entry.stepIndex
                ))
            }
        }
        return (sends, expected)
    }

    /// Which Paso an alarm belongs to. Ids are deterministic per
    /// `(recipeID, stepIndex)`, so the Paso is recovered by trying them all —
    /// bounded by the session's step count. This is what lets a Lock Screen
    /// press reach its own Paso (including one that is not on screen and one
    /// seen from the Cierre) without the cook ever moving.
    static func stepIndex(of alarmID: UUID, recipeID: String, stepCount: Int) -> Int? {
        (0..<stepCount).first {
            CookingAlarmID.id(recipeID: recipeID, stepIndex: $0) == alarmID
        }
    }

    /// What AlarmKit itself recorded for a button press: the remaining it
    /// froze on pause, or the fire date it computed on resume. The press's
    /// instant in AlarmKit's own words — immune to how long the app was
    /// suspended before it observed the transition.
    struct SystemPress: Equatable {
        var pausedRemaining: TimeInterval?
        var resumedFireDate: TimeInterval?
    }

    /// The instant to stamp a mirrored press with. `pauseTimer(now:)` freezes
    /// `endsAt - now`, so the store agrees with AlarmKit when
    /// `now = endsAt - alarmRemaining`. `resumeTimer(now:)` sets
    /// `endsAt = now + remaining`, so `now = alarmFireDate - remaining`.
    /// Whatever AlarmKit did not report falls back to when the update was
    /// observed (which is exact while the app is in the foreground anyway).
    static func systemInstant(
        _ effect: SystemEffect,
        press: SystemPress,
        endsAt: TimeInterval?,
        pausedRemaining: TimeInterval?,
        observedAt: TimeInterval
    ) -> TimeInterval {
        switch effect {
        case .pause:
            if let endsAt, let alarmRemaining = press.pausedRemaining {
                return endsAt - alarmRemaining
            }
        case .resume:
            if let fireDate = press.resumedFireDate, let pausedRemaining {
                return fireDate - pausedRemaining
            }
        case .stop:
            break
        }
        return observedAt
    }
}
