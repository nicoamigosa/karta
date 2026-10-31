import LinkPresentation
import SwiftUI
import UIKit
import KartaCore
import KartaPresentation

/// Where the shell learns the domain shared links live under (#157).
/// The real domain is still pending (#155): it arrives as the
/// `KartaShareBaseURL` Info.plist key, fed by the `KARTA_SHARE_BASE_URL`
/// build setting, which ships unset — so the app offers no share surface
/// at all. Debug runs may point it at a test domain through the
/// `KARTA_SHARE_BASE_URL` environment variable (ignored on Release).
enum ShareLinks {
    static var baseURL: URL? {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["KARTA_SHARE_BASE_URL"],
           let url = URL(string: value), url.host != nil {
            return url
        }
        #endif
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "KartaShareBaseURL"
        ) as? String,
              let url = URL(string: value), url.host != nil else { return nil }
        return url
    }

    /// The payload the contract builds for one recipe; nil while Share is
    /// switched off, so every caller (share card, cookbook menu) hides.
    @MainActor
    static func payload(
        for recipe: Recipe,
        in store: KartaStore
    ) -> SharePayload? {
        RecipeShare(baseURL: store.state.shareBaseURL).payload(for: recipe)
    }

    /// The recipe's Foto as a `UIImage` for the sheet header — the same
    /// resolution `RecipePhoto` applies to `local:` manifest keys.
    static func image(
        for reference: MediaReference,
        manifest: MediaAssetManifest
    ) -> UIImage? {
        guard let media = try? MediaResolver(manifest: manifest, baseURL: nil)
            .resolve(reference) else { return nil }
        switch media {
        case let .remote(url):
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        case let .bundle(resource):
            guard let bundleURL = Bundle.main.url(
                forResource: "KartaCore_KartaPresentation",
                withExtension: "bundle"
            ),
                let bundle = Bundle(url: bundleURL),
                let url = bundle.url(forResource: resource, withExtension: nil)
            else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
    }
}

/// The activity item that carries the link: hands the URL itself to the
/// target app and `LPLinkMetadata` to the sheet's header — the Foto as the
/// thumbnail and a two-line title, the name over
/// *Serves 4 · 35 min · Easy* (`share-sheet.png`; iOS adds the domain line).
final class ShareLinkItemSource: NSObject, UIActivityItemSource {
    let payload: SharePayload
    let image: UIImage?

    init(payload: SharePayload, image: UIImage?) {
        self.payload = payload
        self.image = image
        super.init()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        payload.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.url
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = payload.url
        metadata.url = payload.url
        // The two-line header (name over "Serves 4 · 35 min · Easy",
        // `share-sheet.png`): U+2028 survives where "\n" is collapsed.
        metadata.title = "\(payload.title)\u{2028}\(payload.subtitle)"
        if let image {
            metadata.imageProvider = NSItemProvider(object: image)
            metadata.iconProvider = metadata.imageProvider
        }
        return metadata
    }
}

/// The native share sheet for a `SharePayload`: the "<name> on Karta" line
/// plus the link, with the header above (`docs/design/karta-v1.md` → *Share*).
struct ShareSheetView: UIViewControllerRepresentable {
    let payload: SharePayload
    let image: UIImage?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [
                payload.text,
                ShareLinkItemSource(payload: payload, image: image)
            ],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
