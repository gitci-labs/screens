import XCTest
@testable import GitCIScreensCore

final class SceneSpanCalculatorTests: XCTestCase {
    func testSingleSpanWhenAspectFits() {
        let target = TargetProfile(
            id: "iphone",
            width: 1320,
            height: 2868,
            displayGapPx: 80,
            maxScreenshots: 10
        )
        let span = SceneSpanCalculator.requiredSpan(
            target: target,
            constraints: .init(minAspectRatio: 0.42)
        )
        XCTAssertEqual(span, 1)
    }

    func testTwoSpanWhenSceneRequiresWideAspect() {
        let target = TargetProfile(
            id: "iphone",
            width: 1320,
            height: 2868,
            displayGapPx: 80,
            maxScreenshots: 10
        )
        let span = SceneSpanCalculator.requiredSpan(
            target: target,
            constraints: .init(minAspectRatio: 0.75)
        )
        XCTAssertEqual(span, 2)
    }

    func testClipRectsSkipDisplayGap() {
        let target = TargetProfile(
            id: "iphone",
            width: 1320,
            height: 2868,
            displayGapPx: 80,
            maxScreenshots: 10
        )
        XCTAssertEqual(
            SceneSpanCalculator.clipRect(target: target, indexInSpan: 1),
            ClipRect(x: 1400, y: 0, width: 1320, height: 2868)
        )
    }
}
