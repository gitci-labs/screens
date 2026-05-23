import ArgumentParser
import Foundation
import GitCIScreensCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
struct GitCIScreensCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gitci-screens",
        abstract: "Generate App Store screenshots from GitCI Screens scene sets.",
        subcommands: [
            Doctor.self,
            Discover.self,
            Validate.self,
            Plan.self,
            Build.self,
            Archive.self,
            Gallery.self,
            Init.self,
            SceneSets.self,
            Templates.self
        ]
    )
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check the local GitCI Screens toolchain."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Flag(name: .long, help: "Print JSON.")
    var json = false

    func run() throws {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = try ScreensRootLocator.locate(from: projectURL)
        _ = try ScreensWorkspace.load(root: screensRoot)
        let jsWorkspace = try RendererInvoker.findJSWorkspace()
        try RendererInvoker.verifyNodePlaywrightRenderer(jsWorkspace: jsWorkspace)
        let summary = DoctorSummary(
            status: "ok",
            screensRoot: screensRoot.path,
            jsWorkspace: jsWorkspace.path,
            renderer: "node-playwright"
        )
        if json {
            let data = try JSONEncoder.gitci.encode(summary)
            print(String(decoding: data, as: UTF8.self))
        } else {
            print("screens root: \(summary.screensRoot)")
            print("js workspace: \(summary.jsWorkspace)")
            print("renderer: \(summary.renderer)")
            print("status: \(summary.status)")
        }
    }
}

struct Discover: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Discover scene sets, targets, and built-in templates."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Flag(name: .long, help: "Print JSON.")
    var json = false

    func run() throws {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = try ScreensRootLocator.locate(from: projectURL)
        let workspace = try ScreensWorkspace.load(root: screensRoot)
        let summary = DiscoverySummary(
            rootDirectory: screensRoot.path,
            sceneSets: workspace.sceneSets.map {
                DiscoverySceneSet(id: $0.id, name: $0.manifest.name)
            },
            packs: workspace.packs,
            targets: workspace.targets.values.sorted { $0.id < $1.id },
            sceneTemplates: workspace.sceneTemplates.values.sorted { $0.id < $1.id },
            sceneSetTemplates: workspace.sceneSetTemplates.values.sorted { $0.id < $1.id },
            components: workspace.components.values.sorted { $0.id < $1.id },
            palettes: workspace.palettes.values.sorted { $0.id < $1.id },
            themes: workspace.themes.values.sorted { $0.id < $1.id }
        )

        if json {
            let data = try JSONEncoder.gitci.encode(summary)
            print(String(decoding: data, as: UTF8.self))
        } else {
            print("Screens root: \(summary.rootDirectory)")
            print("Scene sets:")
            for sceneSet in summary.sceneSets {
                print("  - \(sceneSet.id)\(sceneSet.name.map { " (\($0))" } ?? "")")
            }
            print("Targets:")
            for target in summary.targets {
                print("  - \(target.id) \(target.width)x\(target.height)")
            }
            print("Scene templates:")
            for template in summary.sceneTemplates {
                print("  - \(template.id)")
            }
            print("Scene set templates:")
            for template in summary.sceneSetTemplates {
                print("  - \(template.id)")
            }
            print("Components:")
            for component in summary.components {
                print("  - \(component.id)")
            }
            print("Palettes:")
            for palette in summary.palettes {
                print("  - \(palette.id)")
            }
            print("Themes:")
            for theme in summary.themes {
                print("  - \(theme.id)")
            }
        }
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate a scene set without rendering screenshots."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Option(name: .long, help: "Scene set id.")
    var sceneSet: String?

    @Flag(name: .long, help: "Print JSON.")
    var json = false

    func run() throws {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = try ScreensRootLocator.locate(from: projectURL)
        let workspace = try ScreensWorkspace.load(root: screensRoot)
        let selectedSceneSet = try workspace.resolveSceneSet(id: sceneSet)
        let report = ProjectValidator(workspace: workspace).validate(sceneSet: selectedSceneSet)

        if json {
            let data = try JSONEncoder.gitci.encode(report)
            print(String(decoding: data, as: UTF8.self))
        } else if report.diagnostics.isEmpty {
            print("status: ok")
        } else {
            for diagnostic in report.diagnostics {
                print("\(diagnostic.severity.rawValue): \(diagnostic.code): \(diagnostic.message)")
            }
        }

        if report.hasErrors {
            throw ExitCode.failure
        }
    }
}

