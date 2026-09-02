# FlowingTiles

A small, **data-agnostic** SwiftUI component for iOS that renders a browser of
"flowing" tiles (a loose, rotated, hand-placed horizontal strip — e.g. photo
albums) above a vertical media grid that **expands in place** when a tile is
selected while the tiles shrink to a compact strip.

Built for photo/video browsers, but it knows nothing about Photos, PhotoKit, or
your data model — you feed it plain value types plus a couple of closures that
resolve opaque ids into images and preview players.

- **Flowing tile strip** — rotated / offset tiles, cover image, count badge.
- **Selected-tile cover rotation** — the selected tile cycles through its cover
  ids every 10 seconds with a crossfade.
- **Shrink / expand** — selecting a tile springs the strip smaller and reveals a
  3-column media grid; deselecting restores it.
- **Press-and-hold preview** — hold a grid cell to play a muted, looping preview;
  release to stop.

## Requirements

- iOS 17+
- Swift 5.9+

## Installation

Swift Package Manager. In Xcode: **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/pbadgi09/FlowingTiles.git
```

Pin to version `1.0.0` (or later).

Or in `Package.swift`:

```swift
.package(url: "https://github.com/pbadgi09/FlowingTiles.git", from: "1.0.0")
```

## Usage

```swift
import SwiftUI
import FlowingTiles

struct BrowserScreen: View {
    @State private var selectedID: String? = "recents"

    let tiles: [FlowingTileModel]
    let videos: [MediaGridModel]

    var body: some View {
        FlowingBrowser(
            tiles: tiles,
            selectedID: $selectedID,
            gridItems: videos,
            headerTitle: "Recents",
            accent: .blue,
            tileThumbnail: { id, size in await MyLibrary.image(id, size) },
            gridThumbnail: { id, size in await MyLibrary.image(id, size) },
            preview:       { id in await MyLibrary.player(id) },
            onGridTap:     { item in /* stubbed / navigate / compress */ },
            onSelectionChange: { newID in /* load that album's videos */ },
            emptyState: {
                Text("Pick an album")
            }
        )
    }
}
```

### Models

```swift
// A tile. `coverIDs` are opaque ids resolved by `tileThumbnail`.
FlowingTileModel(id: "recents", title: "Recents", count: 128, coverIDs: [...])

// A grid cell. `id` is resolved by `gridThumbnail` and `preview`.
MediaGridModel(id: assetID, durationText: "0:42", sizeText: "84 MB")
```

### Providers

```swift
typealias FlowingThumbnailProvider = (_ id: String, _ targetSize: CGSize) async -> UIImage?
typealias FlowingPreviewProvider   = @MainActor (_ id: String) async -> AVPlayer?
```

## Public API

- `FlowingBrowser` — the full composed browser (header + strip + expanding grid).
- `FlowingTileStrip` — just the horizontal flowing tiles.
- `MediaThumbGrid` — just the 3-column grid with hold-to-play.
- `FlowingTileModel`, `MediaGridModel` — the value types.

## License

MIT
