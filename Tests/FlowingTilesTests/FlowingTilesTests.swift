import XCTest
@testable import FlowingTiles

final class FlowingTilesTests: XCTestCase {
    func testTileModelStoresCoverIDs() {
        let tile = FlowingTileModel(id: "a", title: "Recents", count: 12, coverIDs: ["1", "2", "3"])
        XCTAssertEqual(tile.coverIDs.count, 3)
        XCTAssertEqual(tile.title, "Recents")
        XCTAssertEqual(tile.count, 12)
    }

    func testGridModelEquatable() {
        let a = MediaGridModel(id: "x", durationText: "0:42", sizeText: "84 MB")
        let b = MediaGridModel(id: "x", durationText: "0:42", sizeText: "84 MB")
        XCTAssertEqual(a, b)
    }
}
