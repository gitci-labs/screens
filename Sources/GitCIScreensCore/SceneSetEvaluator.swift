import Foundation

public protocol SceneSetEvaluator: Sendable {
    @MainActor
    func evaluateSceneSet(
        manifest: SceneSetManifest,
        manifestURL: URL
    ) async throws -> SceneSetManifest
}

public enum SceneSetEvaluation {
    public static func merged(
        manifest: SceneSetManifest,
        evaluated: SceneSetManifest
    ) -> SceneSetManifest {
        SceneSetManifest(
            schemaVersion: evaluated.schemaVersion,
            id: evaluated.id.isEmpty ? manifest.id : evaluated.id,
            name: evaluated.name ?? manifest.name,
            entry: manifest.entry ?? evaluated.entry,
            export: manifest.export ?? evaluated.export,
            targets: evaluated.targets,
            appearanceByTarget: evaluated.appearanceByTarget,
            theme: evaluated.theme,
            locales: evaluated.locales,
            variantGroups: evaluated.variantGroups,
            slots: evaluated.slots
        )
    }
}
