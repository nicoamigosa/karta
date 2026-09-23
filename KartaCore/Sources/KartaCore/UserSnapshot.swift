import Foundation

/// The user-owned state that survives an app launch.
///
/// This value is deliberately not `Codable`. `encoded()` maps it to the
/// versioned DTO below so changes to the domain model cannot silently change
/// the on-disk format.
public struct UserSnapshot: Equatable, Sendable {
    public static let currentVersion = 1

    public let profile: OnboardingProfile
    public let cookbook: Cookbook
    public let viewHistory: ViewHistory
    public let cookHistory: [CookEntry]
    public let tasteCalibration: TasteCalibration
    public let cookingSession: CookingSession?

    public init(
        profile: OnboardingProfile,
        cookbook: Cookbook = Cookbook(),
        viewHistory: ViewHistory = ViewHistory(),
        cookHistory: [CookEntry] = [],
        tasteCalibration: TasteCalibration = TasteCalibration(),
        cookingSession: CookingSession? = nil
    ) {
        self.profile = profile
        self.cookbook = cookbook
        self.viewHistory = viewHistory
        self.cookHistory = cookHistory
        self.tasteCalibration = tasteCalibration
        self.cookingSession = cookingSession
    }

    /// An explicit safe state used when persisted bytes cannot be understood.
    public static let safeDefault = UserSnapshot(
        profile: OnboardingProfile(intolerances: [], householdSize: 1)
    )

    /// Encode the snapshot without performing any storage I/O.
    public func encoded() throws -> Data {
        let dto = UserSnapshotDTO(
            version: Self.currentVersion,
            profile: ProfileDTO(
                intolerances: profile.intolerances.map(\.rawValue).sorted(),
                householdSize: profile.householdSize
            ),
            cookbook: CookbookDTO(
                savedIDs: cookbook.savedIDs,
                saveCap: cookbook.saveCap
            ),
            viewHistory: ViewHistoryDTO(
                entries: viewHistory.entries.map(ViewEntryDTO.init),
                openings: viewHistory.openings.map(OpenEntryDTO.init)
            ),
            cookHistory: cookHistory.map(CookEntryDTO.init),
            tasteCalibration: TasteCalibrationDTO(
                likedIDs: tasteCalibration.likedIDs
            ),
            cookingSession: cookingSession.map(CookingSessionDTO.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(dto)
    }

    /// Decode persisted bytes, retaining unreadable input for the storage owner.
    ///
    /// The package never writes or deletes storage. Callers should keep
    /// `preservedData` untouched when it is non-nil and start with `snapshot`.
    public static func restore(from data: Data) -> SnapshotRestoreResult {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let version = try decoder.decode(VersionDTO.self, from: data).version
            guard (0...Self.currentVersion).contains(version) else {
                throw SnapshotDecodingError.unsupportedVersion(version)
            }
            let dto = try decoder.decode(UserSnapshotDTO.self, from: data)
            return SnapshotRestoreResult(snapshot: try dto.snapshot(), preservedData: nil)
        } catch {
            return SnapshotRestoreResult(snapshot: Self.safeDefault, preservedData: data)
        }
    }
}

/// The result of attempting to restore a snapshot.
public struct SnapshotRestoreResult: Equatable, Sendable {
    /// Always safe to start the app with, including after a decode failure.
    public let snapshot: UserSnapshot
    /// The exact original bytes when restoration failed. Storage owners must
    /// preserve these bytes rather than replacing or deleting them.
    public let preservedData: Data?

    public var wasRestored: Bool { preservedData == nil }

    fileprivate init(snapshot: UserSnapshot, preservedData: Data?) {
        self.snapshot = snapshot
        self.preservedData = preservedData
    }
}

private enum SnapshotDecodingError: Error {
    case unsupportedVersion(Int)
    case invalidValue
}

private struct VersionDTO: Decodable {
    let version: Int
}

// MARK: - Version 1 wire DTOs

private struct UserSnapshotDTO: Codable {
    let version: Int
    let profile: ProfileDTO?
    let cookbook: CookbookDTO?
    let viewHistory: ViewHistoryDTO?
    let cookHistory: [CookEntryDTO]?
    let tasteCalibration: TasteCalibrationDTO?
    let cookingSession: CookingSessionDTO?

