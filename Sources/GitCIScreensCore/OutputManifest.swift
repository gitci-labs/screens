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

    public init(
        id: String,
        width: Int,
        height: Int,
        displayGapPx: Int,
        appearance: Appearance,
        screenshots: [OutputManifestScreenshot]
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.displayGapPx = displayGapPx
        self.appearance = appearance
        self.screenshots = screenshots
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case width
        case height
        case displayGapPx
        case appearance
        case screenshots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.displayGapPx = try container.decodeIfPresent(Int.self, forKey: .displayGapPx) ?? 0
        self.appearance = try container.decode(Appearance.self, forKey: .appearance)
        self.screenshots = try container.decode([OutputManifestScreenshot].self, forKey: .screenshots)
    }
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

    public init(
        slotId: String,
        variantId: String,
        sceneTemplate: String,
        path: String,
        width: Int,
        height: Int,
        span: Int,
        spanIndex: Int,
        compositeWidth: Int,
        compositeHeight: Int,
        clip: ClipRect
    ) {
        self.slotId = slotId
        self.variantId = variantId
        self.sceneTemplate = sceneTemplate
        self.path = path
        self.width = width
        self.height = height
        self.span = span
        self.spanIndex = spanIndex
        self.compositeWidth = compositeWidth
        self.compositeHeight = compositeHeight
        self.clip = clip
    }

    private enum CodingKeys: String, CodingKey {
        case slotId
        case variantId
        case sceneTemplate
        case path
        case width
        case height
        case span
        case spanIndex
        case compositeWidth
        case compositeHeight
        case clip
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.slotId = try container.decode(String.self, forKey: .slotId)
        self.variantId = try container.decode(String.self, forKey: .variantId)
        self.sceneTemplate = try container.decode(String.self, forKey: .sceneTemplate)
        self.path = try container.decode(String.self, forKey: .path)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.span = try container.decode(Int.self, forKey: .span)
        self.spanIndex = try container.decodeIfPresent(Int.self, forKey: .spanIndex) ?? 0
        self.compositeWidth = try container.decodeIfPresent(Int.self, forKey: .compositeWidth) ?? width
        self.compositeHeight = try container.decodeIfPresent(Int.self, forKey: .compositeHeight) ?? height
        self.clip = try container.decodeIfPresent(ClipRect.self, forKey: .clip) ?? ClipRect(
            x: 0,
            y: 0,
            width: width,
            height: height
        )
    }
}
