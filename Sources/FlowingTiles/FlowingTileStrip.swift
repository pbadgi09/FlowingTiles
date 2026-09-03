import SwiftUI

/// The horizontally-scrolling strip of "flowing" tiles — each tile is rotated
/// by a small angle and vertically offset so the row reads as a loose,
/// hand-placed stack. Tiles shrink when `isExpanded` is true.
public struct FlowingTileStrip: View {
    private let tiles: [FlowingTileModel]
    @Binding private var selectedID: String?
    private let isExpanded: Bool
    private let accent: Color
    private let fonts: FlowingFonts
    private let scrollProgress: CGFloat
    private let thumbnail: FlowingThumbnailProvider
    private let onTap: (String) -> Void

    public init(
        tiles: [FlowingTileModel],
        selectedID: Binding<String?>,
        isExpanded: Bool,
        accent: Color,
        fonts: FlowingFonts = .init(),
        scrollProgress: CGFloat = 0,
        thumbnail: @escaping FlowingThumbnailProvider,
        onTap: @escaping (String) -> Void
    ) {
        self.tiles = tiles
        self._selectedID = selectedID
        self.isExpanded = isExpanded
        self.accent = accent
        self.fonts = fonts
        self.scrollProgress = scrollProgress
        self.thumbnail = thumbnail
        self.onTap = onTap
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 10) {
                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    Button {
                        onTap(tile.id)
                    } label: {
                        FlowingTileView(
                            tile: tile,
                            index: index,
                            isSelected: selectedID == tile.id,
                            isExpanded: isExpanded,
                            accent: accent,
                            fonts: fonts,
                            scrollProgress: scrollProgress,
                            thumbnail: thumbnail
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            // Rotated tiles overhang their frames, so they need side room at rest;
            // as they straighten (scrollProgress → 1) that overhang disappears, so we
            // pull the strip closer to the screen edges.
            .padding(.horizontal, 24 - 18 * scrollProgress)
            .padding(.vertical, 28)
        }
        .frame(height: isExpanded ? 200 : 282)
        .padding(.top, isExpanded ? -28 : -48)
        // Whole-strip shrink as the grid scrolls under it (tiles + gaps together).
        .scaleEffect(1 - 0.2 * scrollProgress, anchor: .top)
    }
}

/// One flowing tile. Loads its cover via the thumbnail provider; when selected,
/// rotates through all `coverIDs` on a 10-second interval with a crossfade.
struct FlowingTileView: View {
    let tile: FlowingTileModel
    let index: Int
    let isSelected: Bool
    let isExpanded: Bool
    let accent: Color
    let fonts: FlowingFonts
    let scrollProgress: CGFloat
    let thumbnail: (String, CGSize) async -> UIImage?

    private let angles:   [Double]  = [-8, -3,  3,  8, -5,  2, -2,  5]
    private let yOffsets: [CGFloat] = [ 12,  4, -4, 10,  6,  0,  8, -2]

    // Straighten + flatten as the grid scrolls (scrollProgress 0 → 1).
    private var angle:   Double  { angles[index % angles.count] * (1 - scrollProgress) }
    private var yOffset: CGFloat { yOffsets[index % yOffsets.count] * (1 - scrollProgress) }

    private var tileWidth:  CGFloat { isExpanded ? 108 : 152 }
    private var tileHeight: CGFloat { isExpanded ? 152 : 214 }

    @State private var image: UIImage?
    @State private var rotationIndex = 0

    private var effectiveCoverID: String? {
        guard !tile.coverIDs.isEmpty else { return nil }
        if isSelected { return tile.coverIDs[rotationIndex % tile.coverIDs.count] }
        return tile.coverIDs.first
    }

    var body: some View {
        // Stable rectangular hit area — not rotated, so adjacent tiles never overlap.
        Color.clear
            .frame(width: tileWidth, height: tileHeight)
            .contentShape(Rectangle())
            .offset(y: yOffset)
            .overlay { visual }
            .task(id: effectiveCoverID) { await loadCover() }
            .task(id: isSelected) { await rotateCovers() }
    }

    private var visual: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(accent.opacity(0.25))
                }
            }
            .frame(width: tileWidth, height: tileHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if isSelected {
                accent.opacity(0.35)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .transition(.opacity)
            }

            Text(tile.title)
                .font(fonts.tileLabel(size: 17))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .frame(width: tileWidth, height: tileHeight)
        .overlay(alignment: .topLeading) {
            Text(tile.count.formatted())
                .font(fonts.badge(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
        .rotationEffect(.degrees(angle))
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        .allowsHitTesting(false)
    }

    private func loadCover() async {
        guard let id = effectiveCoverID else { return }
        let size = CGSize(width: 320, height: 440)
        let loaded = await thumbnail(id, size)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.5)) { image = loaded }
    }

    private func rotateCovers() async {
        guard isSelected, tile.coverIDs.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            rotationIndex += 1
        }
    }
}
