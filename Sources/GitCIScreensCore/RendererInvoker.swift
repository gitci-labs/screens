import Foundation

public struct RendererInvoker: Sendable {
    public var renderer: String

    public init(renderer: String) {
        self.renderer = renderer
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
        let jsWorkspace = try Self.findJSWorkspace()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "pnpm",
            "--dir",
            jsWorkspace.path,
            "render",
            "--",
            "--plan",
            planURL.path
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ScreensError.rendererFailed(process.terminationStatus)
        }
    }

    public static func findJSWorkspace(startingAt start: URL? = nil) throws -> URL {
        let fm = FileManager.default
        if let override = ProcessInfo.processInfo.environment["GITCI_SCREENS_JS_WORKSPACE"] {
            let overrideURL = URL(fileURLWithPath: override).standardizedFileURL
            if fm.fileExists(atPath: overrideURL.appendingPathComponent("package.json").path) {
                return overrideURL
            }
        }
        let packagedURL = URL(fileURLWithPath: "/opt/gitci-screens/js")
        if fm.fileExists(atPath: packagedURL.appendingPathComponent("package.json").path) {
            return packagedURL
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