    func snapshot() throws -> UserSnapshot {
        let profileDTO = profile ?? ProfileDTO(intolerances: [], householdSize: 1)
        let allergens = try Set(profileDTO.intolerances.map { rawValue in
            guard let allergen = Allergen(rawValue: rawValue) else {
                throw SnapshotDecodingError.invalidValue
            }
            return allergen
        })
        guard profileDTO.householdSize > 0 else {
            throw SnapshotDecodingError.invalidValue
        }

        let cookbookDTO = cookbook ?? CookbookDTO(
            savedIDs: [],
            saveCap: Cookbook.freeSaveCap
        )
        if let saveCap = cookbookDTO.saveCap, saveCap < 0 {
            throw SnapshotDecodingError.invalidValue
        }

        let historyDTO = viewHistory ?? ViewHistoryDTO(entries: [], openings: [])
        let history = ViewHistory(
            entries: historyDTO.entries.map { $0.domainValue },
            openings: historyDTO.openings.map { $0.domainValue }
        )

        return UserSnapshot(
            profile: OnboardingProfile(
                intolerances: allergens,
                householdSize: profileDTO.householdSize
            ),
            cookbook: Cookbook(
                savedIDs: cookbookDTO.savedIDs,
                saveCap: cookbookDTO.saveCap
            ),
            viewHistory: history,
            cookHistory: (cookHistory ?? []).map(\.domainValue),
            tasteCalibration: TasteCalibration(
                likedIDs: tasteCalibration?.likedIDs ?? []
            ),
            cookingSession: try cookingSession?.domainValue
        )
    }
}

private struct ProfileDTO: Codable {
    let intolerances: [String]
    let householdSize: Int

    init(intolerances: [String], householdSize: Int) {
        self.intolerances = intolerances
        self.householdSize = householdSize
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intolerances = try container.decodeIfPresent([String].self, forKey: .intolerances) ?? []
        householdSize = try container.decodeIfPresent(Int.self, forKey: .householdSize) ?? 1
    }

    private enum CodingKeys: String, CodingKey {
        case intolerances
        case householdSize
    }
}

private struct CookbookDTO: Codable {
    let savedIDs: [String]
    let saveCap: Int?

    init(savedIDs: [String], saveCap: Int?) {
        self.savedIDs = savedIDs
        self.saveCap = saveCap
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedIDs = try container.decodeIfPresent([String].self, forKey: .savedIDs) ?? []
        // A missing ceiling is legacy data and means the normal free ceiling;
        // an explicit null remains the domain's unlimited value.
        saveCap = container.contains(.saveCap)
            ? try container.decodeIfPresent(Int.self, forKey: .saveCap)
            : Cookbook.freeSaveCap
    }

    private enum CodingKeys: String, CodingKey {
        case savedIDs
        case saveCap
    }
}

private struct ViewHistoryDTO: Codable {
    let entries: [ViewEntryDTO]
    let openings: [OpenEntryDTO]

    init(entries: [ViewEntryDTO], openings: [OpenEntryDTO]) {
        self.entries = entries
        self.openings = openings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([ViewEntryDTO].self, forKey: .entries) ?? []
        openings = try container.decodeIfPresent([OpenEntryDTO].self, forKey: .openings) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case entries
        case openings
    }
}

private struct ViewEntryDTO: Codable {
    let recipeID: String
    let date: Date

    init(_ entry: ViewEntry) {
        recipeID = entry.recipeID
        date = entry.date
    }

    var domainValue: ViewEntry { ViewEntry(recipeID: recipeID, date: date) }
}

private struct OpenEntryDTO: Codable {
    let recipeID: String
    let date: Date

    init(_ entry: OpenEntry) {
        recipeID = entry.recipeID
        date = entry.date
    }

    var domainValue: OpenEntry { OpenEntry(recipeID: recipeID, date: date) }
}

private struct CookEntryDTO: Codable {
    let recipeID: String
    let date: Date
    let wasInferred: Bool

    init(_ entry: CookEntry) {
        recipeID = entry.recipeID
        date = entry.date
        wasInferred = entry.wasInferred
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipeID = try container.decode(String.self, forKey: .recipeID)
        date = try container.decode(Date.self, forKey: .date)
        wasInferred = try container.decodeIfPresent(Bool.self, forKey: .wasInferred) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case recipeID
        case date
        case wasInferred
    }

    var domainValue: CookEntry {
        CookEntry(recipeID: recipeID, date: date, wasInferred: wasInferred)
    }
}

private struct TasteCalibrationDTO: Codable {
    let likedIDs: [String]

