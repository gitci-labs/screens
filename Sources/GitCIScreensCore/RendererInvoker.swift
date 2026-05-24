import Foundation

public struct RendererInvoker: Sendable {
    public var renderer: String
    public var failOnOverflow: Bool
    public var jsWorkspaceURL: URL?

    public init(renderer: String, failOnOverflow: Bool = false, jsWorkspaceURL: URL? = nil) {
        self.renderer = renderer
        self.failOnOverflow = failOnOverflow
        self.jsWorkspaceURL = jsWorkspaceURL
    }

    public func render(planURL: URL) async throws {
        switch renderer {
        case "node-playwright":
            try await runNodePlaywright(planURL: planURL)
        default:
            throw ScreensError.unsupportedRenderer(renderer)
        }
    }

    private func runNodePlaywright(planURL: URL) async throws {
        #if os(macOS)
        let jsWorkspace = if let jsWorkspaceURL {
            jsWorkspaceURL.standardizedFileURL
        } else {
            try Self.findJSWorkspace()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var arguments = [
            "pnpm",
            "--dir",
            jsWorkspace.path,
            "render",
            "--",
            "--plan",
            planURL.path
        ]
        if failOnOverflow {
            arguments.append("--fail-on-overflow")
        }
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ScreensError.rendererFailed(process.terminationStatus)
        }
        #else
        _ = planURL
        throw ScreensError.unsupportedRenderer("node-playwright")
        #endif
    }

    public static func findJSWorkspace(
        startingAt start: URL? = nil,
        executableURL: URL? = Bundle.main.executableURL
    ) throws -> URL {
        let fm = FileManager.default
        if let override = ProcessInfo.processInfo.environment["GITCI_SCREENS_JS_WORKSPACE"] {
            let overrideURL = URL(fileURLWithPath: override).standardizedFileURL
            if fm.fileExists(atPath: overrideURL.appendingPathComponent("package.json").path) {
                return overrideURL
            }
        }
        for root in InstallationPaths.resourceRoots(executableURL: executableURL) {
            let candidate = root.appendingPathComponent("js")
            if fm.fileExists(atPath: candidate.appendingPathComponent("package.json").path) {
                return candidate.standardizedFileURL
            }
        }
        var current = (start ?? URL(fileURLWithPath: fm.currentDirectoryPath)).standardizedFileURL

        while true {
            let candidate = current.appendingPathComponent("js")
            if fm.fileExists(atPath: candidate.appendingPathComponent("package.json").path) {
                return candidate
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                throw ScreensError.jsWorkspaceNotFound(start ?? current)
            }
            current = parent
        }
    }

    public static func verifyNodePlaywrightRenderer(jsWorkspace: URL) throws {
        let rendererPath = jsWorkspace
            .appendingPathComponent("packages")
            .appendingPathComponent("renderer-node")
            .appendingPathComponent("dist")
            .appendingPathComponent("render.js")
        let harnessPath = jsWorkspace
            .appendingPathComponent("apps")
            .appendingPathComponent("renderer-harness")
            .appendingPathComponent("dist")
            .appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: rendererPath.path) else {
            throw ScreensError.rendererNotBuilt(rendererPath.path)
        }
        guard FileManager.default.fileExists(atPath: harnessPath.path) else {
            throw ScreensError.rendererNotBuilt(harnessPath.path)
        }
    }
}
