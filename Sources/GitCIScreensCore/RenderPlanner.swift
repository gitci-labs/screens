import Foundation

public struct RenderPlanner: Sendable {
    public var workspace: ScreensWorkspace
    public var options: RenderPlannerOptions

    public init(workspace: ScreensWorkspace, options: RenderPlannerOptions = RenderPlannerOptions()) {
        self.workspace = workspace
        self.options = options
    }

    public func makePlan(sceneSet: LoadedSceneSet, outputDirectory: URL) throws -> RenderPlan {
        var planTargets: [RenderPlanTarget] = []
        var usedSceneTemplateIDs = Set<String>()
        let variantGroup = try resolveVariantGroup(in: sceneSet.manifest)
        let variantSelections = variantGroup?.selections ?? [:]

        for targetID in sceneSet.manifest.targets {
            guard let target = workspace.targets[targetID] else {
                throw ScreensError.unknownTarget(targetID)
            }

            let appearance = resolveAppearance(
                targetID: targetID,
                appearanceByTarget: sceneSet.manifest.appearanceByTarget
            )
            var themeVars = try resolveThemeVars(
                themeID: sceneSet.manifest.theme?.id,
                appearance: appearance
            )
            try applyPaletteMapping(
                theme: sceneSet.manifest.theme,
                appearance: appearance,
                themeVars: &themeVars
            )
            for (key, value) in sceneSet.manifest.theme?.overrides ?? [:] {
                themeVars[key] = value
            }

            var outputs: [RenderPlanOutput] = []
            var usedOutputPaths = Set<String>()

            for locale in normalizedLocales(sceneSet.manifest) {
                var localeOutputCount = 0
                for slot in sceneSet.manifest.slots {
                    guard let variant = try selectedVariant(
                        in: slot,
                        targetID: targetID,
                        variantSelections: variantSelections
                    ) else {
                        continue
                    }
                    guard let template = workspace.sceneTemplates[variant.sceneTemplate] else {
                        throw ScreensError.unknownSceneTemplate(variant.sceneTemplate)
                    }
                    try validateSupportedTarget(template: template, targetID: targetID)
                    try validateRequiredProps(template: template, props: variant.props)
                    usedSceneTemplateIDs.insert(template.id)

                    let span = SceneSpanCalculator.requiredSpan(
                        target: target,
                        constraints: template.constraints
                    )
                    let compositeWidth = SceneSpanCalculator.compositeWidth(target: target, span: span)
                    let localizedProps = try resolveLocalizedValues(in: variant.props, locale: locale)
                    let resolvedProps = try resolveAssets(
                        in: localizedProps,
                        relativeTo: sceneSet.directoryURL,
                        allowRemoteAssets: workspace.project?.assetPolicy?.allowRemoteAssets ?? false
                    )

                    for indexInSpan in 0..<span {
                        localeOutputCount += 1
                        let filename = span == 1
                            ? "\(Self.zeroPadded(localeOutputCount))-\(Self.slug(slot.id)).png"
                            : "\(Self.zeroPadded(localeOutputCount))-\(Self.slug(slot.id))-\(indexInSpan + 1).png"
                        let outputPath = Self.outputPath(targetID: target.id, locale: locale, filename: filename)
                        guard usedOutputPaths.insert(outputPath).inserted else {
                            throw ScreensError.outputCollision(outputPath)
                        }
                        outputs.append(RenderPlanOutput(
                            locale: locale.map { RenderPlanLocale(id: $0.id, name: $0.name) },
                            slotId: slot.id,
                            variantId: variant.id,
                            sceneTemplate: variant.sceneTemplate,
                            span: span,
                            compositeWidth: compositeWidth,
                            compositeHeight: target.height,
                            clip: SceneSpanCalculator.clipRect(target: target, indexInSpan: indexInSpan),
                            outputPath: outputPath,
                            props: resolvedProps
                        ))
                    }
                }

                guard localeOutputCount <= target.maxScreenshots else {
                    throw ScreensError.tooManyOutputs(
                        targetID: locale.map { "\(target.id) locale \($0.id)" } ?? target.id,
                        count: localeOutputCount,
                        max: target.maxScreenshots
                    )
                }
            }

            guard !outputs.isEmpty else {
                throw ScreensError.noOutputs(targetID: target.id)
            }

            planTargets.append(RenderPlanTarget(
                id: target.id,
                width: target.width,
                height: target.height,
                displayGapPx: target.displayGapPx,
                appearance: appearance == .automatic ? .light : appearance,
                themeVars: themeVars,
                outputs: outputs
            ))
        }

        return RenderPlan(
            schemaVersion: 1,
            buildId: "\(sceneSet.id)-\(Self.timestamp())",
            rootDirectory: workspace.rootURL.path,
            outputDirectory: outputDirectory.standardizedFileURL.path,
            assetBaseURL: workspace.rootURL.absoluteURL.absoluteString,
            sceneSet: RenderPlanSceneSet(
                id: sceneSet.id,
                name: sceneSet.manifest.name,
                variantGroup: variantGroup.map {
                    RenderPlanVariantGroup(id: $0.id, name: $0.name)
                }
            ),
            targets: planTargets,
            registry: RenderPlanRegistry(
                moduleURL: "generated:gitci.registry",
                sceneTemplates: try registryEntries(for: usedSceneTemplateIDs)
            )
        )
    }

