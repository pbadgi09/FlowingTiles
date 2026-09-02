import SwiftUI
import AVFoundation

/// A 3-column grid of square media thumbnails. Each cell shows a duration and
/// file-size overlay and plays a muted, looping preview while pressed-and-held.
public struct MediaThumbGrid: View {
    private let items: [MediaGridModel]
    private let thumbnail: FlowingThumbnailProvider
    private let preview: FlowingPreviewProvider
    private let onTap: (MediaGridModel) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    public init(
        items: [MediaGridModel],
        thumbnail: @escaping FlowingThumbnailProvider,
        preview: @escaping FlowingPreviewProvider,
        onTap: @escaping (MediaGridModel) -> Void
    ) {
        self.items = items
        self.thumbnail = thumbnail
        self.preview = preview
        self.onTap = onTap
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(items) { item in
                MediaThumbCell(
                    item: item,
                    thumbnail: thumbnail,
                    preview: preview,
                    onTap: { onTap(item) }
                )
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct MediaThumbCell: View {
    let item: MediaGridModel
    let thumbnail: FlowingThumbnailProvider
    let preview: FlowingPreviewProvider
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isPreviewing = false
    @State private var isHolding = false
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        // Square cell: Color.clear takes the column width and aspectRatio forces
        // a 1:1 box; content is layered in an overlay and clipped to that box.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    Rectangle().fill(Color.primary.opacity(0.08))

                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    }

                    if isPreviewing, let player {
                        PlayerLayerView(player: player)
                            .transition(.opacity)
                    }

                    overlays
                        .opacity(isPreviewing ? 0 : 1)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: item.id) { await loadThumbnail() }
            .onTapGesture { onTap() }
            .gesture(holdGesture)
            .onDisappear { endHold() }
    }

    private var overlays: some View {
        VStack {
            HStack {
                Spacer()
                Text(item.sizeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: Capsule())
            }
            Spacer()
            HStack {
                Image(systemName: "video.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(item.durationText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(6)
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }

    // Press-and-hold: begins after a short press, ends on release.
    private var holdGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, _) = value { beginHold() }
            }
            .onEnded { _ in endHold() }
    }

    private func loadThumbnail() async {
        let size = CGSize(width: 300, height: 300)
        let loaded = await thumbnail(item.id, size)
        guard !Task.isCancelled else { return }
        image = loaded
    }

    private func beginHold() {
        guard !isHolding else { return }
        isHolding = true
        Task { @MainActor in
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
