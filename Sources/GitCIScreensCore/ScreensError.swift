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
    case projectSourceMissingPath(String)
    case templateSourceNotFound(id: String, path: String)
    case unknownVariantGroup(sceneSetID: String, groupID: String)
    case missingVariant(slotID: String, variantID: String)
    case noVariant(slotID: String)
    case missingRequiredProp(templateID: String, prop: String)
    case unsupportedTemplateTarget(templateID: String, targetID: String)
    case invalidTemplateEntry(String)
    case assetNotFound(String)
    case remoteAssetDisabled(String)
    case missingLocalizedString(localeID: String, key: String)
    case noOutputs(targetID: String)
    case tooManyOutputs(targetID: String, count: Int, max: Int)
    case outputCollision(String)
    case unsupportedRenderer(String)
    case rendererFailed(Int32)
    case jsWorkspaceNotFound(URL)
    case rendererNotBuilt(String)

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
        case let .projectSourceMissingPath(id):
            return "Project source \(id) is local but has no path."
        case let .templateSourceNotFound(id, path):
            return "Project source \(id) does not contain a packs directory at \(path)."
        case let .unknownVariantGroup(sceneSetID, groupID):
            return "Scene set \(sceneSetID) does not contain variant group \(groupID)."
        case let .missingVariant(slotID, variantID):
            return "Slot \(slotID) does not contain variant \(variantID)."
        case let .noVariant(slotID):
            return "Slot \(slotID) does not contain any variants."
        case let .missingRequiredProp(templateID, prop):
            return "Scene template \(templateID) requires prop \(prop)."
        case let .unsupportedTemplateTarget(templateID, targetID):
            return "Scene template \(templateID) does not support target \(targetID)."
        case let .invalidTemplateEntry(id):
            return "Scene template \(id) must declare both entry and export for rendering."
        case let .assetNotFound(path):
            return "Asset not found: \(path)."
        case let .remoteAssetDisabled(url):
            return "Remote assets are disabled, but found \(url)."
        case let .missingLocalizedString(localeID, key):
            return "Locale \(localeID) is missing localized string \(key)."
        case let .noOutputs(targetID):
            return "Target \(targetID) would not produce any screenshots."
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
        case let .rendererNotBuilt(path):
            return "Renderer build artifact not found: \(path). Run `cd js && pnpm build`."
        }
    }
}
