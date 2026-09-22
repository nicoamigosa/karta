import KartaCore

/// The three top-level recipe worlds in the app.
public enum World: String, CaseIterable, Equatable, Hashable, Sendable {
    case forYou
    case saved
    case leftovers
}

/// A route pushed on the app's navigation stack.
public enum Route: Equatable, Hashable, Sendable {
    case recipeDetail(recipeID: String)
}

/// The recipe and relative geometry captured by the feed shell.
public struct ScrollAnchor: Equatable, Hashable, Sendable {
    public let recipeID: String
    public let relativeOffset: Double

    public init(recipeID: String, relativeOffset: Double) {
        self.recipeID = recipeID
        self.relativeOffset = relativeOffset
    }
}

/// Session-only navigation state shared by the shell and its presentation reducer.
public struct AppNavigationState: Equatable, Sendable {
    public private(set) var world: World
    public private(set) var routes: [Route]
    private var anchors: [World: ScrollAnchor]

    public init(
        world: World = .forYou,
        routes: [Route] = [],
        anchors: [World: ScrollAnchor] = [:]
    ) {
        self.world = world
        self.routes = routes
        self.anchors = anchors
    }

    /// The anchor captured for a world, or `nil` for its top position.
    public func anchor(for world: World) -> ScrollAnchor? {
        anchors[world]
    }

    /// Resolve a world's anchor against the current feed. A missing recipe
    /// means the feed has changed, so the shell should render from the top.
    public func anchor(for world: World, in feed: [Recipe]) -> ScrollAnchor? {
        guard let anchor = anchors[world], feed.contains(where: { $0.id == anchor.recipeID }) else {
            return nil
        }
        return anchor
    }

    public mutating func selectWorld(_ world: World) {
        self.world = world
    }

    public mutating func setAnchor(_ anchor: ScrollAnchor?, for world: World) {
        if let anchor {
            anchors[world] = anchor
        } else {
            anchors.removeValue(forKey: world)
        }
    }

    public mutating func discardAnchors() {
        anchors.removeAll()
    }

    public mutating func push(_ route: Route) {
        routes.append(route)
    }

    public mutating func pop() {
        guard !routes.isEmpty else { return }
        routes.removeLast()
    }
}
