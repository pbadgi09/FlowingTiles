import SwiftUI

/// A drop-in browser that composes a big faded header title, the flowing tile
/// strip, and — once a tile is selected — a vertical media grid that expands in
/// place while the tiles shrink to a compact strip.
///
/// The view is data-agnostic: the host supplies tile/grid models plus closures
/// that resolve ids into thumbnails and preview players.
public struct FlowingBrowser<Empty: View>: View {
    private let tiles: [FlowingTileModel]
    @Binding private var selectedID: String?
    private let gridItems: [MediaGridModel]
    private let headerTitle: String
    private let accent: Color
    private let fonts: FlowingFonts
    private let tileThumbnail: FlowingThumbnailProvider
    private let gridThumbnail: FlowingThumbnailProvider
    private let preview: FlowingPreviewProvider
    private let sizeProvider: FlowingSizeProvider?
    private let zoomNamespace: Namespace.ID?
    private let onGridTap: (MediaGridModel) -> Void
    private let onSelectionChange: (String?) -> Void
    private let emptyState: () -> Empty

    public init(
        tiles: [FlowingTileModel],
        selectedID: Binding<String?>,
        gridItems: [MediaGridModel],
        headerTitle: String,
        accent: Color,
        fonts: FlowingFonts = .init(),
        tileThumbnail: @escaping FlowingThumbnailProvider,
        gridThumbnail: @escaping FlowingThumbnailProvider,
        preview: @escaping FlowingPreviewProvider,
        sizeProvider: FlowingSizeProvider? = nil,
        zoomNamespace: Namespace.ID? = nil,
        onGridTap: @escaping (MediaGridModel) -> Void,
        onSelectionChange: @escaping (String?) -> Void = { _ in },
        @ViewBuilder emptyState: @escaping () -> Empty
    ) {
        self.tiles = tiles
        self._selectedID = selectedID
        self.gridItems = gridItems
        self.headerTitle = headerTitle
        self.accent = accent
        self.fonts = fonts
        self.tileThumbnail = tileThumbnail
        self.gridThumbnail = gridThumbnail
        self.preview = preview
        self.sizeProvider = sizeProvider
        self.zoomNamespace = zoomNamespace
        self.onGridTap = onGridTap
        self.onSelectionChange = onSelectionChange
        self.emptyState = emptyState
    }

    private var isExpanded: Bool { selectedID != nil }

    @State private var scrollProgress: CGFloat = 0
    @State private var scrollBaseline: CGFloat?

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                if isExpanded {
                    MediaThumbGrid(
                        items: gridItems,
                        fonts: fonts,
                        thumbnail: gridThumbnail,
                        preview: preview,
                        sizeProvider: sizeProvider,
                        zoomNamespace: zoomNamespace,
                        onTap: onGridTap
                    )
                    .transition(.opacity)
                } else {
                    emptyState()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 40)
            .background {
                // Scroll probe: reports the content's top in the scroll's space so
                // the tiles can straighten/shrink as the grid scrolls under them.
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: geo.frame(in: .named(flowingScrollSpace)).minY)
                }
            }
        }
        .coordinateSpace(name: flowingScrollSpace)
        .onPreferenceChange(ScrollOffsetKey.self) { minY in
            // Baseline = the content's position at rest (top), captured once, so
            // progress is exactly 0 at the top regardless of the safe-area inset.
            let base = scrollBaseline ?? minY
            if scrollBaseline == nil { scrollBaseline = minY }
            scrollProgress = min(1, max(0, (base - minY) / flowingScrollThreshold))
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerTitle)
                .font(fonts.title(size: isExpanded ? 60 : 88))
                .foregroundStyle(accent.opacity(0.1))
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            FlowingTileStrip(
                tiles: tiles,
                selectedID: $selectedID,
                isExpanded: isExpanded,
                accent: accent,
                fonts: fonts,
                scrollProgress: scrollProgress,
                thumbnail: tileThumbnail,
                onTap: toggle
            )
        }
        .padding(.top, 8)
        .background {
            VStack(spacing: 0) {
                Color(uiColor: .systemBackground)
                if isExpanded {
                    LinearGradient(
                        colors: [Color(uiColor: .systemBackground), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func toggle(_ id: String) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedID = (selectedID == id) ? nil : id
        }
        onSelectionChange(selectedID)
    }
}

private let flowingScrollSpace = "flowingScroll"
private let flowingScrollThreshold: CGFloat = 140

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
