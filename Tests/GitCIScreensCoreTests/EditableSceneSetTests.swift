import XCTest
@testable import GitCIScreensCore

final class EditableSceneSetTests: XCTestCase {
    func testUpdatesVariantPropAndAdvancesRevision() throws {
        let document = EditableSceneSetDocument(sceneSet: Self.fixtureSceneSet())

        let updated = try document.applying(
            .setVariantProp(
                slotID: "hero",
                variantID: "default",
                path: ["headline"],
                value: .string("Read anything faster")
            )
        )

        XCTAssertEqual(updated.revision, 1)
        XCTAssertEqual(
            updated.sceneSet.slots[0].variants[0].props.objectValue?["headline"],
            .string("Read anything faster")
        )
    }

    func testUpdatesNestedVariantPropForFormBindings() throws {
        let document = EditableSceneSetDocument(sceneSet: Self.fixtureSceneSet())

        let updated = try document.applying(
            .setVariantProp(
                slotID: "hero",
                variantID: "default",
                path: ["screenshot", "alt"],
                value: .string("Reader app screenshot")
            )
        )

        let screenshot = updated.sceneSet.slots[0].variants[0].props.objectValue?["screenshot"]?.objectValue
        XCTAssertEqual(screenshot?["alt"], .string("Reader app screenshot"))
    }

    func testSelectsVariantByStableIDs() throws {
        var sceneSet = Self.fixtureSceneSet()
        sceneSet.slots[0].variants.append(
            SceneVariant(
                id: "wide",
                sceneTemplate: "gitci.core.keyword-cards",
                includeTargets: nil,
                excludeTargets: nil,
                props: .object(["headline": .string("Wide layout")])
            )
        )
        let document = EditableSceneSetDocument(sceneSet: sceneSet)

        let updated = try document.applying(.selectVariant(slotID: "hero", variantID: "wide"))

        XCTAssertEqual(updated.sceneSet.slots[0].selectedVariant, "wide")
    }

    func testThrowsForUnknownBindingPath() {
        let document = EditableSceneSetDocument(sceneSet: Self.fixtureSceneSet())

        XCTAssertThrowsError(
            try document.applying(
                .setVariantProp(
                    slotID: "missing",
                    variantID: "default",
                    path: ["headline"],
                    value: .string("Nope")
                )
            )
        ) { error in
            XCTAssertEqual(error as? EditableSceneSetError, .unknownSlot("missing"))
        }
    }

    private static func fixtureSceneSet() -> SceneSetManifest {
        SceneSetManifest(
            schemaVersion: 1,
            id: "launch",
            name: "Launch",
            targets: ["appstore.iphone.6_9.portrait"],
            theme: ThemeSelection(
                id: "gitci.theme.clean-editorial",
                palette: nil,
                paletteMap: nil,
                overrides: nil
            ),
            slots: [
                SceneSlot(
                    id: "hero",
                    label: "Hero",
                    selectedVariant: "default",
                    variants: [
                        SceneVariant(
                            id: "default",
                            sceneTemplate: "gitci.core.keyword-cards",
                            includeTargets: nil,
                            excludeTargets: nil,
                            props: .object([
                                "headline": .string("Read what you love"),
                                "screenshot": .object([
                                    "kind": .string("asset"),
                                    "path": .string("../../assets/iphone/reader.png")
                                ])
                            ])
                        )
                    ]
                )
            ]
        )
    }
}