    private func registryEntries(for templateIDs: Set<String>) throws -> [RenderPlanRegistryEntry] {
        try templateIDs.sorted().map { templateID in
            guard let template = workspace.sceneTemplates[templateID] else {
                throw ScreensError.unknownSceneTemplate(templateID)
            }
            guard let entry = template.resolvedEntry ?? template.entry, let exportName = template.exportName else {
                throw ScreensError.invalidTemplateEntry(templateID)
            }
            return RenderPlanRegistryEntry(id: template.id, entry: entry, exportName: exportName)
        }
    }

    private func resolveThemeVars(themeID: String?, appearance: Appearance) throws -> [String: String] {
        guard let themeID else {
            return try BuiltInCatalog.themeVars(themeID: nil, appearance: appearance)
        }
        guard let theme = workspace.themes[themeID] else {
            return try BuiltInCatalog.themeVars(themeID: themeID, appearance: appearance)
        }
        let resolvedAppearance = appearance == .automatic ? Appearance.light : appearance
        let key = resolvedAppearance.rawValue
        guard let vars = theme.vars[key] else {
            return try BuiltInCatalog.themeVars(themeID: themeID, appearance: appearance)
        }
        return vars
    }

    private func applyPaletteMapping(
        theme: ThemeSelection?,
        appearance: Appearance,
        themeVars: inout [String: String]
    ) throws {
        guard let paletteID = theme?.palette else {
            return
        }
        guard let palette = workspace.palettes[paletteID] else {
            throw ScreensError.unknownPalette(paletteID)
        }
        let resolvedAppearance = appearance == .automatic ? Appearance.light : appearance
        guard let colors = palette.colors[resolvedAppearance.rawValue], !colors.isEmpty else {
            throw ScreensError.paletteHasNoColors(paletteID, resolvedAppearance)
        }

        for (variable, stop) in theme?.paletteMap ?? [:] {
            themeVars[variable] = Self.colorAtStop(colors: colors, stop: stop)
        }
    }

    private func validateRequiredProps(template: SceneTemplateRecord, props: JSONValue) throws {
        let object = props.objectValue ?? [:]
        for requiredProp in template.requiredProps where object[requiredProp] == nil {
            throw ScreensError.missingRequiredProp(templateID: template.id, prop: requiredProp)
        }
    }

    private func validateSupportedTarget(template: SceneTemplateRecord, targetID: String) throws {
        guard let supportedTargets = template.supportedTargets, !supportedTargets.isEmpty else {
            return
        }
        guard supportedTargets.contains(where: { Self.matches(pattern: $0, value: targetID) }) else {
            throw ScreensError.unsupportedTemplateTarget(templateID: template.id, targetID: targetID)
        }
    }

    private func selectedVariant(
        in slot: SceneSlot,
        targetID: String,
        variantSelections: [String: String]
    ) throws -> SceneVariant? {
        if let selectedVariant = selectedVariantID(
            for: slot.id,
            targetID: targetID,
            variantSelections: variantSelections
        ) {
            guard let found = slot.variants.first(where: { $0.id == selectedVariant }) else {
                throw ScreensError.missingVariant(slotID: slot.id, variantID: selectedVariant)
            }
            return isVariant(found, includedIn: targetID) ? found : nil
        }

        if let selectedVariant = slot.selectedVariant {
            guard let found = slot.variants.first(where: { $0.id == selectedVariant }) else {
                throw ScreensError.missingVariant(slotID: slot.id, variantID: selectedVariant)
            }
            return isVariant(found, includedIn: targetID) ? found : nil
        }

        guard !slot.variants.isEmpty else {
            throw ScreensError.noVariant(slotID: slot.id)
        }
        return slot.variants.first { isVariant($0, includedIn: targetID) }
    }

    private func selectedVariantID(
        for slotID: String,
        targetID: String,
        variantSelections: [String: String]
    ) -> String? {
        let targetPrefix = "\(slotID)@"
        let targetMatches = variantSelections
            .compactMap { key, variantID -> (pattern: String, variantID: String)? in
                guard key.hasPrefix(targetPrefix) else {
                    return nil
                }
                let pattern = String(key.dropFirst(targetPrefix.count))
                return Self.matches(pattern: pattern, value: targetID)
                    ? (pattern, variantID)
                    : nil
            }
            .sorted { lhs, rhs in
                Self.patternSpecificity(lhs.pattern) > Self.patternSpecificity(rhs.pattern)
            }
        return targetMatches.first?.variantID ?? variantSelections[slotID]
    }

    private func resolveVariantGroup(in sceneSet: SceneSetManifest) throws -> SceneSetVariantGroup? {
        guard let groupID = options.variantGroupID else {
            return nil
        }
        guard let group = sceneSet.variantGroups?.first(where: { $0.id == groupID }) else {
            throw ScreensError.unknownVariantGroup(sceneSetID: sceneSet.id, groupID: groupID)
        }
        return group
    }

