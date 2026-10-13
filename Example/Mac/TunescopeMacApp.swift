import ITunesSearchKit
import ITunesSearchUI
import SwiftUI

/// Tunescope for the Mac: search the iTunes Store by category, browse artwork, open albums, podcasts, movies,
/// books and apps, and play previews.
@main
struct TunescopeMacApp: App {
    @State private var store: SearchStore
    @State private var player = PreviewPlayer()

    init() {
        _store = State(initialValue: SearchStore.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup("Tunescope") {
            MacRootView(store: store, player: player, scene: ScreenshotScene.current)
                // Screenshot scenes count and retry their image loads, to report ready once all are on screen.
                .artworkLoader(ScreenshotScene.current == nil ? ArtworkLoader.urlSession : ScreenshotScene.imageLoader)
                .modifier(MacWindowSize(isScreenshot: ScreenshotScene.current != nil))
        }
        .defaultSize(width: MacWindowSize.screenshotSize.width, height: MacWindowSize.screenshotSize.height)
        .windowResizability(ScreenshotScene.current == nil ? .contentMinSize : .contentSize)
        .commands {
            SidebarCommands()
        }
    }
}

/// A fixed size for screenshots, so every capture has the same frame; a minimum size otherwise.
struct MacWindowSize: ViewModifier {
    static let screenshotSize = CGSize(width: 1180, height: 760)
    let isScreenshot: Bool

    func body(content: Content) -> some View {
        if isScreenshot {
            content
                .frame(width: Self.screenshotSize.width, height: Self.screenshotSize.height)
                .preferredColorScheme(.dark)
                .background(ScreenshotWindow())
        } else {
            content
                .frame(minWidth: 820, minHeight: 540)
        }
    }
}

/// The sidebar of categories, and the results or a detail page next to it.
struct MacRootView: View {
    @Bindable var store: SearchStore
    let player: PreviewPlayer
    let scene: ScreenshotScene?

    @State private var path: [ITunesItem] = []
    @State private var openedFirstResult = false

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                Section("iTunes Store") {
                    ForEach(SearchCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage)
                            .tag(Optional(category))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            NavigationStack(path: $path) {
                ResultsView(store: store, scene: scene)
                    .navigationTitle(store.category.title)
                    .navigationSubtitle(subtitle)
                    .navigationDestination(for: ITunesItem.self) { item in
                        ItemDetailView(item: item, client: store.client, player: player, scene: scene)
                    }
            }
        }
        .searchable(text: $store.query, placement: .toolbar, prompt: Text(store.category.prompt))
        .tint(.pink)
        .task(id: store.key) {
            await store.search(debounce: scene == nil)
        }
        .onChange(of: store.category) {
            path.removeAll()
        }
        .onChange(of: store.phase) {
            openFirstResultIfNeeded()
        }
    }

    private var selection: Binding<SearchCategory?> {
        Binding(
            get: { store.category },
            set: { newValue in
                if let newValue {
                    store.category = newValue
                }
            }
        )
    }

    private var subtitle: String {
        guard store.phase == .loaded, !store.key.query.isEmpty else { return "" }
        let count = store.results.count
        return count == 1 ? "1 result" : "\(count) results"
    }

    /// Detail scenes open the first result once the search has loaded, as if it had been clicked.
    private func openFirstResultIfNeeded() {
        guard let scene, scene.opensFirstResult, !openedFirstResult, store.phase == .loaded,
              let first = store.results.first
        else { return }
        openedFirstResult = true
        path = [first]
    }
}
