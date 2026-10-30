import ActivityKit
import CryptoKit
import Foundation
import SwiftUI
import AlarmKit
import KartaCore
import KartaPresentation

/// Deterministic alarm identity (ADR 0014): one UUID per (recipe, Paso), so
/// reconciling stays idempotent and restart-proof.
enum CookingAlarmID {
    /// RFC 4122 UUIDv5-style: SHA-1 over a fixed namespace + the stable name.
    static func id(recipeID: String, stepIndex: Int) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 0x4B  // 'K'
        bytes[1] = 0x41  // 'A'
        let digest = Insecure.SHA1.hash(data: Data("\(recipeID)#\(stepIndex)".utf8))
        for (offset, byte) in digest.prefix(14).enumerated() {
            bytes[2 + offset] = byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

/// The shell's AlarmKit mirror (ADR 0014): it reconciles
/// `KartaState.timerAlarms` into `AlarmManager` — schedule, pause, resume and
/// cancel — and reflects AlarmKit's own buttons back into the same store
/// actions when they hit the current Paso's alarm. It owns no countdown of
/// its own.
@MainActor
final class CookingAlarmController {
    private let store: KartaStore
    private var updatesTask: Task<Void, Never>?
    /// Last observed AlarmKit states, used to detect a Lock Screen Stop.
    private var observed: [UUID: Alarm.State] = [:]
    /// Ids seen reaching `.paused` through a live `alarmUpdates` transition.
    /// A `.paused` snapshot could be a stale alarm from a previous run, and
    /// stale-paused → fresh-countdown must not read as a Lock Screen resume.
    private var systemPaused: Set<UUID> = []
    /// Lock Screen presses being mirrored to the store on their own
    /// instant; reconcile must wait or it would revert the press first.
    private var pendingSystemSends = 0
    private var permissionAsked = false

    init(store: KartaStore) {
        self.store = store
    }

    /// Observe AlarmKit for the whole session lifecycle: its own pause,
    /// resume and Stop buttons produce the same store actions as the app's.
    func start() {
        guard updatesTask == nil else { return }
        refreshObserved()
        updatesTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard !Task.isCancelled else { return }
                self?.applySystemUpdate(alarms)
            }
        }
        reconcile()
    }

    /// Reconcile the store's `timerAlarms` into AlarmKit. Called on every
    /// store-driven timer change, on the one-second tick and on appear.
    func reconcile() {
        guard pendingSystemSends == 0 else { return }
        let now = Date().timeIntervalSince1970
        let desired = store.state.timerAlarms(now: now).map {
            (
                id: CookingAlarmID.id(recipeID: $0.recipeID, stepIndex: $0.stepIndex),
                state: $0.state,
                alarm: $0
            )
        }
        if !desired.isEmpty {
            ensurePermission()
        }
        let observedStates = observed.mapValues(CookingAlarmPlan.Observed.init)
        let ops = CookingAlarmPlan.diff(
            desired: desired.map { ($0.id, $0.state) },
            observed: observedStates,
            now: now
        )
        for op in ops {
            apply(op: op, desired: desired)
        }
        refreshObserved()
    }

    /// Ask for alarm permission the first time a Temporizador exists — never
    /// before (ADR 0014). A denial still lets the timer run; the store's
    /// one-time flag shows the *Alarms are off* sheet once.
    private func ensurePermission() {
        guard !permissionAsked else { return }
        permissionAsked = true
        Task {
            let state = try? await AlarmManager.shared.requestAuthorization()
            if state != .authorized {
                store.send(.alarmPermissionDenied)
            }
            reconcile()
        }
    }