    private func isVariant(_ variant: SceneVariant, includedIn targetID: String) -> Bool {
        if let includeTargets = variant.includeTargets,
           !includeTargets.contains(where: { Self.matches(pattern: $0, value: targetID) }) {
            return false
        }
        if let excludeTargets = variant.excludeTargets,
           excludeTargets.contains(where: { Self.matches(pattern: $0, value: targetID) }) {
            return false
        }
        return true
    }

    private func resolveAppearance(
        targetID: String,
        appearanceByTarget: [String: Appearance]?
    ) -> Appearance {
        guard let appearanceByTarget else {
            return .light
        }
        let matches = appearanceByTarget
            .filter { pattern, _ in Self.matches(pattern: pattern, value: targetID) }
            .sorted { lhs, rhs in
                Self.patternSpecificity(lhs.key) > Self.patternSpecificity(rhs.key)
            }
        for (_, appearance) in matches {
            if appearance == .automatic, targetID.hasPrefix("appstore.") {
                return .light
            }
            return appearance
        }
        return .light
    }

    private func resolveAssets(
        in value: JSONValue,
        relativeTo sceneSetDirectory: URL,
        allowRemoteAssets: Bool
    ) throws -> JSONValue {
        try value.mapObjects { object in
            guard object["kind"]?.stringValue == "asset", let path = object["path"]?.stringValue else {
                return .object(object)
            }

            if path.hasPrefix("https://") || path.hasPrefix("http://") {
                guard allowRemoteAssets else {
                    throw ScreensError.remoteAssetDisabled(path)
                }
                var remoteObject = object
                remoteObject["resolvedURL"] = .string(path)
                return .object(remoteObject)
            }

            let resolvedURL = URL(fileURLWithPath: path, relativeTo: sceneSetDirectory)
                .standardizedFileURL
            guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
                throw ScreensError.assetNotFound(resolvedURL.path)
            }

            var resolvedObject = object
            resolvedObject["resolvedURL"] = .string(resolvedURL.absoluteString)
            return .object(resolvedObject)
        }
    }

    private func normalizedLocales(_ sceneSet: SceneSetManifest) -> [SceneSetLocale?] {
        var locales = sceneSet.locales ?? []
        let hasConfiguredLocales = !locales.isEmpty
        if options.includePseudoLocale,
           !locales.contains(where: { $0.id == PseudoLocalizer.localeID }),
           let pseudoLocale = PseudoLocalizer.locale(for: sceneSet) {
            locales.append(pseudoLocale)
        }
        guard !locales.isEmpty else {
            return [nil]
        }
        let configured = locales.map(Optional.some)
        return hasConfiguredLocales ? configured : [nil] + configured
    }

    private func resolveLocalizedValues(in value: JSONValue, locale: SceneSetLocale?) throws -> JSONValue {
        try value.mapObjects { object in
            guard object["kind"]?.stringValue == "localized" else {
                return .object(object)
            }
            guard let key = object["key"]?.stringValue else {
                return .object(object)
            }
            if let locale, let translated = locale.strings[key], !translated.isEmpty {
                return .string(translated)
            }
            if let fallback = object["fallback"]?.stringValue {
                return .string(fallback)
            }
            throw ScreensError.missingLocalizedString(
                localeID: locale?.id ?? "default",
                key: key
            )
        }
    }

    private static func outputPath(targetID: String, locale: SceneSetLocale?, filename: String) -> String {
        guard let locale else {
            return "\(targetID)/\(filename)"
        }
        return "\(pathComponent(locale.id))/\(targetID)/\(filename)"
    }

    private static func matches(pattern: String, value: String) -> Bool {
        if pattern == "*" || pattern == value {
            return true
        }
        let parts = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else {
            return false
        }

        var remainder = value[...]
        for (index, part) in parts.enumerated() where !part.isEmpty {
            guard let range = remainder.range(of: part) else {
                return false
            }
            if index == 0, !pattern.hasPrefix("*"), range.lowerBound != remainder.startIndex {
                return false
            }
            remainder = remainder[range.upperBound...]
        }

        if !pattern.hasSuffix("*"), let last = parts.last, !last.isEmpty {
            return value.hasSuffix(last)
        }
        return true
    }

    private static func patternSpecificity(_ pattern: String) -> Int {
        let wildcardPenalty = pattern.filter { $0 == "*" }.count * 1_000
        return pattern.count - wildcardPenalty
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
        return slug.isEmpty ? "scene" : slug
    }

    private static func pathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let component = String(scalars)
        return component.isEmpty ? "locale" : component
    }

    private static func colorAtStop(colors: [String], stop: Double) -> String {
        let clamped = min(1, max(0, stop))
        let index = Int((clamped * Double(colors.count - 1)).rounded())
        return colors[index]
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter.string(from: Date())
    }
}

public struct RenderPlannerOptions: Equatable, Sendable {
    public var includePseudoLocale: Bool
    public var variantGroupID: String?

    public init(includePseudoLocale: Bool = false, variantGroupID: String? = nil) {
        self.includePseudoLocale = includePseudoLocale
        self.variantGroupID = variantGroupID
    }
}
