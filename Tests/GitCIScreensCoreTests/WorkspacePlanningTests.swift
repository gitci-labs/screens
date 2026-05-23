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