    /// Reflect AlarmKit-side transitions into the same store actions the
    /// view would send — for every Paso of the session, including from the
    /// Cierre: each alarm maps back to its own `stepIndex` (the ids are
    /// deterministic) and the press goes to the Paso-indexed
    /// `.pauseTimer/.resumeTimer/.stopTimer(stepIndex:now:)`.
    private func applySystemUpdate(_ alarms: [Alarm]) {
        let now = Date().timeIntervalSince1970
        let current = Dictionary(uniqueKeysWithValues: alarms.map { ($0.id, $0.state) })
        defer {
            observed = current
            if pendingSystemSends == 0 {
                reconcile()
            }
        }
        guard let session = store.session, !session.isExited else { return }
        // Track genuine countdown→paused transitions seen in-stream.
        for index in session.steps.indices {
            let id = CookingAlarmID.id(recipeID: session.recipeID, stepIndex: index)
            if current[id] == .paused, observed[id] != .paused {
                systemPaused.insert(id)
            }
            if current[id] == nil {
                systemPaused.remove(id)
            }
        }
        // One deferred send per affected alarm, stamped with AlarmKit's own
        // instant (`systemInstant`), not the observe time.
        var sends: [(effect: CookingAlarmPlan.SystemEffect, alarmID: UUID, stepIndex: Int)] = []
        for index in session.steps.indices {
            let alarmID = CookingAlarmID.id(recipeID: session.recipeID, stepIndex: index)
            guard observed[alarmID] != current[alarmID],
                  let effect = CookingAlarmPlan.systemEffect(
                      old: observed[alarmID].map(CookingAlarmPlan.Observed.init),
                      new: current[alarmID].map(CookingAlarmPlan.Observed.init)
                  ),
                  effect != .resume || systemPaused.contains(alarmID)
            else { continue }
            sends.append((effect, alarmID, index))
        }
        guard !sends.isEmpty else { return }
        pendingSystemSends += 1
        Task { [weak self] in
            guard let self else { return }
            for send in sends {
                let instant = await self.systemInstant(
                    for: send.effect,
                    alarmID: send.alarmID,
                    stepIndex: send.stepIndex,
                    observedAt: now
                )
                switch send.effect {
                case .pause:
                    self.store.send(.pauseTimer(stepIndex: send.stepIndex, now: instant))
                case .resume:
                    self.store.send(.resumeTimer(stepIndex: send.stepIndex, now: instant))
                case .stop:
                    self.store.send(.stopTimer(stepIndex: send.stepIndex, now: instant))
                }
            }
            self.pendingSystemSends -= 1
            self.reconcile()
        }
    }

