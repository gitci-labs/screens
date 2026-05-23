import Foundation

public enum SceneSpanCalculator {
    public static func requiredSpan(
        target: TargetProfile,
        constraints: SceneTemplateConstraints
    ) -> Int {
        guard let minAspectRatio = constraints.minAspectRatio else {
            return 1
        }

        let width = Double(target.width)
        let height = Double(target.height)
        let gap = Double(target.displayGapPx)
        let raw = ((minAspectRatio * height) + gap) / (width + gap)
        return max(1, Int(ceil(raw)))
    }

    public static func compositeWidth(
        target: TargetProfile,
        span: Int
    ) -> Int {
        max(1, span) * target.width + max(0, span - 1) * target.displayGapPx
    }

    public static func clipRect(
        target: TargetProfile,
        indexInSpan: Int
    ) -> ClipRect {
        let x = indexInSpan * (target.width + target.displayGapPx)
        return ClipRect(x: x, y: 0, width: target.width, height: target.height)
    }
}
