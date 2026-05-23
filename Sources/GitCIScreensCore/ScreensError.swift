import Foundation

public enum ScreensError: Error, CustomStringConvertible, Equatable {
    case missingScreensRoot(URL)
    case unsupportedSchema(file: String, version: Int)
    case noSceneSets(URL)
    case unknownSceneSet(String)
    case unknownTarget(String)
    case unknownSceneTemplate(String)
    case unknownTheme(String)
    case unknownPalette(String)
    case paletteHasNoColors(String, Appearance)
    case missingVariant(slotID: String, variantID: String)
    case noVariant(slotID: String)
    case missingRequiredProp(templateID: String, prop: String)
    case invalidTemplateEntry(String)
    case assetNotFound(String)
    case remoteAssetDisabled(String)
    case tooManyOutputs(targetID: String, count: Int, max: Int)
    case outputCollision(String)
    case unsupportedRenderer(String)
    case rendererFailed(Int32)
    case jsWorkspaceNotFound(URL)

    public var description: String {
        switch self {
        case let .missingScreensRoot(url):
            return "Could not find gitci/screens at or under \(url.path)."
        case let .unsupportedSchema(file, version):
            return "Unsupported schemaVersion \(version) in \(file)."
        case let .noSceneSets(url):
            return "No scene sets found under \(url.path)/scene-sets."
        case let .unknownSceneSet(id):
            return "Unknown scene set: \(id)."
        case let .unknownTarget(id):
            return "Unknown target: \(id)."
        case let .unknownSceneTemplate(id):
            return "Unknown scene template: \(id)."
        case let .unknownTheme(id):
            return "Unknown theme: \(id)."
        case let .unknownPalette(id):
            return "Unknown palette: \(id)."
        case let .paletteHasNoColors(id, appearance):
            return "Palette \(id) has no colors for \(appearance.rawValue)."
        case let .missingVariant(slotID, variantID):
            return "Slot \(slotID) does not contain variant \(variantID)."
        case let .noVariant(slotID):
            return "Slot \(slotID) does not contain any variants."
        case let .missingRequiredProp(templateID, prop):
            return "Scene template \(templateID) requires prop \(prop)."
        case let .invalidTemplateEntry(id):
            return "Scene template \(id) must declare both entry and export for rendering."
        case let .assetNotFound(path):
            return "Asset not found: \(path)."
        case let .remoteAssetDisabled(url):
            return "Remote assets are disabled, but found \(url)."
        case let .tooManyOutputs(targetID, count, max):
            return "Target \(targetID) would produce \(count) screenshots, above max \(max)."
        case let .outputCollision(path):
            return "Output filename collision: \(path)."
        case let .unsupportedRenderer(renderer):
            return "Unsupported renderer: \(renderer)."
        case let .rendererFailed(status):
            return "Renderer failed with exit status \(status)."
        case let .jsWorkspaceNotFound(start):
            return "Could not find js/package.json from \(start.path)."
        }
    }
}
