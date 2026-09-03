import SwiftUI
import AVFoundation

/// A 3-column grid of square media thumbnails. Each cell shows a duration and
/// (lazily-loaded) file-size badge, and plays a muted, looping preview while
/// pressed-and-held.
///
/// Cell size is computed from the measured grid width and applied as a fixed
/// square frame. This is deliberate: a per-cell `GeometryReader { }.aspectRatio()`
/// can collapse to zero height when it's a direct `LazyVGrid` child (leaving the
/// grid invisible and unscrollable), so we size cells deterministically instead.
public struct MediaThumbGrid: View {
    private let items: [MediaGridModel]
    private let fonts: FlowingFonts
    private let accent: Color
    private let thumbnail: FlowingThumbnailProvider
    private let preview: FlowingPreviewProvider
    private let sizeProvider: FlowingSizeProvider?
    private let zoomNamespace: Namespace.ID?
    private let selection: Binding<Set<String>>?
    private let isSelecting: Bool
    private let selectionLimit: Int?
    private let onSelectionLimitReached: (() -> Void)?
    private let onTap: (MediaGridModel) -> Void

    private static let spacing: CGFloat = 3
    private static let columnCount = 3

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: spacing),
        count: columnCount
    )

    @State private var cellSide: CGFloat = 0

    public init(
        items: [MediaGridModel],
        fonts: FlowingFonts = .init(),
        accent: Color = .accentColor,
        thumbnail: @escaping FlowingThumbnailProvider,
        preview: @escaping FlowingPreviewProvider,
        sizeProvider: FlowingSizeProvider? = nil,
        zoomNamespace: Namespace.ID? = nil,
        selection: Binding<Set<String>>? = nil,
        isSelecting: Bool = false,
        selectionLimit: Int? = nil,
        onSelectionLimitReached: (() -> Void)? = nil,
        onTap: @escaping (MediaGridModel) -> Void
    ) {
        self.items = items
        self.fonts = fonts
        self.accent = accent
        self.thumbnail = thumbnail
        self.preview = preview
        self.sizeProvider = sizeProvider
        self.zoomNamespace = zoomNamespace
        self.selection = selection
        self.isSelecting = isSelecting
        self.selectionLimit = selectionLimit
        self.onSelectionLimitReached = onSelectionLimitReached
        self.onTap = onTap
    }

    /// Toggle selection (respecting the cap) when selecting; otherwise the normal tap.
    private func handleTap(_ item: MediaGridModel) {
        guard isSelecting, let selection else { onTap(item); return }
        var set = selection.wrappedValue
        if set.contains(item.id) {
            set.remove(item.id)
        } else if let limit = selectionLimit, set.count >= limit {
            onSelectionLimitReached?()
            return
        } else {
            set.insert(item.id)
        }
        selection.wrappedValue = set
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MediaThumbCell(
                    item: item,
                    side: cellSide,
                    fonts: fonts,
                    accent: accent,
                    isSelecting: isSelecting,
                    isSelected: selection?.wrappedValue.contains(item.id) ?? false,
                    thumbnail: thumbnail,
                    preview: preview,
                    sizeProvider: sizeProvider,
                    onTap: { handleTap(item) }
                )
                .accessibilityIdentifier("videoCell_\(index)")
                .modifier(ZoomSourceModifier(id: item.id, namespace: zoomNamespace))
            }
        }
        .padding(.horizontal, Self.spacing)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: GridWidthKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(GridWidthKey.self) { width in
            let gaps = Self.spacing * CGFloat(Self.columnCount - 1)
            let insets = Self.spacing * 2
            cellSide = max(0, (width - insets - gaps) / CGFloat(Self.columnCount))
        }
    }
}

