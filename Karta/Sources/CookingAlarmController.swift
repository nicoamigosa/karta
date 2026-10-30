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
    /// view would send. The actions are current-Paso-only, so only the
    /// alarm of the Paso on screen can be mirrored; a press on another
    /// Paso's alarm has no store action to send (see Open decisions).
    private func applySystemUpdate(_ alarms: [Alarm]) {
        let now = Date().timeIntervalSince1970
        let current = Dictionary(uniqueKeysWithValues: alarms.map { ($0.id, $0.state) })
        defer {
            observed = current
            reconcile()
        }
        guard let session = store.session, !session.isOnFinish else { return }
        let currentID = CookingAlarmID.id(
            recipeID: session.recipeID,
            stepIndex: session.currentIndex
        )
        // Track genuine countdown→paused transitions seen in-stream.
        if current[currentID] == .paused, observed[currentID] != .paused {
            systemPaused.insert(currentID)
        }
        if current[currentID] == nil {
            systemPaused.remove(currentID)
        }
        guard observed[currentID] != current[currentID] else { return }
        switch CookingAlarmPlan.systemEffect(
            old: observed[currentID].map(CookingAlarmPlan.Observed.init),
            new: current[currentID].map(CookingAlarmPlan.Observed.init)
        ) {
        case .pause:
            store.send(.pauseTimer(now: now))
        case .resume where systemPaused.contains(currentID):
            store.send(.resumeTimer(now: now))
        case .stop:
            store.send(.stopTimer(now: now))
        default:
            break
        }
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
