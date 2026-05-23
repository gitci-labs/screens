import Foundation

public enum DiagnosticSeverity: String, Codable, Equatable, Sendable {
    case warning
    case error
}

public struct ProjectDiagnostic: Codable, Equatable, Sendable {
    public var severity: DiagnosticSeverity
    public var code: String
    public var message: String
    public var targetId: String?
    public var outputPath: String?
    public var assetPath: String?
    public var sourceId: String?

    public init(
        severity: DiagnosticSeverity,
        code: String,
        message: String,
        targetId: String? = nil,
        outputPath: String? = nil,
        assetPath: String? = nil,
        sourceId: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.targetId = targetId
        self.outputPath = outputPath
        self.assetPath = assetPath
        self.sourceId = sourceId
    }
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
    public var options: RenderPlannerOptions

    public init(workspace: ScreensWorkspace, options: RenderPlannerOptions = RenderPlannerOptions()) {
        self.workspace = workspace
        self.options = options
    }

    public func validate(sceneSet: LoadedSceneSet) -> ValidationReport {
        var diagnostics: [ProjectDiagnostic] = []

        do {
            let plan = try RenderPlanner(workspace: workspace, options: options).makePlan(
                sceneSet: sceneSet,
                outputDirectory: workspace.rootURL.appendingPathComponent("build/validation")
            )
            diagnostics.append(contentsOf: warnings(for: plan))
            diagnostics.append(contentsOf: warningsForProjectSources())
        } catch {
            diagnostics.append(Self.diagnostic(for: error))
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
            if !targetAcceptedSizeMatches(target) {
                warnings.append(ProjectDiagnostic(
                    severity: .warning,
                    code: "target.output-size-not-accepted",
                    message: "\(target.id) renders \(target.width)x\(target.height), which is not listed in acceptedSizes.",
                    targetId: target.id
                ))
            }
            let outputsByLocale = Dictionary(grouping: target.outputs) { output in
                output.locale?.id ?? ""
            }
            for localeID in outputsByLocale.keys.sorted() {
                for output in (outputsByLocale[localeID] ?? []).prefix(3) {
                    if output.props.objectValue?["headline"]?.stringValue?.isEmpty ?? true {
                        warnings.append(ProjectDiagnostic(
                            severity: .warning,
                            code: "metadata.first-three-missing-headline",
                            message: "\(target.id) \(output.outputPath) is in the first three screenshots and has no headline.",
                            targetId: target.id,
                            outputPath: output.outputPath
                        ))
                    }
                }
            }
        }

        return warnings
    }

    private func warningsForProjectSources() -> [ProjectDiagnostic] {
        (workspace.project?.sources ?? []).compactMap { source in
            guard source.kind != "local", source.kind != "githubRelease" else {
                return nil
            }
            return ProjectDiagnostic(
                severity: .warning,
                code: "project.source-unsupported",
                message: "Project source \(source.id) uses unsupported kind \(source.kind); supported source kinds are local and githubRelease.",
                sourceId: source.id
            )
        }
    }

    private func targetAcceptedSizeMatches(_ target: RenderPlanTarget) -> Bool {
        guard let profile = workspace.targets[target.id], !profile.acceptedSizes.isEmpty else {
            return true
        }
        return profile.acceptedSizes.contains([target.width, target.height])
    }

    private static func diagnostic(for error: Error) -> ProjectDiagnostic {
        guard let screensError = error as? ScreensError else {
            return ProjectDiagnostic(
                severity: .error,
                code: "planning.failed",
                message: String(describing: error)
            )
        }

        switch screensError {
        case let .unknownTarget(targetID):
            return ProjectDiagnostic(
                severity: .error,
                code: "target.unknown",
                message: screensError.description,
                targetId: targetID
            )
        case let .assetNotFound(path):
            return ProjectDiagnostic(
                severity: .error,
                code: "asset.not-found",
                message: screensError.description,
                assetPath: path
            )
        case let .remoteAssetDisabled(url):
            return ProjectDiagnostic(
                severity: .error,
                code: "asset.remote-disabled",
                message: screensError.description,
                assetPath: url
            )
        case let .missingLocalizedString(localeID, _):
            return ProjectDiagnostic(
                severity: .error,
                code: "locale.string-missing",
                message: screensError.description,
                sourceId: localeID
            )
        case let .templateSourceNotFound(sourceID, path):
            return ProjectDiagnostic(
                severity: .error,
                code: "project.source-not-found",
                message: screensError.description,
                outputPath: path,
                sourceId: sourceID
            )
        case let .unknownVariantGroup(_, groupID):
            return ProjectDiagnostic(
                severity: .error,
                code: "variant-group.unknown",
                message: screensError.description,
                sourceId: groupID
            )
        case let .projectSourceMissingPath(sourceID):
            return ProjectDiagnostic(
                severity: .error,
                code: "project.source-missing-path",
                message: screensError.description,
                sourceId: sourceID
            )
        case let .noOutputs(targetID):
            return ProjectDiagnostic(
                severity: .error,
                code: "target.no-outputs",
                message: screensError.description,
                targetId: targetID
            )
        case let .tooManyOutputs(targetID, _, _):
            return ProjectDiagnostic(
                severity: .error,
                code: "target.too-many-outputs",
                message: screensError.description,
                targetId: targetID
            )
        default:
            return ProjectDiagnostic(
                severity: .error,
                code: "planning.failed",
                message: screensError.description
            )
        }
    }
}