    /// The instant AlarmKit recorded for a press. AlarmKit updates the Live
    /// Activity content state a beat after `alarmUpdates`, so a press made
    /// while the app is in the foreground can need a few retries; one made
    /// while it was suspended is already there.
    private func systemInstant(
        for effect: CookingAlarmPlan.SystemEffect,
        alarmID: UUID,
        stepIndex: Int,
        observedAt: TimeInterval
    ) async -> TimeInterval {
        // AlarmKit publishes the press's payload to the Live Activity
        // content state a beat after `alarmUpdates`, so a foreground press
        // can need a retry — bounded to ~1 s; a press observed after the
        // app was suspended is already complete on the first read.
        for attempt in 0...4 {
            let press = systemPresses()[alarmID] ?? .init()
            let missing: Bool
            switch effect {
            case .pause: missing = press.pausedRemaining == nil
            case .resume: missing = press.resumedFireDate == nil
            case .stop: missing = false
            }
            if !missing || attempt == 4 {
                let timer = store.session?.timers[stepIndex]
                return CookingAlarmPlan.systemInstant(
                    effect,
                    press: press,
                    endsAt: timer.map { $0.startedAt + $0.duration },
                    pausedRemaining: timer?.pausedRemaining,
                    observedAt: observedAt
                )
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return observedAt
    }

    /// The remaining / fire date AlarmKit recorded per alarm, read from the
    /// Live Activity content state the Lock Screen itself renders.
    private func systemPresses() -> [UUID: CookingAlarmPlan.SystemPress] {
        var presses: [UUID: CookingAlarmPlan.SystemPress] = [:]
        for activity in Activity<AlarmAttributes<KartaAlarmMetadata>>.activities {
            let state = activity.contentState
            switch state.mode {
            case .countdown(let countdown):
                presses[state.alarmID] = CookingAlarmPlan.SystemPress(
                    resumedFireDate: countdown.fireDate.timeIntervalSince1970
                )
            case .paused(let paused):
                presses[state.alarmID] = CookingAlarmPlan.SystemPress(
                    pausedRemaining: paused.totalCountdownDuration
                        - paused.previouslyElapsedDuration
                )
            default:
                break
            }
        }
        return presses
    }

    private func apply(
        op: CookingAlarmPlan.Op,
        desired: [(id: UUID, state: TimerAlarm.State, alarm: TimerAlarm)]
    ) {
        switch op {
        case let .schedule(id, running, seconds):
            guard AlarmManager.shared.authorizationState == .authorized else { return }
            guard let entry = desired.first(where: { $0.id == id }) else { return }
            let metadata = KartaAlarmMetadata(
                recipeID: entry.alarm.recipeID,
                stepIndex: entry.alarm.stepIndex,
                recipeName: entry.alarm.recipeName,
                summary: entry.alarm.summary
            )
            let title = LocalizedStringResource(stringLiteral: entry.alarm.summary)
            let presentation = AlarmPresentation(
                alert: CookingAlarmController.alertPresentation(title: title),
                countdown: .init(
                    title: title,
                    pauseButton: AlarmButton(
                        text: "Pause",
                        textColor: .white,
                        systemImageName: "pause.fill"
                    )
                ),
                paused: .init(
                    title: title,
                    resumeButton: AlarmButton(
                        text: "Resume",
                        textColor: .white,
                        systemImageName: "play.fill"
                    )
                )
            )
            let attributes = AlarmAttributes(
                presentation: presentation,
                metadata: metadata,
                tintColor: KartaDesign.ColorToken.brand
            )
            Task { [attributes] in
                let configuration = AlarmManager.AlarmConfiguration<KartaAlarmMetadata>
                    .timer(duration: max(seconds, 0.1), attributes: attributes)
                do {
                    // A stale alarm under the same deterministic id (previous
                    // run, reinstall) makes schedule fail as a duplicate:
                    // cancel first so the fresh countdown always lands.
                    try? AlarmManager.shared.cancel(id: id)
                    _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
                    if !running {
                        try AlarmManager.shared.pause(id: id)
                    }
                } catch {
                    NSLog("Karta AlarmKit schedule failed: \(error)")
                }
                self.refreshObserved()
            }
        case let .pause(id):
            try? AlarmManager.shared.pause(id: id)
            refreshObserved()
        case let .resume(id):
            try? AlarmManager.shared.resume(id: id)
            refreshObserved()
        case let .remove(id, alerting):
            if alerting {
                try? AlarmManager.shared.stop(id: id)
            } else {
                try? AlarmManager.shared.cancel(id: id)
            }
            refreshObserved()
        }
    }

    /// `AlarmPresentation.Alert(title:)` needs iOS 26.1; on iOS 26.0 the older
    /// shape takes the unused stop button it still renders on its own.
    private static func alertPresentation(title: LocalizedStringResource)
        -> AlarmPresentation.Alert
    {
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: title)
        }
        return AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill"
            )
        )
    }

    /// `AlarmManager.alarms` is the observed truth between update events.
    private func refreshObserved() {
        observed = Dictionary(
            uniqueKeysWithValues: (try? AlarmManager.shared.alarms)?.map { ($0.id, $0.state) } ?? []
        )
        systemPaused.formIntersection(observed.keys)
    }
}

private extension CookingAlarmPlan.Observed {
    init(_ state: Alarm.State) {
        switch state {
        case .scheduled: self = .scheduled
        case .countdown: self = .countdown
        case .paused: self = .paused
        case .alerting: self = .alerting
        default: self = .scheduled
        }
    }
}
