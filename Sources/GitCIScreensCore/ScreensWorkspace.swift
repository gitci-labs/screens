import Foundation

public struct ScreensWorkspace: Sendable {
    public var rootURL: URL
    public var project: ProjectManifest?
    public var sceneSets: [LoadedSceneSet]
    public var packs: [PackManifest]
    public var targets: [String: TargetProfile]
    public var sceneTemplates: [String: SceneTemplateRecord]
    public var sceneSetTemplates: [String: SceneSetTemplateManifest]
    public var components: [String: ComponentManifest]
    public var palettes: [String: PaletteManifest]
    public var themes: [String: ThemeManifest]

    public static func load(root: URL) throws -> ScreensWorkspace {
        let rootURL = root.standardizedFileURL
        let project = try loadProjectManifest(rootURL: rootURL)
        let sceneSets = try loadSceneSets(rootURL: rootURL)
        if sceneSets.isEmpty {
            throw ScreensError.noSceneSets(rootURL)
        }
        let catalog = try loadTemplateCatalog(rootURL: rootURL, project: project)

        return ScreensWorkspace(
            rootURL: rootURL,
            project: project,
            sceneSets: sceneSets,
            packs: catalog.packs,
            targets: catalog.targets,
            sceneTemplates: catalog.sceneTemplates,
            sceneSetTemplates: catalog.sceneSetTemplates,
            components: catalog.components,
            palettes: catalog.palettes,
            themes: catalog.themes
        )
    }

    public func resolveSceneSet(id: String?) throws -> LoadedSceneSet {
        let requestedID = id ?? project?.defaultSceneSet ?? sceneSets.first?.id
        guard let requestedID else {
            throw ScreensError.noSceneSets(rootURL)
        }
        guard let sceneSet = sceneSets.first(where: { $0.id == requestedID }) else {
            throw ScreensError.unknownSceneSet(requestedID)
        }
        return sceneSet
    }

    private static func loadProjectManifest(rootURL: URL) throws -> ProjectManifest? {
        let url = rootURL.appendingPathComponent("project.gitci.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let manifest = try JSONDecoder.gitci.decode(ProjectManifest.self, from: Data(contentsOf: url))
        guard manifest.schemaVersion == 1 else {
            throw ScreensError.unsupportedSchema(file: url.path, version: manifest.schemaVersion)
        }
        return manifest
    }

    private static func loadSceneSets(rootURL: URL) throws -> [LoadedSceneSet] {
        let sceneSetsURL = rootURL.appendingPathComponent("scene-sets")
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: sceneSetsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try children
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { directory -> LoadedSceneSet? in
                let manifestURL = directory.appendingPathComponent("scene-set.gitci.json")
                guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                    return nil
                }
                let manifest = try JSONDecoder.gitci.decode(SceneSetManifest.self, from: Data(contentsOf: manifestURL))
                guard manifest.schemaVersion == 1 else {
                    throw ScreensError.unsupportedSchema(file: manifestURL.path, version: manifest.schemaVersion)
                }
                return LoadedSceneSet(manifest: manifest, directoryURL: directory.standardizedFileURL)
            }
    }

    private static func loadTemplateCatalog(rootURL: URL, project: ProjectManifest?) throws -> TemplateCatalog {
        var catalog = TemplateCatalog(
            packs: [],
            targets: BuiltInCatalog.targetProfiles,
            sceneTemplates: BuiltInCatalog.sceneTemplates,
            sceneSetTemplates: [:],
            components: [:],
            palettes: [:],
            themes: [:]
        )

        for templatesRoot in try templateRoots(projectRoot: rootURL, project: project) {
            try mergeTemplateRoot(templatesRoot, into: &catalog)
        }
        catalog.packs.sort { $0.id < $1.id }
        return catalog
    }

