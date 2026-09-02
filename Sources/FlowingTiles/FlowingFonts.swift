import SwiftUI

/// Optional custom font names (PostScript names) for the text the package
/// renders. When a name is `nil` the package falls back to a system font at the
/// same size, so it stays usable without any font setup. The package owns the
/// sizes; the host only supplies the font family per role.
public struct FlowingFonts: Sendable, Equatable {
    public var titleFontName: String?
    public var tileLabelFontName: String?
    public var badgeFontName: String?
    public var metadataFontName: String?

    public init(
        titleFontName: String? = nil,
        tileLabelFontName: String? = nil,
        badgeFontName: String? = nil,
        metadataFontName: String? = nil
    ) {
        self.titleFontName = titleFontName
        self.tileLabelFontName = tileLabelFontName
        self.badgeFontName = badgeFontName
        self.metadataFontName = metadataFontName
    }

    func title(size: CGFloat) -> Font {
        titleFontName.map { .custom($0, fixedSize: size) }
            ?? .system(size: size, weight: .black, design: .rounded)
    }

    func tileLabel(size: CGFloat) -> Font {
        tileLabelFontName.map { .custom($0, fixedSize: size) }
            ?? .system(size: size, weight: .semibold, design: .rounded)
    }

    func badge(size: CGFloat) -> Font {
        badgeFontName.map { .custom($0, fixedSize: size) }
            ?? .system(size: size, weight: .medium, design: .rounded)
    }

    func metadata(size: CGFloat) -> Font {
        metadataFontName.map { .custom($0, fixedSize: size) }
            ?? .system(size: size, weight: .semibold, design: .monospaced)
    }
}
