import Foundation

public enum OverflowLocalizer {
    public static let localeID = "qps-overflow"
    public static let localeName = "Overflow Stress"

    public static func locale(for sceneSet: SceneSetManifest) -> SceneSetLocale? {
        var strings: [String: String] = [:]

        for slot in sceneSet.slots {
            for variant in slot.variants {
                collectLocalizedStrings(from: variant.props, into: &strings)
            }
        }

        guard !strings.isEmpty else {
            return nil
        }
        return SceneSetLocale(id: localeID, name: localeName, strings: strings)
    }

    public static func transform(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Overflow stress string" : trimmed
        let targetLength = max(96, Int((Double(base.count) * 2.75).rounded(.up)))
        var parts: [String] = []
        var length = 0
        while length < targetLength {
            parts.append(base)
            length += base.count + 3
        }
        return parts.joined(separator: " / ")
    }

    private static func collectLocalizedStrings(from value: JSONValue, into strings: inout [String: String]) {
        switch value {
        case let .object(object):
            if object["kind"]?.stringValue == "localized", let key = object["key"]?.stringValue {
                let fallback = object["fallback"]?.stringValue ?? key
                strings[key] = transform(fallback)
                return
            }
            for child in object.values {
                collectLocalizedStrings(from: child, into: &strings)
            }
        case let .array(array):
            for child in array {
                collectLocalizedStrings(from: child, into: &strings)
            }
        case .string, .number, .bool, .null:
            return
        }
    }
}
