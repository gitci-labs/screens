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
        XCTAssertEqual(Set(workspace.sceneSetTemplates.keys), ["gitci.core.basic-launch"])
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

    func testGithubReleaseSourcesAreSupportedValidationInputs() throws {
        let root = try exampleRoot()
        var workspace = try ScreensWorkspace.load(root: root)
        workspace.project = ProjectManifest(
            schemaVersion: 1,
            id: "com.example",
            name: "Example",
            sources: [
                ProjectSource(
                    id: "gitci.core",
                    kind: "githubRelease",
                    path: nil,
                    repo: "gitci-labs/screens-templates",
                    version: "v0.1.0"
                )
            ],
            defaultSceneSet: "launch",
            assetPolicy: nil
        )
        let sceneSet = try workspace.resolveSceneSet(id: "launch")
        let report = ProjectValidator(workspace: workspace).validate(sceneSet: sceneSet)

        XCTAssertFalse(report.diagnostics.contains { $0.code == "project.source-unsupported" })
    }

    func testValidationReportsMissingAssetsDirectly() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.iphone.6_9.portrait"]
        sceneSet.manifest.slots[0].variants[0].props = .object([
            "headline": .string("Missing screenshot"),
            "screenshot": .object([
                "kind": .string("asset"),
                "path": .string("../../assets/iphone/does-not-exist.svg")
            ])
        ])

        let report = ProjectValidator(workspace: workspace).validate(sceneSet: sceneSet)
        let diagnostic = try XCTUnwrap(report.diagnostics.first)

        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(diagnostic.code, "asset.not-found")
        XCTAssertTrue(diagnostic.assetPath?.hasSuffix("does-not-exist.svg") == true)
    }

    func testValidationReportsRemoteAssetsWhenDisabled() throws {
        let root = try exampleRoot()
        var workspace = try ScreensWorkspace.load(root: root)
        workspace.project = ProjectManifest(
            schemaVersion: 1,
            id: "com.example",
            name: "Example",
            sources: nil,
            defaultSceneSet: "launch",
            assetPolicy: AssetPolicy(allowRemoteAssets: false)
        )
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.iphone.6_9.portrait"]
        sceneSet.manifest.slots[0].variants[0].props = .object([
            "headline": .string("Remote screenshot"),
            "screenshot": .object([
                "kind": .string("asset"),
                "path": .string("https://example.com/screenshot.png")
            ])
        ])

        let report = ProjectValidator(workspace: workspace).validate(sceneSet: sceneSet)
        let diagnostic = try XCTUnwrap(report.diagnostics.first)

        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(diagnostic.code, "asset.remote-disabled")
        XCTAssertEqual(diagnostic.assetPath, "https://example.com/screenshot.png")
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

    func testPlannerExpandsLocalizedSceneSets() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.iphone.6_9.portrait"]
        sceneSet.manifest.locales = [
            SceneSetLocale(
                id: "en-US",
                name: "English (US)",
                strings: [
                    "hero.headline": "Ship screenshots from source"
                ]
            ),
            SceneSetLocale(
                id: "ja-JP",
                name: "Japanese",
                strings: [
                    "hero.headline": "ソースからスクリーンショットを生成"
                ]
            )
        ]
        sceneSet.manifest.slots = [
            SceneSlot(
                id: "hero",
                label: nil,
                selectedVariant: nil,
                variants: [
                    SceneVariant(
                        id: "default",
                        sceneTemplate: "gitci.core.hero-device",
                        includeTargets: nil,
                        excludeTargets: nil,
                        props: .object([
                            "headline": .object([
                                "kind": .string("localized"),
                                "key": .string("hero.headline"),
                                "fallback": .string("Ship screenshots")
                            ]),
                            "screenshot": .object([
                                "kind": .string("asset"),
                                "path": .string("../../assets/iphone/inbox.svg")
                            ]),
                            "device": .string("iphone-2d")
                        ])
                    )
                ]
            )
        ]

        let plan = try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )
        let outputs = try XCTUnwrap(plan.targets.first?.outputs)
        let manifest = OutputManifest(plan: plan)
        let screenshots = try XCTUnwrap(manifest.targets.first?.screenshots)

        XCTAssertEqual(outputs.map { $0.locale?.id }, ["en-US", "ja-JP"])
        XCTAssertEqual(outputs.map(\.outputPath), [
            "en-US/appstore.iphone.6_9.portrait/01-hero.png",
            "ja-JP/appstore.iphone.6_9.portrait/01-hero.png"
        ])
        XCTAssertEqual(outputs[0].props.objectValue?["headline"]?.stringValue, "Ship screenshots from source")
        XCTAssertEqual(outputs[1].props.objectValue?["headline"]?.stringValue, "ソースからスクリーンショットを生成")
        XCTAssertEqual(screenshots.map { $0.locale?.id }, ["en-US", "ja-JP"])
    }

    func testPlannerCanAddPseudoLocaleForLocalizationStressTesting() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.iphone.6_9.portrait"]
        sceneSet.manifest.locales = nil
        sceneSet.manifest.slots = [
            SceneSlot(
                id: "hero",
                label: nil,
                selectedVariant: nil,
                variants: [
                    SceneVariant(
                        id: "default",
                        sceneTemplate: "gitci.core.hero-device",
                        includeTargets: nil,
                        excludeTargets: nil,
                        props: .object([
                            "headline": .object([
                                "kind": .string("localized"),
                                "key": .string("hero.headline"),
                                "fallback": .string("Ship screenshots")
                            ]),
                            "screenshot": .object([
                                "kind": .string("asset"),
                                "path": .string("../../assets/iphone/inbox.svg")
                            ]),
                            "device": .string("iphone-2d")
                        ])
                    )
                ]
            )
        ]

        let plan = try RenderPlanner(
            workspace: workspace,
            options: RenderPlannerOptions(includePseudoLocale: true)
        ).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )
        let outputs = try XCTUnwrap(plan.targets.first?.outputs)
        let pseudoHeadline = try XCTUnwrap(outputs[1].props.objectValue?["headline"]?.stringValue)

        XCTAssertEqual(outputs.map { $0.locale?.id }, [nil, "qps-ploc"])
        XCTAssertEqual(outputs.map(\.outputPath), [
            "appstore.iphone.6_9.portrait/01-hero.png",
            "qps-ploc/appstore.iphone.6_9.portrait/01-hero.png"
        ])
        XCTAssertEqual(outputs[0].props.objectValue?["headline"]?.stringValue, "Ship screenshots")
        XCTAssertTrue(pseudoHeadline.hasPrefix("[!! "))
        XCTAssertGreaterThan(pseudoHeadline.count, "Ship screenshots".count)
    }

    func testPlannerAppliesNamedVariantGroupSelections() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.iphone.6_9.portrait"]
        sceneSet.manifest.variantGroups = [
            SceneSetVariantGroup(
                id: "ppo-a",
                name: "PPO A",
                selections: [
                    "hero": "alternate"
                ]
            )
        ]
        sceneSet.manifest.slots = [
            SceneSlot(
                id: "hero",
                label: nil,
                selectedVariant: "default",
                variants: [
                    SceneVariant(
                        id: "default",
                        sceneTemplate: "gitci.core.hero-device",
                        includeTargets: nil,
                        excludeTargets: nil,
                        props: .object([
                            "headline": .string("Default headline"),
                            "screenshot": .object([
                                "kind": .string("asset"),
                                "path": .string("../../assets/iphone/inbox.svg")
                            ])
                        ])
                    ),
                    SceneVariant(
                        id: "alternate",
                        sceneTemplate: "gitci.core.hero-device",
                        includeTargets: nil,
                        excludeTargets: nil,
                        props: .object([
                            "headline": .string("Alternate headline"),
                            "screenshot": .object([
                                "kind": .string("asset"),
                                "path": .string("../../assets/iphone/inbox.svg")
                            ])
                        ])
                    )
                ]
            )
        ]

        let plan = try RenderPlanner(
            workspace: workspace,
            options: RenderPlannerOptions(variantGroupID: "ppo-a")
        ).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )
        let output = try XCTUnwrap(plan.targets.first?.outputs.first)

        XCTAssertEqual(plan.sceneSet.variantGroup?.id, "ppo-a")
        XCTAssertEqual(output.variantId, "alternate")
        XCTAssertEqual(output.props.objectValue?["headline"]?.stringValue, "Alternate headline")
        XCTAssertEqual(OutputManifest(plan: plan).sceneSet.variantGroup?.name, "PPO A")
    }

    func testValidationReportsUnknownVariantGroup() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        let sceneSet = try workspace.resolveSceneSet(id: "launch")
        let report = ProjectValidator(
            workspace: workspace,
            options: RenderPlannerOptions(variantGroupID: "missing")
        ).validate(sceneSet: sceneSet)
        let diagnostic = try XCTUnwrap(report.diagnostics.first)

        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(diagnostic.code, "variant-group.unknown")
        XCTAssertEqual(diagnostic.sourceId, "missing")
    }

    func testValidationReportsMissingLocalizedString() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.iphone.6_9.portrait"]
        sceneSet.manifest.locales = [
            SceneSetLocale(id: "en-US", name: nil, strings: [:])
        ]
        sceneSet.manifest.slots[0].variants[0].props = .object([
            "headline": .object([
                "kind": .string("localized"),
                "key": .string("hero.missing")
            ]),
            "screenshot": .object([
                "kind": .string("asset"),
                "path": .string("../../assets/iphone/inbox.svg")
            ])
        ])

        let report = ProjectValidator(workspace: workspace).validate(sceneSet: sceneSet)
        let diagnostic = try XCTUnwrap(report.diagnostics.first)

        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(diagnostic.code, "locale.string-missing")
        XCTAssertEqual(diagnostic.sourceId, "en-US")
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

    func testFastlaneExporterCopiesScreenshotsIntoLocaleFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let buildURL = root.appendingPathComponent("build")
        let targetDirectoryURL = buildURL
            .appendingPathComponent("en-US")
            .appendingPathComponent("appstore.iphone.6_9.portrait")
        let fastlaneURL = root.appendingPathComponent("fastlane/screenshots")
        try FileManager.default.createDirectory(at: targetDirectoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let sourceURL = targetDirectoryURL.appendingPathComponent("01-hero.png")
        try Data("png".utf8).write(to: sourceURL)
        let manifest = OutputManifest(
            schemaVersion: 1,
            buildId: "localized",
            sceneSet: RenderPlanSceneSet(id: "launch", name: nil),
            targets: [
                OutputManifestTarget(
                    id: "appstore.iphone.6_9.portrait",
                    width: 1320,
                    height: 2868,
                    displayGapPx: 80,
                    appearance: .light,
                    screenshots: [
                        OutputManifestScreenshot(
                            locale: RenderPlanLocale(id: "en-US", name: "English"),
                            slotId: "hero",
                            variantId: "default",
                            sceneTemplate: "gitci.core.hero-device",
                            path: "en-US/appstore.iphone.6_9.portrait/01-hero.png",
                            width: 1320,
                            height: 2868,
                            span: 1,
                            spanIndex: 0,
                            compositeWidth: 1320,
                            compositeHeight: 2868,
                            clip: ClipRect(x: 0, y: 0, width: 1320, height: 2868)
                        )
                    ]
                )
            ]
        )
        try JSONEncoder.gitci.encode(manifest)
            .write(to: buildURL.appendingPathComponent("manifest.gitci-output.json"))

        let exported = try FastlaneScreenshotsExporter(
            buildOutputURL: buildURL,
            outputURL: fastlaneURL
        ).export()
        let outputPath = try XCTUnwrap(exported.first?.outputPath)

        XCTAssertEqual(exported.first?.localeId, "en-US")
        XCTAssertTrue(outputPath.hasSuffix("fastlane/screenshots/en-US/01-appstore-iphone-6_9-portrait-hero-default.png"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
    }

    func testFastlaneExporterRestartsOrdinalsPerLocaleAndTarget() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let buildURL = root.appendingPathComponent("build")
        let sourceDirectoryURL = buildURL.appendingPathComponent("appstore.iphone.6_9.portrait")
        let fastlaneURL = root.appendingPathComponent("fastlane/screenshots")
        try FileManager.default.createDirectory(at: sourceDirectoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        for filename in ["en.png", "ja.png"] {
            try Data("png".utf8).write(to: sourceDirectoryURL.appendingPathComponent(filename))
        }
        let manifest = OutputManifest(
            schemaVersion: 1,
            buildId: "localized",
            sceneSet: RenderPlanSceneSet(id: "launch", name: nil),
            targets: [
                OutputManifestTarget(
                    id: "appstore.iphone.6_9.portrait",
                    width: 1320,
                    height: 2868,
                    displayGapPx: 80,
                    appearance: .light,
                    screenshots: [
                        OutputManifestScreenshot(
                            locale: RenderPlanLocale(id: "en-US", name: nil),
                            slotId: "hero",
                            variantId: "iphone",
                            sceneTemplate: "gitci.core.hero-device",
                            path: "appstore.iphone.6_9.portrait/en.png",
                            width: 1320,
                            height: 2868,
                            span: 1,
                            spanIndex: 0,
                            compositeWidth: 1320,
                            compositeHeight: 2868,
                            clip: ClipRect(x: 0, y: 0, width: 1320, height: 2868)
                        ),
                        OutputManifestScreenshot(
                            locale: RenderPlanLocale(id: "ja-JP", name: nil),
                            slotId: "hero",
                            variantId: "iphone",
                            sceneTemplate: "gitci.core.hero-device",
                            path: "appstore.iphone.6_9.portrait/ja.png",
                            width: 1320,
                            height: 2868,
                            span: 1,
                            spanIndex: 0,
                            compositeWidth: 1320,
                            compositeHeight: 2868,
                            clip: ClipRect(x: 0, y: 0, width: 1320, height: 2868)
                        )
                    ]
                )
            ]
        )
        try JSONEncoder.gitci.encode(manifest)
            .write(to: buildURL.appendingPathComponent("manifest.gitci-output.json"))

        let exported = try FastlaneScreenshotsExporter(
            buildOutputURL: buildURL,
            outputURL: fastlaneURL
        ).export()

        XCTAssertTrue(exported[0].outputPath.hasSuffix("en-US/01-appstore-iphone-6_9-portrait-hero-iphone.png"))
        XCTAssertTrue(exported[1].outputPath.hasSuffix("ja-JP/01-appstore-iphone-6_9-portrait-hero-iphone.png"))
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

    func testSceneTemplateSupportedTargetsAreEnforced() throws {
        let root = try exampleRoot()
        var workspace = try ScreensWorkspace.load(root: root)
        workspace.sceneTemplates["example.minimal.split-proof"]?.supportedTargets = ["appstore.iphone.*"]
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.mac.16_10"]
        sceneSet.manifest.slots = [
            SceneSlot(
                id: "unsupported",
                label: nil,
                selectedVariant: nil,
                variants: [
                    SceneVariant(
                        id: "iphone-only",
                        sceneTemplate: "example.minimal.split-proof",
                        includeTargets: nil,
                        excludeTargets: nil,
                        props: .object([
                            "headline": .string("Unsupported"),
                            "screenshot": .object([
                                "kind": .string("asset"),
                                "path": .string("../../assets/iphone/inbox.svg")
                            ])
                        ])
                    )
                ]
            )
        ]

        XCTAssertThrowsError(try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )) { error in
            XCTAssertEqual(
                String(describing: error),
                "Scene template example.minimal.split-proof does not support target appstore.mac.16_10."
            )
        }
    }

    func testPlannerFailsClearlyWhenTargetHasNoOutputs() throws {
        let root = try exampleRoot()
        let workspace = try ScreensWorkspace.load(root: root)
        var sceneSet = try workspace.resolveSceneSet(id: "launch")
        sceneSet.manifest.targets = ["appstore.mac.16_10"]
        sceneSet.manifest.slots = [
            SceneSlot(
                id: "iphone-only",
                label: nil,
                selectedVariant: nil,
                variants: [
                    SceneVariant(
                        id: "iphone",
                        sceneTemplate: "gitci.core.hero-device",
                        includeTargets: ["appstore.iphone.*"],
                        excludeTargets: nil,
                        props: .object([
                            "headline": .string("iPhone only"),
                            "screenshot": .object([
                                "kind": .string("asset"),
                                "path": .string("../../assets/iphone/inbox.svg")
                            ])
                        ])
                    )
                ]
            )
        ]

        XCTAssertThrowsError(try RenderPlanner(workspace: workspace).makePlan(
            sceneSet: sceneSet,
            outputDirectory: root.appendingPathComponent("build/test")
        )) { error in
            XCTAssertEqual(
                String(describing: error),
                "Target appstore.mac.16_10 would not produce any screenshots."
            )
        }
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

    func testCachedTemplateCandidatesUseCurrentScreensTemplatesName() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let project = ProjectManifest(
            schemaVersion: 1,
            id: "com.example",
            name: "Example",
            sources: [
                ProjectSource(
                    id: "gitci.core",
                    kind: "githubRelease",
                    path: nil,
                    repo: "gitci-labs/screens-templates",
                    version: "v0.1.0"
                )
            ],
            defaultSceneSet: nil,
            assetPolicy: nil
        )
        defer {
            try? FileManager.default.removeItem(at: home)
        }

        let candidates = ScreensWorkspace.cachedTemplateCandidates(
            cacheRoot: home.appendingPathComponent("cache"),
            project: project
        )

        XCTAssertEqual(
            candidates.first?.path,
            home
                .appendingPathComponent("cache/screens-templates/v0.1.0/gitci/screens")
                .standardizedFileURL
                .path
        )
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
