import Foundation
import KartaCore
import KartaPresentation

/// The two non-overlapping halves of the Cookbook
/// (`CONTEXT.md` → Repertorio / Por probar). Which half is shown is a shell
/// preference, persisted by the shell, never part of the user snapshot
/// (ADR 0010).
enum CookbookHalf: String, CaseIterable {
    case repertoire
    case wantToTry

    /// The half the cookbook reopens on: the last one the user left. The
    /// first time it is Por probar, because nothing has been cooked yet.
    static func reopening(stored: String?) -> CookbookHalf {
        stored.flatMap(CookbookHalf.init(rawValue:)) ?? .wantToTry
    }

    func rows(in presentation: CookbookPresentation) -> [CookbookPresentation.Row] {
        switch self {
        case .repertoire: presentation.repertoire
        case .wantToTry: presentation.wantToTry
        }
    }

    func title(in presentation: CookbookPresentation) -> String {
        switch self {
        case .repertoire: "Your repertoire · \(presentation.repertoireCount)"
        case .wantToTry: "Want to try · \(presentation.wantToTryCount)"
        }
    }
}

/// Which surface an unsave came from. Decides where the Undo toast lives and
/// whether Undo reopens the reverse (`docs/design/karta-v1.md` → *Undo*:
/// from a reverse opened in the cookbook the reverse closes and Undo puts
/// the card back in its slot and opens the reverse again).
enum UnsaveOrigin {
    case feedReverse
    case cookbookGrid
    case cookbookReverse

    /// Only a reverse opened in the cookbook flips back into its grid slot.
    var closesReverse: Bool { self == .cookbookReverse }
    /// Only that same path reopens the reverse on Undo (not an Apertura).
    var undoReopensReverse: Bool { self == .cookbookReverse }
}

/// What the shell plays after sending `.saveRecipe`: the save animation or
/// the cookbook-full sheet. The view reads the result the store recorded —
/// it never inspects the cookbook itself to decide.
enum SaveTap {
    enum Effect: Equatable {
        case none
        case saved
        case cookbookFull
    }

    static func effect(of result: SaveResult?) -> Effect {
        switch result {
        case .saved, .alreadySaved: .saved
        case .blockedByCap: .cookbookFull
        case nil: .none
        }
    }
}

/// Where "Unlock unlimited cookbook" lands. The paywall itself is issue #14;
/// the sheet only opens this hook.
enum PaywallHook {
    static func open() {}
}
