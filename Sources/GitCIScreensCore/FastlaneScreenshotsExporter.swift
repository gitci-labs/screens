import Foundation

public struct FastlaneScreenshotsExporter: Sendable {
    public var buildOutputURL: URL
    public var outputURL: URL
    public var defaultLocale: String

    public init(buildOutputURL: URL, outputURL: URL, defaultLocale: String = "en-US") {
        self.buildOutputURL = buildOutputURL
        self.outputURL = outputURL
        self.defaultLocale = defaultLocale
    }

    @discardableResult
    public func export() throws -> [FastlaneScreenshot] {
        let manifestURL = buildOutputURL.appendingPathComponent("manifest.gitci-output.json")
        let manifest = try JSONDecoder.gitci.decode(
            OutputManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        var exported: [FastlaneScreenshot] = []
        for target in manifest.targets {
            for (index, screenshot) in target.screenshots.enumerated() {
                let sourceURL = buildOutputURL.appendingPathComponent(screenshot.path)
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    throw ScreensError.assetNotFound(sourceURL.path)
                }
                let localeID = screenshot.locale?.id ?? defaultLocale
                let localeDirectoryURL = outputURL.appendingPathComponent(Self.pathComponent(localeID))
                try FileManager.default.createDirectory(at: localeDirectoryURL, withIntermediateDirectories: true)

                let filename = Self.filename(targetID: target.id, screenshot: screenshot, ordinal: index + 1)
                let destinationURL = localeDirectoryURL.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                exported.append(FastlaneScreenshot(
                    localeId: localeID,
                    targetId: target.id,
                    sourcePath: screenshot.path,
                    outputPath: destinationURL.path
                ))
            }
        }
        return exported
    }

    private static func filename(
        targetID: String,
        screenshot: OutputManifestScreenshot,
        ordinal: Int
    ) -> String {
        [
            zeroPadded(ordinal),
            slug(targetID),
            slug(screenshot.slotId),
            slug(screenshot.variantId)
        ].joined(separator: "-") + ".png"
    }

    private static func zeroPadded(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let slug = String(scalars).lowercased()
        return slug.isEmpty ? "screenshot" : slug
    }

    private static func pathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let component = String(scalars)
        return component.isEmpty ? "locale" : component
    }
}

public struct FastlaneScreenshot: Codable, Equatable, Sendable {
    public var localeId: String
    public var targetId: String
    public var sourcePath: String
    public var outputPath: String
}
