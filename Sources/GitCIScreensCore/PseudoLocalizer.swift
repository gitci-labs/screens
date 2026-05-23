import Foundation

public enum PseudoLocalizer {
    public static let localeID = "qps-ploc"
    public static let localeName = "Pseudo Localization"

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
        let mapped = value.unicodeScalars.map { scalar in
            replacement(for: scalar) ?? String(scalar)
        }.joined()
        let expansionCount = max(3, Int((Double(value.count) * 0.35).rounded(.up)))
        let expansion = String(repeating: "!", count: expansionCount)
        return "[!! \(mapped) \(expansion) !!]"
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

    private static func replacement(for scalar: UnicodeScalar) -> String? {
        switch scalar.value {
        case 65: return "\u{00C0}"
        case 69: return "\u{00C8}"
        case 73: return "\u{00CC}"
        case 79: return "\u{00D2}"
        case 85: return "\u{00D9}"
        case 97: return "\u{00E1}"
        case 101: return "\u{00E9}"
        case 105: return "\u{00ED}"
        case 111: return "\u{00F3}"
        case 117: return "\u{00FA}"
        default: return nil
        }
    }
}
