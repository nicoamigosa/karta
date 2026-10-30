import AlarmKit

/// Alarm metadata shared byte-for-byte between the app and the widget
/// extension (the Live Activity fails to decode otherwise). The store only
/// says which Paso the Temporizador belongs to; titles come from
/// `AlarmPresentation`.
struct KartaAlarmMetadata: AlarmMetadata {
    let recipeID: String
    /// Zero-based index in the session's Pasos, matching `TimerAlarm`.
    let stepIndex: Int
    let recipeName: String
    /// The editor-written Resumen used as the alarm title.
    let summary: String
}
