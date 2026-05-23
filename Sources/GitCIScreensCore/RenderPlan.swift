import Foundation

public struct RenderPlan: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var buildId: String
    public var rootDirectory: String
    public var outputDirectory: String
    public var assetBaseURL: String
    public var sceneSet: RenderPlanSceneSet
    public var targets: [RenderPlanTarget]
    public var registry: RenderPlanRegistry
}

public struct RenderPlanSceneSet: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
}

public struct RenderPlanRegistry: Codable, Equatable, Sendable {
    public var moduleURL: String
    public var sceneTemplates: [RenderPlanRegistryEntry] = []
}

public struct RenderPlanRegistryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var entry: String
    public var exportName: String
}

public struct RenderPlanTarget: Codable, Equatable, Sendable {
    public var id: String
    public var width: Int
    public var height: Int
    public var displayGapPx: Int
    public var appearance: Appearance
    public var themeVars: [String: String]
    public var outputs: [RenderPlanOutput]
}

public struct RenderPlanOutput: Codable, Equatable, Sendable {
    public var slotId: String
    public var variantId: String
    public var sceneTemplate: String
    public var span: Int
    public var compositeWidth: Int
    public var compositeHeight: Int
    public var clip: ClipRect
    public var outputPath: String
    public var props: JSONValue
}
