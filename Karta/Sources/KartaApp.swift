import SwiftUI
import KartaCore
import KartaPresentation

@main
struct KartaApp: App {
    @State private var store = KartaStore(state: KartaState(
        safetyProfile: SafetyProfile(intolerances: [])
    ))

    var body: some Scene {
        WindowGroup {
            FeedScreen(store: store)
        }
    }
}

private struct SystemClock: KartaClock {
    var now: Date { Date() }
}

struct FeedScreen: View {
    let store: KartaStore

    @State private var recipes: [Recipe] = []
    @State private var manifest = MediaAssetManifest([:])
    @State private var isLoaded = false
    @State private var loadError: String?

    private let ink = Color(red: 0.19, green: 0.22, blue: 0.17)
    private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if !isLoaded {
                ProgressView("Loading recipes")
            } else if let feed = store.feed(recipes: recipes, views: [], recentWindow: 7 * 24 * 60 * 60, clock: SystemClock()) {
                if feed.isEmpty {
                    ContentUnavailableView("No compatible recipes", systemImage: "fork.knife", description: Text("There are no recipes compatible with your intolerances."))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            header
                            ForEach(Array(feed.items.enumerated()), id: \.offset) { indexed in
                                switch indexed.element {
                                case let .new(recipe):
                                    card(for: recipe)
                                case .frontier:
                                    frontier
                                case let .alreadySeen(recipe):
                                    card(for: recipe, alreadySeen: true)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    }
                }
            } else {
                onboarding
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(paper)
        .foregroundStyle(ink)
        .task {
            do {
                let seed = SeedResourceAdapter()
                recipes = try seed.loadRecipes()
                manifest = try seed.loadMediaManifest()
                isLoaded = true
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KARTA")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.secondary)
            Text("What sounds good today?")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private var frontier: some View {
        HStack(spacing: 12) {
            Rectangle().frame(height: 1)
            Text("YOU'RE UP TO DATE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .fixedSize()
            Rectangle().frame(height: 1)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func card(for recipe: Recipe, alreadySeen: Bool = false) -> some View {
        if let presentation = store.state.onboarding.cardPresentation(for: recipe) {
            VStack(alignment: .leading, spacing: 0) {
                RecipePhoto(reference: recipe.heroPhoto, manifest: manifest)
                    .frame(height: 250)
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    if alreadySeen {
                        Text("ALREADY SEEN")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                    }
                    Text(presentation.name)
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(presentation.durationLabel)
                        Text("·")
                        Text(presentation.difficultyLabel)
                        Text("·")
                        Text(presentation.servingsLabel)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
        }
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("KARTA")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(4)
            if case .unanswered = store.state.onboarding.intoleranceAnswer {
                Text("Do you avoid dairy?")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                Text("If you do, recipes containing dairy won't appear in your feed. Other intolerances are not supported yet.")
                Button("Yes, avoid dairy") {
                    store.send(.onboarding(.answerIntolerances([.dairy])))
                }
                Button("No dairy intolerance") {
                    store.send(.onboarding(.answerIntolerances([])))
                }
            } else {
                Text("How many in your household?")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                Text("We'll put recipes that fit your household first, without hiding the rest.")
                ForEach(1...6, id: \.self) { size in
                    Button("\(size) \(size == 1 ? "person" : "people")") {
                        store.send(.onboarding(.setHouseholdSize(size)))
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(28)
        .buttonStyle(.borderedProminent)
        .tint(ink)
    }
}

private struct RecipePhoto: View {
    let reference: MediaReference
    let manifest: MediaAssetManifest

    var body: some View {
        Group {
            if let media = try? MediaResolver(manifest: manifest, baseURL: nil).resolve(reference) {
                switch media {
                case let .remote(url):
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFill()
                        case .empty:
                            ProgressView()
                        case .failure:
                            unavailable
                        @unknown default:
                            unavailable
                        }
                    }
                case let .bundle(resource):
                    if let bundleURL = Bundle.main.url(forResource: "KartaCore_KartaPresentation", withExtension: "bundle"),
                       let bundle = Bundle(url: bundleURL),
                       let url = bundle.url(forResource: resource, withExtension: nil),
                       let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        unavailable
                    }
                }
            } else {
                unavailable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var unavailable: some View {
        ContentUnavailableView("Photo unavailable", systemImage: "photo")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
    }
}
