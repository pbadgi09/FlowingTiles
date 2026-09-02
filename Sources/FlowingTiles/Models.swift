import Foundation

/// A single tile in the flowing horizontal strip (e.g. a photo album).
///
/// The tile is intentionally data-agnostic: `coverIDs` are opaque identifiers
/// that the host app resolves into images via a `FlowingThumbnailProvider`.
/// A non-selected tile shows `coverIDs.first`; the selected tile rotates
/// through every id on a fixed interval.
public struct FlowingTileModel: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let count: Int
    public let coverIDs: [String]

    public init(id: String, title: String, count: Int, coverIDs: [String]) {
        self.id = id
        self.title = title
        self.count = count
        self.coverIDs = coverIDs
    }
}

/// A single cell in the vertical media grid (e.g. a video).
///
/// `id` is an opaque identifier resolved into a thumbnail image and, on
/// press-and-hold, into an `AVPlayer` for inline preview.
public struct MediaGridModel: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let durationText: String
    public let sizeText: String

    public init(id: String, durationText: String, sizeText: String) {
        self.id = id
        self.durationText = durationText
        self.sizeText = sizeText
    }
}
