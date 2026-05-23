import XCTest
@testable import GitCIScreensCore

final class WorkspacePlanningTests: XCTestCase {
    func testLoadsExampleSceneSetAndPlansAllCanonicalTargets() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        let sceneSet = try workspace.resolveSceneSet(id: "launch")
        let plan = try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )

        XCTAssertEqual(
            plan.targets.map(\.id),
            [
                "appstore.iphone.6_9.portrait",
                "appstore.ipad.13.portrait",
                "appstore.mac.16_10"
            ]
        )
        XCTAssertEqual(
            plan.targets.flatMap(\.outputs).map(\.variantId),
            [
                "iphone", "iphone", "default", "default",
                "ipad", "ipad", "default", "default",
                "mac", "mac", "default"
            ]
        )
        XCTAssertEqual(plan.targets[0].outputs[0].clip.width, 1320)
        XCTAssertEqual(plan.targets[1].outputs[0].clip.width, 2064)
        XCTAssertEqual(plan.targets[2].outputs[0].clip.width, 2880)
        XCTAssertEqual(plan.targets[0].themeVars["--gitci-color-bg"], "#f8fafc")
        XCTAssertEqual(plan.targets[0].themeVars["--gitci-color-fg"], "#111827")
        XCTAssertEqual(plan.targets[0].themeVars["--gitci-color-primary"], "#2563eb")
        XCTAssertEqual(plan.targets[0].themeVars["--gitci-color-secondary"], "#14b8a6")
        XCTAssertEqual(plan.targets.map { $0.outputs.count }, [4, 4, 3])
        XCTAssertEqual(plan.registry.sceneTemplates.map(\.id), [
            "example.minimal.split-proof",
            "gitci.core.feature-closeup",
            "gitci.core.hero-device"
        ])
        XCTAssertEqual(workspace.packs.map(\.id), ["example.minimal", "gitci.core"])
        XCTAssertEqual(Set(workspace.components.keys), ["gitci.core.device-frame-2d", "gitci.core.device-frame-3d"])
        XCTAssertEqual(Set(workspace.palettes.keys), ["gitci.palette.gitci-blue"])
        XCTAssertEqual(Set(workspace.themes.keys), ["gitci.theme.clean-editorial"])
    }

    func testExampleValidationHasNoDiagnostics() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        let sceneSet = try workspace.resolveSceneSet(id: "launch")
        let report = ProjectValidator(workspace: workspace).validate(sceneSet: sceneSet)

        XCTAssertFalse(report.hasErrors)
        XCTAssertEqual(report.diagnostics, [])
    }

    func testValidationDiagnosticsCarryStructuredContext() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.slots[0].variants[0].props = .object([
            "headline": .string(""),
            "screenshot": .object([
                "kind": .string("asset"),
                "path": .string("../../assets/iphone/inbox.svg")
            ])
        ])
        let report = ProjectValidator(workspace: workspace).validate(sceneSet: sceneSet)
        let diagnostic = try XCTUnwrap(report.diagnostics.first {
            $0.code == "metadata.first-three-missing-headline"
        })

        XCTAssertEqual(diagnostic.targetId, "appstore.iphone.6_9.portrait")
        XCTAssertEqual(diagnostic.outputPath, "appstore.iphone.6_9.portrait/01-hero.png")
    }

    func testOutputManifestCarriesSpanClipMetadata() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        let sceneSet = try workspace.resolveSceneSet(id: "launch")
        let plan = try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )
        let manifest = OutputManifest(plan: plan)
        let iphoneScreenshots = manifest.targets[0].screenshots

        XCTAssertEqual(manifest.targets[0].displayGapPx, 80)
        XCTAssertEqual(iphoneScreenshots[2].span, 2)
        XCTAssertEqual(iphoneScreenshots[2].spanIndex, 0)
        XCTAssertEqual(iphoneScreenshots[2].compositeWidth, 2720)
        XCTAssertEqual(iphoneScreenshots[2].clip, ClipRect(x: 0, y: 0, width: 1320, height: 2868))
        XCTAssertEqual(iphoneScreenshots[3].span, 2)
        XCTAssertEqual(iphoneScreenshots[3].spanIndex, 1)
        XCTAssertEqual(iphoneScreenshots[3].compositeWidth, 2720)
        XCTAssertEqual(iphoneScreenshots[3].clip, ClipRect(x: 1400, y: 0, width: 1320, height: 2868))
    }

    func testOutputManifestDecodesOlderBuildIndexes() throws {
        let json = """
        {
          "schemaVersion": 1,
          "buildId": "old",
          "sceneSet": {
            "id": "launch"
          },
          "targets": [
            {
              "id": "appstore.iphone.6_9.portrait",
              "width": 1320,
              "height": 2868,
              "appearance": "light",
              "screenshots": [
                {
                  "slotId": "hero",
                  "variantId": "default",
                  "sceneTemplate": "gitci.core.hero-device",
                  "path": "appstore.iphone.6_9.portrait/01-hero.png",
                  "width": 1320,
                  "height": 2868,
                  "span": 1
                }
              ]
            }
          ]
        }
        """
        let manifest = try JSONDecoder.gitci.decode(OutputManifest.self, from: Data(json.utf8))
        let target = try XCTUnwrap(manifest.targets.first)
        let screenshot = try XCTUnwrap(target.screenshots.first)

        XCTAssertEqual(target.displayGapPx, 0)
        XCTAssertEqual(screenshot.spanIndex, 0)
        XCTAssertEqual(screenshot.compositeWidth, 1320)
        XCTAssertEqual(screenshot.compositeHeight, 2868)
        XCTAssertEqual(screenshot.clip, ClipRect(x: 0, y: 0, width: 1320, height: 2868))
    }

    func testSpecificAppearancePatternWinsOverBroadPattern() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.appearanceByTarget = [
            "appstore.*": .light,
            "appstore.iphone.*": .dark
        ]
        let plan = try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )

        XCTAssertEqual(plan.targets[0].appearance, .dark)
        XCTAssertEqual(plan.targets[1].appearance, .light)
        XCTAssertEqual(plan.targets[2].appearance, .light)
    }

    func testFindsJSWorkspaceNextToPackagedExecutable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let binURL = root.appendingPathComponent("bin")
        let jsURL = root
            .appendingPathComponent("share")
            .appendingPathComponent("gitci-screens")
            .appendingPathComponent("js")
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: jsURL, withIntermediateDirectories: true)
        try "{}".write(to: jsURL.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let found = try RendererInvoker.findJSWorkspace(
            startingAt: root.appendingPathComponent("empty"),
            executableURL: binURL.appendingPathComponent("gitci-screens")
        )

        XCTAssertEqual(found.path, jsURL.standardizedFileURL.path)
    }

    private func exampleRoot() throws -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot
            .appendingPathComponent("examples")
            .appendingPathComponent("minimal")
            .appendingPathComponent("gitci")
            .appendingPathComponent("screens")
    }
}
