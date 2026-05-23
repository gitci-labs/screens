import Foundation

public enum InstallationPaths {
    public static func resourceRoots(executableURL: URL? = Bundle.main.executableURL) -> [URL] {
        var roots: [URL] = []

        if let override = ProcessInfo.processInfo.environment["GITCI_SCREENS_HOME"], !override.isEmpty {
            roots.append(URL(fileURLWithPath: override).standardizedFileURL)
        }

        roots.append(URL(fileURLWithPath: "/opt/gitci-screens"))

        if let executableURL {
            let binURL = executableURL.standardizedFileURL.deletingLastPathComponent()
            let prefixURL = binURL.deletingLastPathComponent()
            roots.append(
                prefixURL
                    .appendingPathComponent("share")
                    .appendingPathComponent("gitci-screens")
                    .standardizedFileURL
            )
            roots.append(
                binURL
                    .appendingPathComponent("share")
                    .appendingPathComponent("gitci-screens")
                    .standardizedFileURL
            )
        }

        var seen = Set<String>()
        return roots.filter { root in
            seen.insert(root.path).inserted
        }
    }
}
