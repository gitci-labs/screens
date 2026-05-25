import Foundation

public struct EditableSceneSetDocument: Equatable, Sendable {
    public var sceneSet: SceneSetManifest
    public var revision: Int

    public init(sceneSet: SceneSetManifest, revision: Int = 0) {
        self.sceneSet = sceneSet
        self.revision = revision
    }

    public func applying(_ edit: SceneSetEdit) throws -> EditableSceneSetDocument {
        var copy = self
        try copy.apply(edit)
        return copy
    }

    public mutating func apply(_ edit: SceneSetEdit) throws {
        switch edit {
        case let .setVariantProp(slotID, variantID, path, value):
            try updateVariant(slotID: slotID, variantID: variantID) { variant in
                variant.props = try variant.props.setting(value, atObjectPath: path)
            }
        case let .removeVariantProp(slotID, variantID, path):
            try updateVariant(slotID: slotID, variantID: variantID) { variant in
                variant.props = try variant.props.removingValue(atObjectPath: path)
            }
        case let .selectVariant(slotID, variantID):
            guard let slotIndex = sceneSet.slots.firstIndex(where: { $0.id == slotID }) else {
                throw EditableSceneSetError.unknownSlot(slotID)
            }
            guard sceneSet.slots[slotIndex].variants.contains(where: { $0.id == variantID }) else {
                throw EditableSceneSetError.unknownVariant(slotID: slotID, variantID: variantID)
            }
            sceneSet.slots[slotIndex].selectedVariant = variantID
        case let .setThemeOverride(name, value):
            var theme = sceneSet.theme ?? ThemeSelection(id: "gitci.theme.default", palette: nil, paletteMap: nil, overrides: nil)
            var overrides = theme.overrides ?? [:]
            overrides[name] = value
            theme.overrides = overrides
            sceneSet.theme = theme
        case let .removeThemeOverride(name):
            guard var theme = sceneSet.theme else {
                throw EditableSceneSetError.missingTheme
            }
            theme.overrides?.removeValue(forKey: name)
            sceneSet.theme = theme
        }
        revision += 1
    }

    private mutating func updateVariant(
        slotID: String,
        variantID: String,
        _ update: (inout SceneVariant) throws -> Void
    ) throws {
        guard let slotIndex = sceneSet.slots.firstIndex(where: { $0.id == slotID }) else {
            throw EditableSceneSetError.unknownSlot(slotID)
        }
        guard let variantIndex = sceneSet.slots[slotIndex].variants.firstIndex(where: { $0.id == variantID }) else {
            throw EditableSceneSetError.unknownVariant(slotID: slotID, variantID: variantID)
        }
        try update(&sceneSet.slots[slotIndex].variants[variantIndex])
    }
}

public enum SceneSetEdit: Equatable, Sendable {
    case setVariantProp(slotID: String, variantID: String, path: [String], value: JSONValue)
    case removeVariantProp(slotID: String, variantID: String, path: [String])
    case selectVariant(slotID: String, variantID: String)
    case setThemeOverride(name: String, value: String)
    case removeThemeOverride(name: String)
}

public struct SceneSetBindingPath: Equatable, Hashable, Codable, Sendable {
    public var slotID: String
    public var variantID: String
    public var propPath: [String]

    public init(slotID: String, variantID: String, propPath: [String]) {
        self.slotID = slotID
        self.variantID = variantID
        self.propPath = propPath
    }
}

public enum EditableSceneSetError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownSlot(String)
    case unknownVariant(slotID: String, variantID: String)
    case emptyPath
    case nonObjectPath([String])
    case missingTheme

    public var description: String {
        switch self {
        case let .unknownSlot(slotID):
            "Unknown scene slot: \(slotID)"
        case let .unknownVariant(slotID, variantID):
            "Unknown scene variant \(variantID) in slot \(slotID)"
        case .emptyPath:
            "Scene edit path must not be empty."
        case let .nonObjectPath(path):
            "Scene edit path does not resolve through JSON objects: \(path.joined(separator: "."))"
        case .missingTheme:
            "Scene set has no theme to edit."
        }
    }
}

public extension JSONValue {
    func setting(_ value: JSONValue, atObjectPath path: [String]) throws -> JSONValue {
        guard let key = path.first else {
            throw EditableSceneSetError.emptyPath
        }
        var object: [String: JSONValue]
        switch self {
        case let .object(existing):
            object = existing
        case .array, .string, .number, .bool, .null:
            throw EditableSceneSetError.nonObjectPath(path)
        }

        if path.count == 1 {
            object[key] = value
            return .object(object)
        }

        let remaining = Array(path.dropFirst())
        let child = object[key] ?? .object([:])
        object[key] = try child.setting(value, atObjectPath: remaining)
        return .object(object)
    }

    func removingValue(atObjectPath path: [String]) throws -> JSONValue {
        guard let key = path.first else {
            throw EditableSceneSetError.emptyPath
        }
        guard var object = objectValue else {
            throw EditableSceneSetError.nonObjectPath(path)
        }

        if path.count == 1 {
            object.removeValue(forKey: key)
            return .object(object)
        }

        let remaining = Array(path.dropFirst())
        guard let child = object[key] else {
            return .object(object)
        }
        object[key] = try child.removingValue(atObjectPath: remaining)
        return .object(object)
    }
}