    init(likedIDs: [String]) {
        self.likedIDs = likedIDs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        likedIDs = try container.decodeIfPresent([String].self, forKey: .likedIDs) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case likedIDs
    }
}

private struct CookingSessionDTO: Codable {
    let recipeID: String
    let steps: [CookingStepDTO]
    let currentIndex: Int
    let isExited: Bool
    let cookedEvent: CookedEventDTO?
    let timers: [StepTimerDTO]

    init(_ session: CookingSession) {
        recipeID = session.recipeID
        steps = session.steps.map(CookingStepDTO.init)
        currentIndex = session.currentIndex
        isExited = session.isExited
        cookedEvent = session.cookedEvent.map(CookedEventDTO.init)
        timers = session.timers
            .map { StepTimerDTO(stepIndex: $0.key, timer: $0.value) }
            .sorted { $0.stepIndex < $1.stepIndex }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipeID = try container.decode(String.self, forKey: .recipeID)
        steps = try container.decode([CookingStepDTO].self, forKey: .steps)
        currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex) ?? 0
        isExited = try container.decodeIfPresent(Bool.self, forKey: .isExited) ?? false
        cookedEvent = try container.decodeIfPresent(CookedEventDTO.self, forKey: .cookedEvent)
        timers = try container.decodeIfPresent([StepTimerDTO].self, forKey: .timers) ?? []
    }

    var domainValue: CookingSession {
        get throws {
            guard currentIndex >= 0,
                  (steps.isEmpty && currentIndex == 0)
                    || (!steps.isEmpty && steps.indices.contains(currentIndex)) else {
                throw SnapshotDecodingError.invalidValue
            }

            var timersByStep: [Int: StepTimer] = [:]
            for timer in timers {
                guard steps.indices.contains(timer.stepIndex), timer.startedAt.isFinite,
                      timer.duration.isFinite, timer.duration >= 0 else {
                    throw SnapshotDecodingError.invalidValue
                }
                guard timersByStep[timer.stepIndex] == nil else {
                    throw SnapshotDecodingError.invalidValue
                }
                timersByStep[timer.stepIndex] = StepTimer(
                    startedAt: timer.startedAt,
                    duration: timer.duration
                )
            }

            return CookingSession(
                recipeID: recipeID,
                steps: steps.map(\.domainValue),
                currentIndex: currentIndex,
                isExited: isExited,
                cookedEvent: try cookedEvent?.domainValue,
                timers: timersByStep
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case recipeID
        case steps
        case currentIndex
        case isExited
        case cookedEvent
        case timers
    }
}

private struct CookingStepDTO: Codable {
    let text: String
    let ingredient: IngredientDTO?
    let timerSeconds: Int?
    let clipID: String?

    init(_ step: CookingStep) {
        text = step.text
        ingredient = step.ingredient.map(IngredientDTO.init)
        timerSeconds = step.timerSeconds
        clipID = step.clipID
    }

    var domainValue: CookingStep {
        CookingStep(
            text: text,
            ingredient: ingredient?.domainValue,
            timerSeconds: timerSeconds,
            clipID: clipID
        )
    }
}

private struct IngredientDTO: Codable {
    let name: String
    let quantity: String

    init(_ ingredient: Ingredient) {
        name = ingredient.name
        quantity = ingredient.quantity
    }

    var domainValue: Ingredient { Ingredient(name: name, quantity: quantity) }
}

private struct CookedEventDTO: Codable {
    let recipeID: String
    let outcome: String?
    let wasInferred: Bool

    init(_ event: CookedEvent) {
        recipeID = event.recipeID
        outcome = event.outcome?.rawValue
        wasInferred = event.wasInferred
    }

    var domainValue: CookedEvent {
        get throws {
            guard let rawOutcome = outcome else {
                return CookedEvent(recipeID: recipeID, outcome: nil, wasInferred: wasInferred)
            }
            guard let outcome = CookOutcome(rawValue: rawOutcome) else {
                throw SnapshotDecodingError.invalidValue
            }
            return CookedEvent(recipeID: recipeID, outcome: outcome, wasInferred: wasInferred)
        }
    }
}

private struct StepTimerDTO: Codable {
    let stepIndex: Int
    let startedAt: TimeInterval
    let duration: TimeInterval

    init(stepIndex: Int, timer: StepTimer) {
        self.stepIndex = stepIndex
        startedAt = timer.startedAt
        duration = timer.duration
    }
}
