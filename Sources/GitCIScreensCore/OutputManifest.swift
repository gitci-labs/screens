import Foundation

public struct OutputManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var buildId: String
    public var sceneSet: RenderPlanSceneSet
    public var targets: [OutputManifestTarget]

    public init(plan: RenderPlan) {
        self.schemaVersion = 1
        self.buildId = plan.buildId
        self.sceneSet = plan.sceneSet
        self.targets = plan.targets.map { target in
            let frameStride = target.width + target.displayGapPx
            return OutputManifestTarget(
                id: target.id,
                width: target.width,
                height: target.height,
                displayGapPx: target.displayGapPx,
                appearance: target.appearance,
                screenshots: target.outputs.map { output in
                    OutputManifestScreenshot(
                        slotId: output.slotId,
                        variantId: output.variantId,
                        sceneTemplate: output.sceneTemplate,
                        path: output.outputPath,
                        width: output.clip.width,
                        height: output.clip.height,
                        span: output.span,
                        spanIndex: output.span > 1 ? output.clip.x / frameStride : 0,
                        compositeWidth: output.compositeWidth,
                        compositeHeight: output.compositeHeight,
                        clip: output.clip
                    )
                }
            )
        }
    }
}

public struct OutputManifestTarget: Codable, Equatable, Sendable {
    public var id: String
    public var width: Int
    public var height: Int
    public var displayGapPx: Int
    public var appearance: Appearance
    public var screenshots: [OutputManifestScreenshot]
}

public struct OutputManifestScreenshot: Codable, Equatable, Sendable {
    public var slotId: String
    public var variantId: String
    public var sceneTemplate: String
    public var path: String
    public var width: Int
    public var height: Int
    public var span: Int
    public var spanIndex: Int
    public var compositeWidth: Int
    public var compositeHeight: Int
    public var clip: ClipRect
}
