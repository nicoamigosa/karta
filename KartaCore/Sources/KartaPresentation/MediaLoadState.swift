import Foundation

/// Identity assigned to each media load attempt. A completion must carry the
/// same identity before it can change the visible state.
public struct MediaRequestID: Equatable, Hashable, Sendable {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

public enum MediaLoadError: Error, Equatable, LocalizedError, Sendable {
    case missingResource(String)
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .missingResource(resource):
            return "Media resource '\(resource)' is missing"
        case let .requestFailed(message):
            return message
        }
    }
}

/// Observable states the shell maps to placeholder, error/retry, or content.
public enum LoadState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading(requestID: MediaRequestID)
    case loaded(Value)
    case failed(requestID: MediaRequestID, error: MediaLoadError)
}

/// Pure request lifecycle state. It is intentionally independent of the
/// network and Bundle so late-response behavior is testable on Linux.
public struct MediaLoadStateMachine<Value: Equatable & Sendable>: Sendable {
    public private(set) var state: LoadState<Value> = .idle
    private var activeRequestID: MediaRequestID?

    public init() {}

    /// Starts a new request and supersedes every earlier request.
    @discardableResult
    public mutating func begin() -> MediaRequestID {
        let requestID = MediaRequestID()
        activeRequestID = requestID
        state = .loading(requestID: requestID)
        return requestID
    }

    /// Starts a fresh attempt after a failure.
    @discardableResult
    public mutating func retry() -> MediaRequestID {
        begin()
    }

    /// Applies a successful response only when it belongs to the active
    /// request. A late response is deliberately ignored.
    public mutating func succeed(_ value: Value, for requestID: MediaRequestID) {
        guard activeRequestID == requestID else { return }
        state = .loaded(value)
        activeRequestID = nil
    }

    /// Applies a failure only when it belongs to the active request.
    public mutating func fail(_ error: MediaLoadError, for requestID: MediaRequestID) {
        guard activeRequestID == requestID else { return }
        state = .failed(requestID: requestID, error: error)
        activeRequestID = nil
    }

    /// Returns to the placeholder state and invalidates any in-flight result.
    public mutating func reset() {
        activeRequestID = nil
        state = .idle
    }
}