struct Plan: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Write a render plan for a scene set."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Option(name: .long, help: "Scene set id.")
    var sceneSet: String?

    @Option(name: .long, help: "Plan output path.")
    var out: String?

    func run() throws {
        let context = try BuildContext(path: path, sceneSet: sceneSet, out: nil).load()
        let planURL = URL(
            fileURLWithPath: out ?? context.planURL.path,
            relativeTo: URL(fileURLWithPath: path).standardizedFileURL
        ).standardizedFileURL
        try FileManager.default.createDirectory(
            at: planURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.gitci.encode(context.plan).write(to: planURL)
        print(planURL.path)
    }
}

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build screenshot assets for a scene set."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Option(name: .long, help: "Scene set id.")
    var sceneSet: String?

    @Option(name: .long, help: "Output directory.")
    var out: String?

    @Option(name: .long, help: "Renderer backend.")
    var renderer: String = "node-playwright"

    func run() async throws {
        let context = try BuildContext(path: path, sceneSet: sceneSet, out: out).load()
        let report = ProjectValidator(workspace: context.workspace).validate(sceneSet: context.sceneSet)
        for diagnostic in report.diagnostics {
            printError("\(diagnostic.severity.rawValue): \(diagnostic.code): \(diagnostic.message)")
        }
        if report.hasErrors {
            throw ExitCode.failure
        }
        try context.writePlan()
        try await RendererInvoker(renderer: renderer).render(planURL: context.planURL)
        try context.writeOutputManifest()
        print(context.outputURL.path)
    }
}

struct Archive: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Package an existing scene-set build output as a zip archive."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Option(name: .long, help: "Scene set id.")
    var sceneSet: String?

    @Option(name: .long, help: "Zip output path.")
    var out: String?

    func run() throws {
        let context = try BuildContext(path: path, sceneSet: sceneSet, out: nil).load()
        let manifestURL = context.outputURL.appendingPathComponent("manifest.gitci-output.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ValidationError("No build manifest found at \(manifestURL.path). Run `gitci-screens build` first.")
        }

        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let archiveURL = if let out {
            URL(fileURLWithPath: out, relativeTo: projectURL).standardizedFileURL
        } else {
            URL(
                fileURLWithPath: "\(context.sceneSet.id).zip",
                relativeTo: context.outputURL.deletingLastPathComponent()
            ).standardizedFileURL
        }

        try Self.writeArchive(sourceURL: context.outputURL, archiveURL: archiveURL)
        print(archiveURL.path)
    }

    private static func writeArchive(sourceURL: URL, archiveURL: URL) throws {
        try FileManager.default.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: archiveURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = sourceURL
        process.arguments = ["zip", "-qry", archiveURL.path, "."]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ValidationError("Could not create zip archive at \(archiveURL.path). Ensure `zip` is installed.")
        }
    }
}