private struct GridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Marks a cell as a zoom-transition source (iOS 18+) so a pushed destination can
/// zoom from it. No-op when no namespace is supplied or on older systems.
private struct ZoomSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace, #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct MediaThumbCell: View {
    // Closures are stored as plain (non-Sendable) function types — they're only
    // ever invoked from this view's own `.task`/gesture handlers, so Sendability
    // isn't needed and this avoids spurious data-race warnings at the call site.
    let item: MediaGridModel
    let side: CGFloat
    let fonts: FlowingFonts
    let accent: Color
    let isSelecting: Bool
    let isSelected: Bool
    let thumbnail: (String, CGSize) async -> UIImage?
    let preview: @MainActor (String) async -> AVPlayer?
    let sizeProvider: ((String) async -> String?)?
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var sizeText: String?
    @State private var player: AVPlayer?
    @State private var isPreviewing = false
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?
    @State private var endObserver: NSObjectProtocol?

    private static let holdDelay: Duration = .milliseconds(180)
    private static let cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.08))

            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }

            if isPreviewing, let player {
                PlayerLayerView(player: player)
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .overlay(alignment: .bottomLeading) {
            durationBadge.opacity(isPreviewing ? 0 : 1)
        }
        .overlay(alignment: .bottomTrailing) {
            sizeBadge.opacity(isPreviewing ? 0 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .overlay { if isSelecting { selectionOverlay } }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .task(id: item.id) {
            async let thumb: Void = loadThumbnail()
            async let size: Void = loadSize()
            _ = await (thumb, size)
        }
        .onTapGesture { onTap() }
        // Scroll-friendly press-and-hold: `onLongPressGesture` with a
        // `maximumDistance` yields to the enclosing ScrollView as soon as the
        // finger moves, so a normal vertical drag scrolls instead of being
        // captured. Preview only starts after the finger stays put for
        // `holdDelay`, so a quick scroll never flashes a preview.
        .onLongPressGesture(minimumDuration: 3600, maximumDistance: 12) {
            // Not used — the long press never "completes"; we drive start/stop
            // from the pressing state below.
        } onPressingChanged: { pressing in
            guard !isSelecting else { return }   // no hold-to-preview while selecting
            if pressing { scheduleHold() } else { cancelHold() }
        }
        .onDisappear { cancelHold() }
    }

    /// Checkmark + accent wash shown over each cell while in selection mode.
    private var selectionOverlay: some View {
        ZStack(alignment: .topTrailing) {
            if isSelected {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(accent.opacity(0.28))
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(accent, lineWidth: 3)
            }
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(isSelected ? .black : .white,
                                 isSelected ? accent : .white.opacity(0.7))
                .padding(6)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var durationBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "video.fill")
                .font(.system(size: 9, weight: .bold))
            Text(item.durationText)
                .font(fonts.metadata(size: 10))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(5)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }

    @ViewBuilder
    private var sizeBadge: some View {
        if let sizeText {
            Text(sizeText)
                .font(fonts.metadata(size: 10))
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(5)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
    }

    // MARK: - Loading

    private func loadThumbnail() async {
        let dimension = max(side, 150) * 2 // retina-crisp for the cell width
        let size = CGSize(width: dimension, height: dimension)
        let loaded = await thumbnail(item.id, size)
        guard !Task.isCancelled else { return }
        image = loaded
    }

    private func loadSize() async {
        guard let sizeProvider else { return }
        let text = await sizeProvider(item.id)
        guard !Task.isCancelled else { return }
        sizeText = text
    }

    // MARK: - Hold-to-play

    private func scheduleHold() {
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: Self.holdDelay)
            guard !Task.isCancelled else { return }
            await beginHold()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        endHold()
    }

    private func beginHold() async {
        guard !isHolding else { return }
        isHolding = true
        guard let p = await preview(item.id), isHolding else { return }
        p.isMuted = true
        p.actionAtItemEnd = .none
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        player = p
        withAnimation(.easeInOut(duration: 0.2)) { isPreviewing = true }
        p.play()
    }

    private func endHold() {
        isHolding = false
        player?.pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        withAnimation(.easeInOut(duration: 0.2)) { isPreviewing = false }
        player = nil
    }
}
