import Foundation

public struct SceneTemplateRecord: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var constraints: SceneTemplateConstraints
    public var requiredProps: [String]
    public var pack: String?
    public var tags: [String]?
    public var supportedTargets: [String]?
    public var entry: String?
    public var exportName: String?
    public var resolvedEntry: String?
}

public enum BuiltInCatalog {
    public static let targetProfiles: [String: TargetProfile] = {
        let iphone = TargetProfile(
            id: "appstore.iphone.6_9.portrait",
            platform: "ios",
            family: "iphone",
            displayName: "iPhone 6.9-inch Portrait",
            width: 1320,
            height: 2868,
            acceptedSizes: [
                [1260, 2736],
                [1290, 2796],
                [1320, 2868]
            ],
            orientation: "portrait",
            required: true,
            displayGapPx: 80,
            displayGapSource: "empirical",
            maxScreenshots: 10
        )
        let ipad = TargetProfile(
            id: "appstore.ipad.13.portrait",
            platform: "ios",
            family: "ipad",
            displayName: "iPad 13-inch Portrait",
            width: 2064,
            height: 2752,
            acceptedSizes: [
                [2064, 2752],
                [2048, 2732]
            ],
            orientation: "portrait",
            required: true,
            displayGapPx: 96,
            displayGapSource: "empirical",
            maxScreenshots: 10
        )
        let mac = TargetProfile(
            id: "appstore.mac.16_10",
            platform: "macos",
            family: "mac",
            displayName: "Mac 16:10",
            width: 2880,
            height: 1800,
            acceptedSizes: [
                [1280, 800],
                [1440, 900],
                [2560, 1600],
                [2880, 1800]
            ],
            orientation: "landscape",
            required: true,
            displayGapPx: 96,
            displayGapSource: "empirical",
            maxScreenshots: 10
        )
        return [
            iphone.id: iphone,
            ipad.id: ipad,
            mac.id: mac
        ]
    }()

    public static let sceneTemplates: [String: SceneTemplateRecord] = {
        let hero = SceneTemplateRecord(
            id: "gitci.core.hero-device",
            name: "Hero Device",
            constraints: SceneTemplateConstraints(minAspectRatio: 0.42),
            requiredProps: ["headline", "screenshot"],
            pack: "gitci.core",
            tags: ["hero", "device", "headline"],
            supportedTargets: ["appstore.iphone.*", "appstore.ipad.*", "appstore.mac.*"],
            entry: "@gitci/screens-templates-core",
            exportName: "HeroDeviceScene",
            resolvedEntry: "@gitci/screens-templates-core"
        )
        let featureCloseup = SceneTemplateRecord(
            id: "gitci.core.feature-closeup",
            name: "Feature Closeup",
            constraints: SceneTemplateConstraints(minAspectRatio: 0.42),
            requiredProps: ["headline", "screenshot"],
            pack: "gitci.core",
            tags: ["feature", "device", "detail"],
            supportedTargets: ["appstore.iphone.*", "appstore.ipad.*", "appstore.mac.*"],
            entry: "@gitci/screens-templates-core",
            exportName: "FeatureCloseupScene",
            resolvedEntry: "@gitci/screens-templates-core"
        )
        return [
            hero.id: hero,
            featureCloseup.id: featureCloseup
        ]
    }()

    public static func themeVars(themeID: String?, appearance: Appearance) throws -> [String: String] {
        let resolvedAppearance = appearance == .automatic ? Appearance.light : appearance
        guard themeID == nil || themeID == "gitci.theme.clean-editorial" else {
            throw ScreensError.unknownTheme(themeID ?? "")
        }

        switch resolvedAppearance {
        case .light, .automatic:
            return [
                "--gitci-color-bg": "#f8fafc",
                "--gitci-color-fg": "#111827",
                "--gitci-color-muted": "#64748b",
                "--gitci-color-primary": "#2563eb",
                "--gitci-color-secondary": "#0f766e",
                "--gitci-font-title": "ui-rounded, system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
                "--gitci-font-headline": "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
                "--gitci-font-body": "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
                "--gitci-radius-card": "36px"
            ]
        case .dark:
            return [
                "--gitci-color-bg": "#0f172a",
                "--gitci-color-fg": "#f8fafc",
                "--gitci-color-muted": "#cbd5e1",
                "--gitci-color-primary": "#60a5fa",
                "--gitci-color-secondary": "#5eead4",
                "--gitci-font-title": "ui-rounded, system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
                "--gitci-font-headline": "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
                "--gitci-font-body": "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
                "--gitci-radius-card": "36px"
            ]
        }
    }
}