struct Gallery: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a static gallery for discovered scene sets and built outputs."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Option(name: .long, help: "Scene set id whose build output should be linked.")
    var sceneSet: String?

    @Option(name: .long, help: "Gallery output directory.")
    var out: String?

    func run() throws {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = try ScreensRootLocator.locate(from: projectURL)
        let workspace = try ScreensWorkspace.load(root: screensRoot)
        let selectedSceneSet = try workspace.resolveSceneSet(id: sceneSet)
        let outputURL = URL(
            fileURLWithPath: out ?? "build/\(selectedSceneSet.id)/gallery",
            relativeTo: screensRoot
        ).standardizedFileURL
        let buildOutputURL = screensRoot
            .appendingPathComponent("build")
            .appendingPathComponent(selectedSceneSet.id)
            .standardizedFileURL

        try GalleryGenerator(workspace: workspace).generate(
            outputURL: outputURL,
            buildOutputURL: buildOutputURL
        )
        print(outputURL.appendingPathComponent("index.html").path)
    }
}

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a minimal gitci/screens project."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    @Option(name: .long, help: "Project display name.")
    var name: String = "GitCI Screens Project"

    @Flag(name: .long, help: "Write .github/workflows/gitci-screens.yml for CI builds.")
    var githubWorkflow = false

    func run() throws {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = projectURL.appendingPathComponent("gitci").appendingPathComponent("screens")
        let sceneSetRoot = screensRoot.appendingPathComponent("scene-sets").appendingPathComponent("launch")
        let assetRoot = screensRoot.appendingPathComponent("assets").appendingPathComponent("iphone")

        try FileManager.default.createDirectory(at: sceneSetRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assetRoot, withIntermediateDirectories: true)

        try writeIfMissing(
            url: screensRoot.appendingPathComponent("project.gitci.json"),
            contents: """
            {
              "$schema": "https://screens.gitci.com/schemas/project.gitci.schema.json",
              "schemaVersion": 1,
              "id": "local.gitci-screens",
              "name": "\(Self.escapeJSON(name))",
              "defaultSceneSet": "launch",
              "assetPolicy": {
                "allowRemoteAssets": false
              }
            }
            """
        )
        try writeIfMissing(
            url: sceneSetRoot.appendingPathComponent("scene-set.gitci.json"),
            contents: """
            {
              "$schema": "https://screens.gitci.com/schemas/scene-set.gitci.schema.json",
              "schemaVersion": 1,
              "id": "launch",
              "name": "Launch Screens",
              "entry": "./scene-set.tsx",
              "export": "sceneSet",
              "targets": [
                "appstore.iphone.6_9.portrait"
              ],
              "appearanceByTarget": {
                "appstore.*": "light"
              },
              "theme": {
                "id": "gitci.theme.clean-editorial"
              },
              "slots": [
                {
                  "id": "hero",
                  "label": "Hero",
                  "variants": [
                    {
                      "id": "iphone",
                      "sceneTemplate": "gitci.core.hero-device",
                      "props": {
                        "headline": "Your app headline",
                        "subheadline": "A short supporting line.",
                        "screenshot": {
                          "kind": "asset",
                          "path": "../../assets/iphone/screenshot.svg"
                        },
                        "device": "iphone-2d"
                      }
                    }
                  ]
                }
              ]
            }
            """
        )
        try writeIfMissing(
            url: assetRoot.appendingPathComponent("screenshot.svg"),
            contents: """
            <svg xmlns="http://www.w3.org/2000/svg" width="390" height="844" viewBox="0 0 390 844">
              <rect width="390" height="844" rx="42" fill="#F8FAFC"/>
              <rect x="32" y="72" width="150" height="24" rx="12" fill="#CBD5E1"/>
              <text x="32" y="154" fill="#111827" font-family="Arial, Helvetica, sans-serif" font-size="38" font-weight="700">Screenshot</text>
              <rect x="32" y="210" width="326" height="112" rx="28" fill="#DBEAFE"/>
              <rect x="32" y="350" width="326" height="112" rx="28" fill="#CCFBF1"/>
              <rect x="32" y="490" width="326" height="112" rx="28" fill="#FFEDD5"/>
              <rect x="32" y="656" width="326" height="92" rx="28" fill="#0F172A"/>
            </svg>
            """
        )
        if githubWorkflow {
            let workflowURL = projectURL
                .appendingPathComponent(".github")
                .appendingPathComponent("workflows")
                .appendingPathComponent("gitci-screens.yml")
            try FileManager.default.createDirectory(
                at: workflowURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try writeIfMissing(
                url: workflowURL,
                contents: """
                name: GitCI Screens

                on:
                  push:
                    branches: [main]
                  pull_request:

                jobs:
                  screenshots:
                    runs-on: ubuntu-latest
                    steps:
                      - uses: actions/checkout@v4
                      - run: docker run --rm -v "$PWD":/workspace ghcr.io/gitci-labs/screens:main build /workspace
                      - run: docker run --rm -v "$PWD":/workspace ghcr.io/gitci-labs/screens:main gallery /workspace
                      - run: docker run --rm -v "$PWD":/workspace ghcr.io/gitci-labs/screens:main archive /workspace
                      - uses: actions/upload-artifact@v4
                        with:
                          name: gitci-screens
                          path: gitci/screens/build/*.zip
                          retention-days: 14
                """
            )
        }
        print(screensRoot.path)
    }

    private func writeIfMissing(url: URL, contents: String) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escapeJSON(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

struct SceneSets: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scene-sets",
        abstract: "Create and manage project scene sets.",
        subcommands: [
            Create.self,
            FillAssets.self
        ]
    )

    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a project scene set from a reusable scene set template."
        )

        @Argument(help: "Project path. Defaults to current directory.")
        var path: String = "."

        @Option(name: .long, help: "Scene set template id.")
        var template: String

        @Option(name: .long, help: "New scene set id. Defaults to the template scene set id.")
        var id: String?

        @Option(name: .long, help: "New scene set display name.")
        var name: String?

        @Option(
            name: .long,
            parsing: .upToNextOption,
            help: "Asset override in name=path form. The name matches an asset placeholder basename, for example hero=/path/to/screenshot.png."
        )
        var asset: [String] = []

        @Flag(name: .long, help: "Overwrite an existing scene-set manifest.")
        var force = false

        @Flag(name: .long, help: "Do not create placeholder SVG assets for missing asset references.")
        var skipPlaceholderAssets = false

        func run() throws {
            let projectURL = URL(fileURLWithPath: path).standardizedFileURL
            let screensRoot = try ScreensRootLocator.locate(from: projectURL)
            let workspace = try ScreensWorkspace.load(root: screensRoot)
            guard let templateManifest = workspace.sceneSetTemplates[template] else {
                throw ValidationError("Unknown scene set template: \(template)")
            }

            var sceneSet = templateManifest.sceneSet
            if let id {
                sceneSet.id = id
            }
            if let name {
                sceneSet.name = name
            }
            let assetOverrides = try Self.parseAssetOverrides(asset)

            let sceneSetRoot = screensRoot
                .appendingPathComponent("scene-sets")
                .appendingPathComponent(sceneSet.id)
            let manifestURL = sceneSetRoot.appendingPathComponent("scene-set.gitci.json")
            if FileManager.default.fileExists(atPath: manifestURL.path), !force {
                throw ValidationError("Scene set already exists at \(manifestURL.path). Use --force to overwrite it.")
            }

            try FileManager.default.createDirectory(at: sceneSetRoot, withIntermediateDirectories: true)
            sceneSet = try Self.applyAssetOverrides(
                assetOverrides,
                to: sceneSet,
                sceneSetRoot: sceneSetRoot
            )
            try JSONEncoder.gitci.encode(EncodedSceneSetManifest(sceneSet))
                .write(to: manifestURL)

            if !skipPlaceholderAssets {
                try Self.writePlaceholderAssets(for: sceneSet, sceneSetRoot: sceneSetRoot)
            }

            print(manifestURL.path)
        }

        fileprivate static func parseAssetOverrides(_ values: [String]) throws -> [String: URL] {
            var overrides: [String: URL] = [:]
            for value in values {
                guard let separator = value.firstIndex(of: "=") else {
                    throw ValidationError("Invalid --asset value '\(value)'. Use name=path.")
                }
                let key = String(value[..<separator])
                let rawPath = String(value[value.index(after: separator)...])
                guard !key.isEmpty, !rawPath.isEmpty else {
                    throw ValidationError("Invalid --asset value '\(value)'. Use name=path.")
                }
                let sourceURL = URL(fileURLWithPath: rawPath).standardizedFileURL
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    throw ValidationError("Asset override not found: \(sourceURL.path)")
                }
                overrides[key] = sourceURL
            }
            return overrides
        }

        fileprivate static func applyAssetOverrides(
            _ overrides: [String: URL],
            to sceneSet: SceneSetManifest,
            sceneSetRoot: URL
        ) throws -> SceneSetManifest {
            guard !overrides.isEmpty else {
                return sceneSet
            }

            let sceneSetDirectory = URL(fileURLWithPath: sceneSetRoot.path, isDirectory: true)
            var unmatched = Set(overrides.keys)
            var updated = sceneSet
            updated.slots = try sceneSet.slots.map { slot in
                var updatedSlot = slot
                updatedSlot.variants = try slot.variants.map { variant in
                    var updatedVariant = variant
                    updatedVariant.props = try replaceAssetRefs(
                        in: variant.props,
                        sceneSetDirectory: sceneSetDirectory,
                        overrides: overrides,
                        unmatched: &unmatched
                    )
                    return updatedVariant
                }
                return updatedSlot
            }

            if let first = unmatched.sorted().first {
                throw ValidationError("No asset placeholder matched --asset \(first). Match by placeholder basename, for example hero=...")
            }

            return updated
        }

        fileprivate static func replaceAssetRefs(
            in value: JSONValue,
            sceneSetDirectory: URL,
            overrides: [String: URL],
            unmatched: inout Set<String>
        ) throws -> JSONValue {
            switch value {
            case let .object(object):
                if object["kind"]?.stringValue == "asset", let path = object["path"]?.stringValue {
                    let key = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    guard let sourceURL = overrides[key] else {
                        return value
                    }
                    let originalURL = URL(fileURLWithPath: path, relativeTo: sceneSetDirectory)
                        .standardizedFileURL
                    let extensionToUse = sourceURL.pathExtension.isEmpty
                        ? originalURL.pathExtension
                        : sourceURL.pathExtension
                    let targetURL = originalURL
                        .deletingPathExtension()
                        .appendingPathExtension(extensionToUse)
                    try FileManager.default.createDirectory(
                        at: targetURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
                    unmatched.remove(key)

                    var updatedObject = object
                    updatedObject["path"] = .string(relativePath(from: sceneSetDirectory, to: targetURL))
                    return .object(updatedObject)
                }

                var mapped: [String: JSONValue] = [:]
                mapped.reserveCapacity(object.count)
                for (key, nestedValue) in object {
                    mapped[key] = try replaceAssetRefs(
                        in: nestedValue,
                        sceneSetDirectory: sceneSetDirectory,
                        overrides: overrides,
                        unmatched: &unmatched
                    )
                }
                return .object(mapped)
            case let .array(array):
                return .array(try array.map {
                    try replaceAssetRefs(
                        in: $0,
                        sceneSetDirectory: sceneSetDirectory,
                        overrides: overrides,
                        unmatched: &unmatched
                    )
                })
            case .string, .number, .bool, .null:
                return value
            }
        }

        private static func writePlaceholderAssets(for sceneSet: SceneSetManifest, sceneSetRoot: URL) throws {
            let sceneSetDirectory = URL(fileURLWithPath: sceneSetRoot.path, isDirectory: true)
            let paths = Set(
                sceneSet.slots.flatMap { slot in
                    slot.variants.flatMap { variant in
                        collectAssetPaths(in: variant.props)
                    }
                }
            )
            for path in paths.sorted() {
                guard !path.hasPrefix("http://"), !path.hasPrefix("https://") else {
                    continue
                }
                let assetURL = URL(fileURLWithPath: path, relativeTo: sceneSetDirectory).standardizedFileURL
                guard assetURL.path.hasPrefix(sceneSetDirectory.deletingLastPathComponent().deletingLastPathComponent().path) else {
                    continue
                }
                guard assetURL.pathExtension.lowercased() == "svg" else {
                    continue
                }
                guard !FileManager.default.fileExists(atPath: assetURL.path) else {
                    continue
                }
                try FileManager.default.createDirectory(
                    at: assetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try placeholderSVG(title: assetURL.deletingPathExtension().lastPathComponent)
                    .write(to: assetURL, atomically: true, encoding: .utf8)
            }
        }

        private static func collectAssetPaths(in value: JSONValue) -> [String] {
            switch value {
            case let .object(object):
                if object["kind"]?.stringValue == "asset", let path = object["path"]?.stringValue {
                    return [path]
                }
                return object.values.flatMap(collectAssetPaths)
            case let .array(array):
                return array.flatMap(collectAssetPaths)
            case .string, .number, .bool, .null:
                return []
            }
        }

        private static func placeholderSVG(title: String) -> String {
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="390" height="844" viewBox="0 0 390 844">
              <rect width="390" height="844" rx="42" fill="#F8FAFC"/>
              <rect x="32" y="72" width="150" height="24" rx="12" fill="#CBD5E1"/>
              <text x="32" y="154" fill="#111827" font-family="Arial, Helvetica, sans-serif" font-size="38" font-weight="700">\(escapeXML(title))</text>
              <rect x="32" y="210" width="326" height="112" rx="28" fill="#DBEAFE"/>
              <rect x="32" y="350" width="326" height="112" rx="28" fill="#CCFBF1"/>
              <rect x="32" y="490" width="326" height="112" rx="28" fill="#FFEDD5"/>
              <rect x="32" y="656" width="326" height="92" rx="28" fill="#0F172A"/>
            </svg>
            """
        }

        private static func escapeXML(_ value: String) -> String {
            value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }

        fileprivate static func relativePath(from directory: URL, to target: URL) -> String {
            let baseComponents = directory.standardizedFileURL.pathComponents
            let targetComponents = target.standardizedFileURL.pathComponents
            var sharedCount = 0
            while sharedCount < baseComponents.count,
                  sharedCount < targetComponents.count,
                  baseComponents[sharedCount] == targetComponents[sharedCount] {
                sharedCount += 1
            }
            let parentSteps = Array(repeating: "..", count: baseComponents.count - sharedCount)
            let targetSteps = targetComponents.dropFirst(sharedCount)
            let path = (parentSteps + targetSteps).joined(separator: "/")
            return path.isEmpty ? "." : path
        }
    }

    struct FillAssets: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "fill-assets",
            abstract: "Copy screenshots into an existing scene set and update matching asset references."
        )

        @Argument(help: "Project path. Defaults to current directory.")
        var path: String = "."

        @Option(name: .long, help: "Scene set id.")
        var sceneSet: String?

        @Option(
            name: .long,
            parsing: .upToNextOption,
            help: "Asset override in name=path form. The name matches an asset placeholder basename, for example hero=/path/to/screenshot.png."
        )
        var asset: [String] = []

        func run() throws {
            guard !asset.isEmpty else {
                throw ValidationError("At least one --asset name=path value is required.")
            }

            let projectURL = URL(fileURLWithPath: path).standardizedFileURL
            let screensRoot = try ScreensRootLocator.locate(from: projectURL)
            let workspace = try ScreensWorkspace.load(root: screensRoot)
            let loadedSceneSet = try workspace.resolveSceneSet(id: sceneSet)
            let overrides = try Create.parseAssetOverrides(asset)
            let updatedSceneSet = try Create.applyAssetOverrides(
                overrides,
                to: loadedSceneSet.manifest,
                sceneSetRoot: loadedSceneSet.directoryURL
            )
            let manifestURL = loadedSceneSet.directoryURL.appendingPathComponent("scene-set.gitci.json")
            try JSONEncoder.gitci.encode(EncodedSceneSetManifest(updatedSceneSet))
                .write(to: manifestURL)
            print(manifestURL.path)
        }
    }
}

struct Templates: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "templates",
        abstract: "Manage cached GitCI Screens template releases.",
        subcommands: [
            Install.self,
            List.self
        ]
    )

    static func resolvedCacheRoot(_ cacheRoot: String?) -> URL {
        if let cacheRoot {
            return URL(fileURLWithPath: cacheRoot).standardizedFileURL
        }
        if let override = ProcessInfo.processInfo.environment["GITCI_SCREENS_TEMPLATE_CACHE_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override).standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gitci")
            .appendingPathComponent("screens")
            .appendingPathComponent("templates")
            .standardizedFileURL
    }

    struct Install: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Install a template release archive into the local cache."
        )

        @Option(name: .long, help: "GitHub repository, for example gitci-labs/screens-templates.")
        var repo: String = "gitci-labs/screens-templates"

        @Option(name: .long, help: "Release version or tag, for example v0.1.0.")
        var version: String

        @Option(name: .long, help: "Local release archive path. If omitted, the archive is downloaded from GitHub Releases.")
        var archive: String?

        @Option(name: .long, help: "Template cache root. Defaults to ~/.gitci/screens/templates.")
        var cacheRoot: String?

        func run() async throws {
            let archiveURL: URL
            if let archive {
                archiveURL = URL(fileURLWithPath: archive).standardizedFileURL
            } else {
                archiveURL = try await Self.downloadArchive(repo: repo, version: version)
            }

            let installedURL = try TemplateArchiveInstaller.install(
                archiveURL: archiveURL,
                repo: repo,
                version: version,
                cacheRoot: Templates.resolvedCacheRoot(cacheRoot)
            )
            print(installedURL.path)
        }

        private static func downloadArchive(repo: String, version: String) async throws -> URL {
            let repositoryName = try TemplateArchiveInstaller.repositoryName(repo)
            let archiveName = "\(repositoryName)-\(version).tar.gz"
            guard let url = URL(string: "https://github.com/\(repo)/releases/download/\(version)/\(archiveName)") else {
                throw ValidationError("Invalid GitHub repository: \(repo)")
            }
            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ValidationError("Download failed with HTTP \(http.statusCode): \(url.absoluteString)")
            }
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("tar.gz")
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            return destinationURL
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List template releases installed in the local cache."
        )

        @Option(name: .long, help: "Template cache root. Defaults to ~/.gitci/screens/templates.")
        var cacheRoot: String?

        @Flag(name: .long, help: "Print JSON.")
        var json = false

        func run() throws {
            let cacheRootURL = Templates.resolvedCacheRoot(cacheRoot)
            let records = try TemplateArchiveInstaller.list(cacheRoot: cacheRootURL)
            if json {
                let summary = TemplateCacheSummary(cacheRoot: cacheRootURL.path, releases: records)
                let data = try JSONEncoder.gitci.encode(summary)
                print(String(decoding: data, as: UTF8.self))
                return
            }

            print("Template cache: \(cacheRootURL.path)")
            if records.isEmpty {
                print("No template releases installed.")
                return
            }
            for record in records {
                print("  - \(record.repo) \(record.version) \(record.path)")
            }
        }
    }
}

private enum TemplateArchiveInstaller {
    static func install(archiveURL: URL, repo: String, version: String, cacheRoot: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ValidationError("Template archive not found: \(archiveURL.path)")
        }

        let extractURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitci-screens-template-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: extractURL)
        }

        try runTarExtract(archiveURL: archiveURL, destinationURL: extractURL)
        let packageURL = try packageRoot(in: extractURL)
        let destinationURL = try cacheDestination(repo: repo, version: version, cacheRoot: cacheRoot)

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: packageURL, to: destinationURL)
        return destinationURL
    }

    static func list(cacheRoot: URL) throws -> [TemplateCacheRecord] {
        guard FileManager.default.fileExists(atPath: cacheRoot.path) else {
            return []
        }
        let repositories = try FileManager.default.contentsOfDirectory(
            at: cacheRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var records: [TemplateCacheRecord] = []
        for repository in repositories {
            guard try repository.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                continue
            }
            let versions = try FileManager.default.contentsOfDirectory(
                at: repository,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for version in versions {
                guard try version.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                    continue
                }
                guard FileManager.default.fileExists(
                    atPath: version.appendingPathComponent("gitci/screens/packs").path
                ) else {
                    continue
                }
                records.append(
                    TemplateCacheRecord(
                        repo: repository.lastPathComponent,
                        version: version.lastPathComponent,
                        path: version.path
                    )
                )
            }
        }
        return records.sorted {
            if $0.repo == $1.repo {
                return $0.version < $1.version
            }
            return $0.repo < $1.repo
        }
    }

    static func cacheDestination(repo: String, version: String, cacheRoot: URL) throws -> URL {
        try cacheRoot
            .appendingPathComponent(repositoryName(repo))
            .appendingPathComponent(version)
            .standardizedFileURL
    }

    static func repositoryName(_ repo: String) throws -> String {
        guard let name = repo.split(separator: "/").last, !name.isEmpty else {
            throw ValidationError("Invalid GitHub repository: \(repo)")
        }
        return String(name)
    }

    private static func runTarExtract(archiveURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tar", "-xzf", archiveURL.path, "-C", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ValidationError("Could not extract template archive: \(archiveURL.path)")
        }
    }

    private static func packageRoot(in extractURL: URL) throws -> URL {
        if FileManager.default.fileExists(
            atPath: extractURL.appendingPathComponent("gitci/screens/packs").path
        ) {
            return extractURL
        }
        let children = try FileManager.default.contentsOfDirectory(
            at: extractURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for child in children {
            if FileManager.default.fileExists(
                atPath: child.appendingPathComponent("gitci/screens/packs").path
            ) {
                return child
            }
        }
        throw ValidationError("Template archive does not contain gitci/screens/packs.")
    }
}

private struct TemplateCacheSummary: Codable {
    var cacheRoot: String
    var releases: [TemplateCacheRecord]
}

private struct TemplateCacheRecord: Codable {
    var repo: String
    var version: String
    var path: String
}

private struct BuildContext {
    var path: String
    var sceneSet: String?
    var out: String?

    func load() throws -> LoadedBuildContext {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = try ScreensRootLocator.locate(from: projectURL)
        let workspace = try ScreensWorkspace.load(root: screensRoot)
        let selectedSceneSet = try workspace.resolveSceneSet(id: sceneSet)

        let outputURL: URL
        if let out {
            outputURL = URL(fileURLWithPath: out, relativeTo: projectURL).standardizedFileURL
        } else {
            outputURL = screensRoot
                .appendingPathComponent("build")
                .appendingPathComponent(selectedSceneSet.id)
                .standardizedFileURL
        }

        let plan = try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: selectedSceneSet,
            outputDirectory: outputURL
        )
        return LoadedBuildContext(
            workspace: workspace,
            sceneSet: selectedSceneSet,
            outputURL: outputURL,
            planURL: outputURL.appendingPathComponent("plan.gitci-render.json"),
            plan: plan
        )
    }
}

private struct LoadedBuildContext {
    var workspace: ScreensWorkspace
    var sceneSet: LoadedSceneSet
    var outputURL: URL
    var planURL: URL
    var plan: RenderPlan

    func writePlan() throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try JSONEncoder.gitci.encode(plan).write(to: planURL)
    }

    func writeOutputManifest() throws {
        let manifestURL = outputURL.appendingPathComponent("manifest.gitci-output.json")
        try JSONEncoder.gitci.encode(OutputManifest(plan: plan)).write(to: manifestURL)
    }
}

private struct DiscoverySummary: Codable {
    var rootDirectory: String
    var sceneSets: [DiscoverySceneSet]
    var packs: [PackManifest]
    var targets: [TargetProfile]
    var sceneTemplates: [SceneTemplateRecord]
    var sceneSetTemplates: [SceneSetTemplateManifest]
    var components: [ComponentManifest]
    var palettes: [PaletteManifest]
    var themes: [ThemeManifest]
}

private struct DiscoverySceneSet: Codable {
    var id: String
    var name: String?
}

private struct EncodedSceneSetManifest: Encodable {
    var schema = "https://screens.gitci.com/schemas/scene-set.gitci.schema.json"
    var manifest: SceneSetManifest

    init(_ manifest: SceneSetManifest) {
        self.manifest = manifest
    }

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case schemaVersion
        case id
        case name
        case entry
        case `export`
        case targets
        case appearanceByTarget
        case theme
        case slots
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(manifest.schemaVersion, forKey: .schemaVersion)
        try container.encode(manifest.id, forKey: .id)
        try container.encodeIfPresent(manifest.name, forKey: .name)
        try container.encodeIfPresent(manifest.entry, forKey: .entry)
        try container.encodeIfPresent(manifest.export, forKey: .export)
        try container.encode(manifest.targets, forKey: .targets)
        try container.encodeIfPresent(manifest.appearanceByTarget, forKey: .appearanceByTarget)
        try container.encodeIfPresent(manifest.theme, forKey: .theme)
        try container.encode(manifest.slots, forKey: .slots)
    }
}

private struct DoctorSummary: Codable {
    var status: String
    var screensRoot: String
    var jsWorkspace: String
    var renderer: String
}

private func printError(_ value: String) {
    FileHandle.standardError.write(Data((value + "\n").utf8))
}
