import ArgumentParser
import Foundation
import GitCIScreensCore

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
            Gallery.self,
            Init.self
        ]
    )
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check the local GitCI Screens toolchain."
    )

    @Argument(help: "Project path. Defaults to current directory.")
    var path: String = "."

    func run() throws {
        let projectURL = URL(fileURLWithPath: path).standardizedFileURL
        let screensRoot = try ScreensRootLocator.locate(from: projectURL)
        _ = try ScreensWorkspace.load(root: screensRoot)
        let jsWorkspace = try RendererInvoker.findJSWorkspace()
        print("screens root: \(screensRoot.path)")
        print("js workspace: \(jsWorkspace.path)")
        print("renderer: node-playwright")
        print("status: ok")
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
    var components: [ComponentManifest]
    var palettes: [PaletteManifest]
    var themes: [ThemeManifest]
}

private struct DiscoverySceneSet: Codable {
    var id: String
    var name: String?
}

private func printError(_ value: String) {
    FileHandle.standardError.write(Data((value + "\n").utf8))
}
