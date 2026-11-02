import Foundation
import KartaCore
import KartaPresentation

/// The shell's storage owner for `UserSnapshot` (#172): the packages hold
/// the encode/restore rules — the package never writes or deletes storage —
/// and the shell owns the file. Persisted answers are what make "stop 3
/// alone on a later launch while unanswered" work (`hasShownFullTour` and
/// the committed Intolerancias/Hogar survive relaunch).
enum UserSnapshotStorage {
    /// Application Support/karta/user-snapshot.json.
    static var fileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "karta", directoryHint: .isDirectory)
            .appending(path: "user-snapshot.json")
    }

    /// Where unreadable bytes are preserved: the original file is moved
    /// aside, never replaced or deleted (the snapshot contract).
    static var preservedURL: URL {
        fileURL.deletingLastPathComponent()
            .appending(path: "user-snapshot.preserved")
    }

    /// The state to launch with, or nil to start on the Baraja segura. The
    /// catalogue is supplied so the persisted cooking session gets its
    /// expiry policy; everything else restores verbatim.
    static func restoreState(catalog: [Recipe]) -> KartaState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let result = UserSnapshot.restore(
            from: data,
            now: Date().timeIntervalSince1970,
            catalog: catalog
        )
        guard let snapshot = result.snapshot else {
            if result.preservedData != nil {
                try? FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? FileManager.default.moveItem(at: fileURL, to: preservedURL)
            }
            return nil
        }
        return KartaState(snapshot: snapshot)
    }

    /// Written on every state change; the payload is a few KB and the write
    /// is atomic, so no debounce is needed.
    static func save(_ state: KartaState) {
        guard let data = try? state.userSnapshot.encoded() else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
