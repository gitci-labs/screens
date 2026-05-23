import Foundation

public enum ScreensRootLocator {
    public static func locate(from url: URL) throws -> URL {
        let fm = FileManager.default
        let standardized = url.standardizedFileURL

        if isScreensRoot(standardized, fileManager: fm) {
            return standardized
        }

        let nested = standardized
            .appendingPathComponent("gitci")
            .appendingPathComponent("screens")
        if isScreensRoot(nested, fileManager: fm) {
            return nested.standardizedFileURL
        }

        throw ScreensError.missingScreensRoot(standardized)
    }

    private static func isScreensRoot(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        let projectManifest = url.appendingPathComponent("project.gitci.json")
        let sceneSets = url.appendingPathComponent("scene-sets")
        return fileManager.fileExists(atPath: projectManifest.path)
            || fileManager.fileExists(atPath: sceneSets.path, isDirectory: &isDirectory)
    }
}
