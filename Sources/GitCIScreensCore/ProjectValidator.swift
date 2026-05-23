import Foundation

public enum DiagnosticSeverity: String, Codable, Equatable, Sendable {
    case warning
    case error
}

public struct ProjectDiagnostic: Codable, Equatable, Sendable {
    public var severity: DiagnosticSeverity
    public var code: String
    public var message: String
}

public struct ValidationReport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var sceneSetId: String
    public var diagnostics: [ProjectDiagnostic]

    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }
}

public struct ProjectValidator: Sendable {
    public var workspace: ScreensWorkspace

    public init(workspace: ScreensWorkspace) {
        self.workspace = workspace
    }

    public func validate(sceneSet: LoadedSceneSet) -> ValidationReport {
        var diagnostics: [ProjectDiagnostic] = []

        do {
            let plan = try RenderPlanner(workspace: workspace).makePlan(
                sceneSet: sceneSet,
                outputDirectory: workspace.rootURL.appendingPathComponent("build/validation")
            )
            diagnostics.append(contentsOf: warnings(for: plan))
        } catch {
            diagnostics.append(ProjectDiagnostic(
                severity: .error,
                code: "planning.failed",
                message: String(describing: error)
            ))
        }

        return ValidationReport(
            schemaVersion: 1,
            sceneSetId: sceneSet.id,
            diagnostics: diagnostics
        )
    }

    private func warnings(for plan: RenderPlan) -> [ProjectDiagnostic] {
        var warnings: [ProjectDiagnostic] = []

        for target in plan.targets {
            for output in target.outputs.prefix(3) {
                if output.props.objectValue?["headline"]?.stringValue?.isEmpty ?? true {
                    warnings.append(ProjectDiagnostic(
                        severity: .warning,
                        code: "metadata.first-three-missing-headline",
                        message: "\(target.id) \(output.outputPath) is in the first three screenshots and has no headline."
                    ))
                }
            }
        }

        return warnings
    }
}
