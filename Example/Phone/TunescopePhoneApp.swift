import ITunesSearchKit
import ITunesSearchUI
import SwiftUI

/// Tunescope for iPhone: the same search as the Mac app, with categories above the results.
@main
struct TunescopePhoneApp: App {
    @State private var store: SearchStore
    @State private var player = PreviewPlayer()

    init() {
        _store = State(initialValue: SearchStore.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView(store: store, player: player, scene: ScreenshotScene.current)
                // Screenshot scenes count and retry their image loads, to report ready once all are on screen.
                .artworkLoader(ScreenshotScene.current == nil ? ArtworkLoader.urlSession : ScreenshotScene.imageLoader)
                .preferredColorScheme(.dark)
                .tint(.pink)
        }
    }
}

/// Search with category chips, a grid of results and detail pages.
struct PhoneRootView: View {
    @Bindable var store: SearchStore
    let player: PreviewPlayer
    let scene: ScreenshotScene?

    @State private var path: [ITunesItem] = []
    @State private var openedFirstResult = false

    var body: some View {
        NavigationStack(path: $path) {
            ResultsView(store: store, scene: scene)
                .safeAreaInset(edge: .top, spacing: 0) {
                    CategoryChips(selection: $store.category)
                }
                // Inline titles: iOS 26 can drop a large title while a scroll view settles under it.
                .navigationTitle("Tunescope")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .searchable(
                    text: $store.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(store.category.prompt)
                )
                .navigationDestination(for: ITunesItem.self) { item in
                    ItemDetailView(item: item, client: store.client, player: player, scene: scene)
                }
        }
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

    /// Detail scenes open the first result once the search has loaded, as if it had been tapped.
    private func openFirstResultIfNeeded() {
        guard let scene, scene.opensFirstResult, !openedFirstResult, store.phase == .loaded,
              let first = store.results.first
        else { return }
        openedFirstResult = true
        print("Screenshot scene \(scene.rawValue): opening \(first.name) (\(store.results.count) results)")
        path = [first]
    }
}

/// The categories as a row of capsules that scrolls sideways.
struct CategoryChips: View {
    @Binding var selection: SearchCategory

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SearchCategory.allCases) { category in
                    let isSelected = category == selection
                    Button {
                        selection = category
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(
                                Capsule().fill(isSelected ? Color.pink : Color.secondary.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Layout.pagePadding)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }
}
