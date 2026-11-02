import Foundation
import KartaCore

extension KartaState {
    /// Only committed answers are persisted. Closing the first-run panel
    /// cannot save its draft. Legacy payloads pass through without interpretation.
    public var userSnapshot: UserSnapshot {
        let profile = onboarding.profile.map {
            OnboardingProfile(intolerances: safetyProfile.intolerances, householdSize: $0.householdSize)
        }
        return UserSnapshot(
            profile: profile, cookbook: cookbook, viewHistory: viewHistory,
            cookHistory: cookHistory, legacyPayload: legacyPayload,
            hasShownFullTour: onboarding.hasShownFullTour, cookingSession: session,
            hasShownAlarmPermissionSheet: hasShownAlarmPermissionSheet,
            hasShownSaveToast: hasShownSaveToast, shareCardHistory: shareCardHistory)
    }

    /// Storage calls UserSnapshot.restore first, including its session expiry
    /// policy when appropriate. Navigation and unfinished answers start fresh.
    public init(snapshot: UserSnapshot, shareBaseURL: URL? = nil) {
        let answer: IntoleranceAnswer = snapshot.profile.map { .answered($0.intolerances) } ?? .unanswered
        self.init(
            cookbook: snapshot.cookbook,
            onboarding: OnboardingState(
                intoleranceAnswer: answer, householdSize: snapshot.profile?.householdSize,
                hasShownFullTour: snapshot.hasShownFullTour),
            viewHistory: snapshot.viewHistory, cookHistory: snapshot.cookHistory,
            session: snapshot.cookingSession,
            safetyProfile: SafetyProfile(intolerances: snapshot.profile?.intolerances ?? Set(Allergen.allCases)),
            hasShownAlarmPermissionSheet: snapshot.hasShownAlarmPermissionSheet,
            hasShownSaveToast: snapshot.hasShownSaveToast, shareBaseURL: shareBaseURL,
            shareCardHistory: snapshot.shareCardHistory)
        legacyPayload = snapshot.legacyPayload
    }
}
