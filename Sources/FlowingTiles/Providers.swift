import UIKit
import AVFoundation

/// Resolves an opaque id (a tile cover id or a grid item id) into an image at
/// roughly the requested size. Called from a SwiftUI `.task`, so it may suspend.
public typealias FlowingThumbnailProvider = @Sendable (_ id: String, _ targetSize: CGSize) async -> UIImage?

/// Resolves a grid item id into a ready-to-play `AVPlayer` for the press-and-hold
/// preview. Return `nil` if a player can't be produced. The view mutes and loops
/// the player itself.
public typealias FlowingPreviewProvider = @MainActor @Sendable (_ id: String) async -> AVPlayer?

/// Resolves a grid item id into a short file-size label (e.g. "84 MB"), loaded
/// lazily per cell because computing it can be expensive. Return `nil` for none.
public typealias FlowingSizeProvider = @Sendable (_ id: String) async -> String?
