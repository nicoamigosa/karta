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
}
