import Foundation
import KartaCore
import KartaPresentation

/// The shell's storage owner for `UserSnapshot` (#172): the packages hold
/// the encode/restore rules — the package never writes or deletes storage —
/// and the shell owns the file. Persisted answers are what make "stop 3
/// alone on a later launch while unanswered" work (`hasShownFullTour` and
/// the committed Intolerancias/Hogar survive relaunch).
enum UserSnapshotStorage {
    /// Application Support/karta — mutable so tests can point the storage
    /// at a scratch directory; every caller is on the main actor.
    nonisolated(unsafe) static var directoryURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "karta", directoryHint: .isDirectory)

    static var fileURL: URL {
        directoryURL.appending(path: "user-snapshot.json")
    }

    /// Where the first unreadable file is preserved; later failures get a
    /// unique `user-snapshot-N.preserved` name — every copy is kept.
    static var preservedURL: URL {
        directoryURL.appending(path: "user-snapshot.preserved")
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
                preserveUnreadableFile()
            }
            return nil
        }
        return KartaState(snapshot: snapshot)
    }

    /// Moves the unreadable file aside, never deleting or replacing it
    /// (ADR 0010: what isn't understood is never deleted). The first copy
    /// keeps the plain name, later ones get a unique suffix so an existing
    /// `*.preserved` never makes the move fail — and if even the move
    /// fails, the bytes are copied instead, so the next `save` can never
    /// be the only thing standing between them and loss.
    private static func preserveUnreadableFile() {
        let files = FileManager.default
        try? files.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        var target = preservedURL
        var copy = 1
        while files.fileExists(atPath: target.path) {
            copy += 1
            target = directoryURL
                .appending(path: "user-snapshot-\(copy).preserved")
        }
        do {
            try files.moveItem(at: fileURL, to: target)
        } catch {
            try? files.copyItem(at: fileURL, to: target)
        }
    }

    /// Written on every state change; the payload is a few KB and the write
    /// is atomic, so no debounce is needed.
    static func save(_ state: KartaState) {
        guard let data = try? state.userSnapshot.encoded() else { return }
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