    private static func templateRoots(projectRoot: URL, project: ProjectManifest?) throws -> [URL] {
        var roots: [URL] = [projectRoot]
        let fm = FileManager.default
        for source in project?.sources ?? [] where source.kind == "local" {
            guard let path = source.path, !path.isEmpty else {
                throw ScreensError.projectSourceMissingPath(source.id)
            }
            let sourceURL = URL(fileURLWithPath: path, relativeTo: projectRoot)
                .standardizedFileURL
            guard fm.fileExists(atPath: sourceURL.appendingPathComponent("packs").path) else {
                throw ScreensError.templateSourceNotFound(id: source.id, path: sourceURL.path)
            }
            roots.append(sourceURL)
        }
        for candidate in cachedTemplateCandidates(cacheRoot: templateCacheRoot(home: fm.homeDirectoryForCurrentUser), project: project) {
            if fm.fileExists(atPath: candidate.appendingPathComponent("packs").path) {
                roots.append(candidate)
            }
        }
        if let override = ProcessInfo.processInfo.environment["GITCI_SCREENS_TEMPLATES_ROOT"] {
            let overrideURL = URL(fileURLWithPath: override).standardizedFileURL
            if fm.fileExists(atPath: overrideURL.appendingPathComponent("packs").path) {
                roots.append(overrideURL)
            }
        }
        for root in InstallationPaths.resourceRoots() {
            let candidate = root
                .appendingPathComponent("templates")
                .appendingPathComponent("gitci")
                .appendingPathComponent("screens")
            if fm.fileExists(atPath: candidate.appendingPathComponent("packs").path) {
                roots.append(candidate.standardizedFileURL)
            }
        }
        var current = URL(fileURLWithPath: fm.currentDirectoryPath).standardizedFileURL
        while true {
            let candidate = current
                .appendingPathComponent("templates")
                .appendingPathComponent("gitci")
                .appendingPathComponent("screens")
            if fm.fileExists(atPath: candidate.appendingPathComponent("packs").path) {
                roots.append(candidate.standardizedFileURL)
                break
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        var seen = Set<String>()
        return roots.map(\.standardizedFileURL).filter { root in
            seen.insert(root.path).inserted
        }
    }

    public static func cachedTemplateCandidates(home: URL, project: ProjectManifest?) -> [URL] {
        cachedTemplateCandidates(cacheRoot: defaultTemplateCacheRoot(home: home), project: project)
    }

    public static func cachedTemplateCandidates(cacheRoot templatesRoot: URL, project: ProjectManifest?) -> [URL] {
        let templatesRoot = templatesRoot.standardizedFileURL
        var candidates: [URL] = []

        for source in project?.sources ?? [] where source.kind == "githubRelease" {
            guard let repoName = source.repo?.split(separator: "/").last.map(String.init) else {
                continue
            }
            let version = source.version ?? "latest"
            candidates.append(
                templatesRoot
                    .appendingPathComponent(repoName)
                    .appendingPathComponent(version)
                    .appendingPathComponent("gitci")
                    .appendingPathComponent("screens")
            )
        }

        for repositoryName in ["screens-templates", "gitci-screens-templates"] {
            let repositoryCache = templatesRoot.appendingPathComponent(repositoryName)
            if let versions = try? FileManager.default.contentsOfDirectory(
                at: repositoryCache,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for versionURL in versions.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                    candidates.append(
                        versionURL
                            .appendingPathComponent("gitci")
                            .appendingPathComponent("screens")
                    )
                }
            }
        }

        var seen = Set<String>()
        return candidates.map(\.standardizedFileURL).filter { candidate in
            seen.insert(candidate.path).inserted
        }
    }

    private static func templateCacheRoot(home: URL) -> URL {
        if let override = ProcessInfo.processInfo.environment["GITCI_SCREENS_TEMPLATE_CACHE_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override).standardizedFileURL
        }
        return defaultTemplateCacheRoot(home: home)
    }

    private static func defaultTemplateCacheRoot(home: URL) -> URL {
        home
            .appendingPathComponent(".gitci")
            .appendingPathComponent("screens")
            .appendingPathComponent("templates")
    }

    private static func mergeTemplateRoot(_ root: URL, into catalog: inout TemplateCatalog) throws {
        let packsURL = root.appendingPathComponent("packs")
        guard let packDirectories = try? FileManager.default.contentsOfDirectory(
            at: packsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for packDirectory in packDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard (try? packDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            try loadPack(directory: packDirectory, into: &catalog)
        }
    }

    private static func loadPack(directory: URL, into catalog: inout TemplateCatalog) throws {
        let packManifestURL = directory.appendingPathComponent("pack.gitci.json")
        if FileManager.default.fileExists(atPath: packManifestURL.path) {
            let pack = try decodeVersioned(PackManifest.self, from: packManifestURL)
            catalog.packs.removeAll { $0.id == pack.id }
            catalog.packs.append(pack)
        }

        for manifestURL in findManifestFiles(root: directory, fileName: "scene-template.gitci.json") {
            let manifest = try decodeVersioned(SceneTemplateManifest.self, from: manifestURL)
            catalog.sceneTemplates[manifest.id] = SceneTemplateRecord(
                id: manifest.id,
                name: manifest.name,
                constraints: SceneTemplateConstraints(minAspectRatio: manifest.minAspectRatio),
                requiredProps: requiredProps(from: manifest.propsSchema),
                pack: manifest.pack,
                tags: manifest.tags,
                supportedTargets: manifest.supportedTargets,
                entry: manifest.entry,
                exportName: manifest.export,
                resolvedEntry: resolvedEntry(from: manifest.entry, manifestURL: manifestURL)
            )
        }

        for manifestURL in findManifestFiles(root: directory, fileName: "scene-set-template.gitci.json") {
            let manifest = try decodeVersioned(SceneSetTemplateManifest.self, from: manifestURL)
            catalog.sceneSetTemplates[manifest.id] = manifest
        }

        for manifestURL in findManifestFiles(root: directory, fileName: "component.gitci.json") {
            let manifest = try decodeVersioned(ComponentManifest.self, from: manifestURL)
            catalog.components[manifest.id] = manifest
        }

        for manifestURL in findManifestFiles(root: directory, fileName: "palette.gitci.json") {
            let manifest = try decodeVersioned(PaletteManifest.self, from: manifestURL)
            catalog.palettes[manifest.id] = manifest
        }

        for manifestURL in findManifestFiles(root: directory, fileName: "theme.gitci.json") {
            let manifest = try decodeVersioned(ThemeManifest.self, from: manifestURL)
            catalog.themes[manifest.id] = manifest
        }

        for manifestURL in findManifestFiles(root: directory, fileName: "appstore.gitci.json") {
            let manifest = try decodeVersioned(TargetsManifest.self, from: manifestURL)
            for target in manifest.targets {
                catalog.targets[target.id] = target
            }
        }
    }

    private static func findManifestFiles(root: URL, fileName: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL, url.lastPathComponent == fileName else {
                return nil
            }
            return url
        }.sorted { $0.path < $1.path }
    }

    private static func decodeVersioned<T: Decodable & VersionedManifest>(_ type: T.Type, from url: URL) throws -> T {
        let value = try JSONDecoder.gitci.decode(type, from: Data(contentsOf: url))
        guard value.schemaVersion == 1 else {
            throw ScreensError.unsupportedSchema(file: url.path, version: value.schemaVersion)
        }
        return value
    }

    private static func requiredProps(from schema: JSONValue?) -> [String] {
        guard
            let schemaObject = schema?.objectValue,
            case let .array(required)? = schemaObject["required"]
        else {
            return []
        }
        return required.compactMap(\.stringValue)
    }

    private static func resolvedEntry(from entry: String?, manifestURL: URL) -> String? {
        guard let entry else {
            return nil
        }
        if entry.hasPrefix(".") {
            return URL(fileURLWithPath: entry, relativeTo: manifestURL.deletingLastPathComponent())
                .standardizedFileURL
                .path
        }
        return entry
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct TemplateCatalog {
    var packs: [PackManifest]
    var targets: [String: TargetProfile]
    var sceneTemplates: [String: SceneTemplateRecord]
    var sceneSetTemplates: [String: SceneSetTemplateManifest]
    var components: [String: ComponentManifest]
    var palettes: [String: PaletteManifest]
    var themes: [String: ThemeManifest]
}

private protocol VersionedManifest {
    var schemaVersion: Int { get }
}

extension PackManifest: VersionedManifest {}
extension SceneTemplateManifest: VersionedManifest {}
extension SceneSetTemplateManifest: VersionedManifest {}
extension ComponentManifest: VersionedManifest {}
extension PaletteManifest: VersionedManifest {}
extension ThemeManifest: VersionedManifest {}
extension TargetsManifest: VersionedManifest {}
