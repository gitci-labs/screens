import Foundation

public struct TargetProfile: Codable, Equatable, Sendable {
    public var id: String
    public var platform: String
    public var family: String
    public var displayName: String
    public var width: Int
    public var height: Int
    public var acceptedSizes: [[Int]]
    public var orientation: String
    public var required: Bool
    public var displayGapPx: Int
    public var displayGapSource: String
    public var maxScreenshots: Int

    public init(
        id: String,
        platform: String = "ios",
        family: String = "iphone",
        displayName: String = "iPhone",
        width: Int,
        height: Int,
        acceptedSizes: [[Int]] = [],
        orientation: String = "portrait",
        required: Bool = true,
        displayGapPx: Int,
        displayGapSource: String = "empirical",
        maxScreenshots: Int
    ) {
        self.id = id
        self.platform = platform
        self.family = family
        self.displayName = displayName
        self.width = width
        self.height = height
        self.acceptedSizes = acceptedSizes
        self.orientation = orientation
        self.required = required
        self.displayGapPx = displayGapPx
        self.displayGapSource = displayGapSource
        self.maxScreenshots = maxScreenshots
    }
}

public struct SceneTemplateConstraints: Codable, Equatable, Sendable {
    public var minAspectRatio: Double?

    public init(minAspectRatio: Double? = nil) {
        self.minAspectRatio = minAspectRatio
    }
}

public struct ClipRect: Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum Appearance: String, Codable, Equatable, Sendable {
    case light
    case dark
    case automatic
}

public struct ProjectManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var sources: [ProjectSource]?
    public var defaultSceneSet: String?
    public var assetPolicy: AssetPolicy?
}

public struct ProjectSource: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var path: String?
    public var repo: String?
    public var version: String?
}

public struct AssetPolicy: Codable, Equatable, Sendable {
    public var allowRemoteAssets: Bool?
}

public struct PackManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var summary: String?
    public var descriptionMarkdown: String?
    public var version: String?
    public var author: PackAuthor?
    public var license: String?
    public var tags: [String]?
}

public struct PackAuthor: Codable, Equatable, Sendable {
    public var name: String
}

public struct SceneTemplateManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var pack: String?
    public var entry: String?
    public var `export`: String?
    public var tags: [String]?
    public var minAspectRatio: Double?
    public var supportedTargets: [String]?
    public var propsSchema: JSONValue?
    public var previewProps: JSONValue?
}

public struct ComponentManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var pack: String?
    public var entry: String?
    public var `export`: String?
    public var category: String?
    public var tags: [String]?
    public var propsSchema: JSONValue?
    public var previewProps: JSONValue?
}

public struct PaletteManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var colors: [String: [String]]
}

public struct ThemeManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var pack: String?
    public var vars: [String: [String: String]]
}

public struct TargetsManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var targets: [TargetProfile]
}

public struct SceneSetManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String?
    public var targets: [String]
    public var appearanceByTarget: [String: Appearance]?
    public var theme: ThemeSelection?
    public var slots: [SceneSlot]
}

public struct ThemeSelection: Codable, Equatable, Sendable {
    public var id: String
    public var palette: String?
    public var paletteMap: [String: Double]?
    public var overrides: [String: String]?
}

public struct SceneSlot: Codable, Equatable, Sendable {
    public var id: String
    public var label: String?
    public var selectedVariant: String?
    public var variants: [SceneVariant]
}

public struct SceneVariant: Codable, Equatable, Sendable {
    public var id: String
    public var sceneTemplate: String
    public var includeTargets: [String]?
    public var excludeTargets: [String]?
    public var props: JSONValue
}

public struct LoadedSceneSet: Equatable, Sendable {
    public var manifest: SceneSetManifest
    public var directoryURL: URL

    public var id: String { manifest.id }
}
