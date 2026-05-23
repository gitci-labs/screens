import Foundation

public struct GalleryGenerator: Sendable {
    public var workspace: ScreensWorkspace

    public init(workspace: ScreensWorkspace) {
        self.workspace = workspace
    }

    public func generate(outputURL: URL, buildOutputURL: URL? = nil) throws {
        let dataURL = outputURL.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)

        let sceneSets = workspace.sceneSets.map {
            GallerySceneSet(id: $0.id, name: $0.manifest.name, slots: $0.manifest.slots.map(\.id))
        }
        try JSONEncoder.gitci.encode(sceneSets).write(to: dataURL.appendingPathComponent("scene-sets.json"))
        try JSONEncoder.gitci.encode(workspace.targets.values.sorted { $0.id < $1.id })
            .write(to: dataURL.appendingPathComponent("targets.json"))
        try JSONEncoder.gitci.encode(workspace.sceneTemplates.values.sorted { $0.id < $1.id })
            .write(to: dataURL.appendingPathComponent("scene-templates.json"))
        try JSONEncoder.gitci.encode(workspace.sceneSetTemplates.values.sorted { $0.id < $1.id })
            .write(to: dataURL.appendingPathComponent("scene-set-templates.json"))
        try JSONEncoder.gitci.encode(workspace.packs)
            .write(to: dataURL.appendingPathComponent("packs.json"))
        try JSONEncoder.gitci.encode(workspace.components.values.sorted { $0.id < $1.id })
            .write(to: dataURL.appendingPathComponent("components.json"))
        try JSONEncoder.gitci.encode(workspace.palettes.values.sorted { $0.id < $1.id })
            .write(to: dataURL.appendingPathComponent("palettes.json"))
        try JSONEncoder.gitci.encode(workspace.themes.values.sorted { $0.id < $1.id })
            .write(to: dataURL.appendingPathComponent("themes.json"))

        let builtOutputs = try loadBuiltOutputs(buildOutputURL: buildOutputURL)
        try JSONEncoder.gitci.encode(builtOutputs)
            .write(to: dataURL.appendingPathComponent("built-outputs.json"))

        try Self.html(
            sceneSets: sceneSets,
            builtOutputs: builtOutputs,
            packs: workspace.packs,
            sceneTemplates: workspace.sceneTemplates.values.sorted { $0.id < $1.id },
            sceneSetTemplates: workspace.sceneSetTemplates.values.sorted { $0.id < $1.id },
            components: workspace.components.values.sorted { $0.id < $1.id },
            palettes: workspace.palettes.values.sorted { $0.id < $1.id },
            themes: workspace.themes.values.sorted { $0.id < $1.id },
            targets: workspace.targets.values.sorted { $0.id < $1.id }
        )
            .write(to: outputURL.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    }

    private func loadBuiltOutputs(buildOutputURL: URL?) throws -> [GalleryBuiltOutput] {
        guard let buildOutputURL else {
            return []
        }
        let manifestURL = buildOutputURL.appendingPathComponent("manifest.gitci-output.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }
        let manifest = try JSONDecoder.gitci.decode(OutputManifest.self, from: Data(contentsOf: manifestURL))
        return manifest.targets.flatMap { target in
            target.screenshots.enumerated().map { index, screenshot in
                GalleryBuiltOutput(
                    variantGroupId: manifest.sceneSet.variantGroup?.id,
                    variantGroupName: manifest.sceneSet.variantGroup?.name,
                    localeId: screenshot.locale?.id,
                    localeName: screenshot.locale?.name,
                    targetId: target.id,
                    screenshotIndex: index + 1,
                    isFirstThree: index < 3,
                    slotId: screenshot.slotId,
                    variantId: screenshot.variantId,
                    path: screenshot.path,
                    width: screenshot.width,
                    height: screenshot.height,
                    displayGapPx: target.displayGapPx,
                    span: screenshot.span,
                    spanIndex: screenshot.spanIndex,
                    compositeWidth: screenshot.compositeWidth,
                    compositeHeight: screenshot.compositeHeight,
                    clip: screenshot.clip
                )
            }
        }
    }

    private static func html(
        sceneSets: [GallerySceneSet],
        builtOutputs: [GalleryBuiltOutput],
        packs: [PackManifest],
        sceneTemplates: [SceneTemplateRecord],
        sceneSetTemplates: [SceneSetTemplateManifest],
        components: [ComponentManifest],
        palettes: [PaletteManifest],
        themes: [ThemeManifest],
        targets: [TargetProfile]
    ) -> String {
        let sceneSetCards = sceneSets.map {
            """
            <article class="card">
              <h3>\(escape($0.name ?? $0.id))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>\($0.slots.count) slots: \(escape($0.slots.joined(separator: ", ")))</p>
            </article>
            """
        }.joined(separator: "\n")
        let packCards = packs.map {
            """
            <article class="card">
              <h3>\(escape($0.name))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>\(escape($0.summary ?? "Reusable GitCI Screens pack."))</p>
              <small>\(escape(($0.tags ?? []).joined(separator: ", ")))</small>
            </article>
            """
        }.joined(separator: "\n")
        let templateCards = sceneTemplates.map {
            """
            <article class="card">
              <h3>\(escape($0.name))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>Pack: \(escape($0.pack ?? "local"))</p>
              <p>Min aspect: \(format($0.constraints.minAspectRatio))</p>
              <small>\(escape(($0.tags ?? []).joined(separator: ", ")))</small>
            </article>
            """
        }.joined(separator: "\n")
        let sceneSetTemplateCards = sceneSetTemplates.map {
            let slotCount = $0.sceneSet.slots.count
            let targetCount = $0.sceneSet.targets.count
            return """
            <article class="card">
              <h3>\(escape($0.name))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>\(escape($0.summary ?? "Reusable scene set template."))</p>
              <p>\(slotCount) slots, \(targetCount) targets</p>
              <small>\(escape(($0.tags ?? []).joined(separator: ", ")))</small>
            </article>
            """
        }.joined(separator: "\n")
        let componentCards = components.map {
            """
            <article class="card">
              <h3>\(escape($0.name))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>Category: \(escape($0.category ?? "component"))</p>
              <small>\(escape(($0.tags ?? []).joined(separator: ", ")))</small>
            </article>
            """
        }.joined(separator: "\n")
        let paletteCards = palettes.map { palette in
            let light = swatches(colors: palette.colors["light"] ?? [])
            let dark = swatches(colors: palette.colors["dark"] ?? [])
            return """
            <article class="card">
              <h3>\(escape(palette.name))</h3>
              <p><code>\(escape(palette.id))</code></p>
              <div class="swatches">\(light)</div>
              <div class="swatches dark">\(dark)</div>
            </article>
            """
        }.joined(separator: "\n")
        let themeCards = themes.map {
            """
            <article class="card">
              <h3>\(escape($0.name))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>Light vars: \($0.vars["light"]?.count ?? 0)</p>
              <p>Dark vars: \($0.vars["dark"]?.count ?? 0)</p>
            </article>
            """
        }.joined(separator: "\n")
        let targetCards = targets.map {
            """
            <article class="card">
              <h3>\(escape($0.displayName))</h3>
              <p><code>\(escape($0.id))</code></p>
              <p>\($0.width)x\($0.height) \(escape($0.orientation))</p>
              <p>Max screenshots: \($0.maxScreenshots)</p>
            </article>
            """
        }.joined(separator: "\n")
        let targetControls = filterButtons(
            label: "Targets",
            attribute: "target",
            values: Set(builtOutputs.map(\.targetId)).sorted()
        )
        let localeControls = filterButtons(
            label: "Locales",
            attribute: "locale",
            values: Set(builtOutputs.map { $0.localeId ?? "default" }).sorted()
        )
        let variantGroupControls = filterButtons(
            label: "Variant groups",
            attribute: "variant-group",
            values: Set(builtOutputs.map { $0.variantGroupId ?? "default" }).sorted()
        )
        let groupedOutputs = Dictionary(grouping: builtOutputs) { output in
            "\(output.variantGroupId ?? "default")|\(output.localeId ?? "default")|\(output.targetId)"
        }
            .sorted { $0.key < $1.key }
            .map { _, outputs in
                let first = outputs[0]
                let headingParts = [
                    first.variantGroupName ?? first.variantGroupId,
                    first.localeId,
                    first.targetId
                ].compactMap { $0 }
                let heading = headingParts.joined(separator: " / ")
                let displayGap = outputs.first.map { output in
                    max(6, min(40, Int(round(Double(output.displayGapPx) * 220.0 / Double(output.width)))))
                } ?? 28
                let cards = outputs.map { output in
                    let firstThreeLabel = output.isFirstThree
                        ? "<small class=\"priority\">Search/result slot \(output.screenshotIndex)</small>"
                        : ""
                    let spanLabel = output.span > 1
                        ? "<small>Span \(output.spanIndex + 1)/\(output.span), clip x=\(output.clip.x), gap=\(output.displayGapPx)</small>"
                        : "<small>Single frame, clip x=\(output.clip.x)</small>"
                    let variantGroupLabel = output.variantGroupId.map {
                        "<small>Variant group: \(escape($0))</small>"
                    } ?? ""
                    return """
                    <a class="shot" href="../\(escapeAttribute(output.path))">
                      <img src="../\(escapeAttribute(output.path))" alt="\(escapeAttribute(output.path))">
                      <span><strong>\(escape(output.slotId))</strong> / \(escape(output.variantId))</span>
                      <span>\(escape(output.path))</span>
                      \(firstThreeLabel)
                      <small>\(String(output.width))x\(String(output.height))</small>
                      \(variantGroupLabel)
                      \(spanLabel)
                    </a>
                    """
                }.joined(separator: "\n")
                return """
                <section class="target output-group" data-target="\(escapeAttribute(first.targetId))" data-locale="\(escapeAttribute(first.localeId ?? "default"))" data-variant-group="\(escapeAttribute(first.variantGroupId ?? "default"))">
                  <h3>\(escape(heading))</h3>
                  <div class="strip" style="gap: \(displayGap)px">\(cards)</div>
                </section>
                """
            }
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>GitCI Screens Gallery</title>
          <style>
            body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, sans-serif; color: #111827; background: #f8fafc; }
            main { max-width: 1180px; margin: 0 auto; padding: 56px 28px; }
            h1 { margin: 0 0 8px; font-size: 44px; line-height: 1; letter-spacing: 0; }
            h2 { margin-top: 42px; font-size: 24px; }
            h3 { margin: 24px 0 12px; font-size: 18px; }
            ul { padding-left: 20px; line-height: 1.7; }
            code { background: #e2e8f0; padding: 2px 6px; border-radius: 6px; }
            a { color: #2563eb; }
            .filters { display: flex; flex-wrap: wrap; gap: 14px; margin: 18px 0 22px; }
            .filter-group { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
            .filter-group strong { font-size: 13px; color: #334155; }
            .filter-button { border: 1px solid #cbd5e1; border-radius: 999px; background: #fff; color: #334155; padding: 6px 10px; font: inherit; font-size: 13px; cursor: pointer; }
            .filter-button[aria-pressed="true"] { background: #0f172a; color: #fff; border-color: #0f172a; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; }
            .card { border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; padding: 18px; box-shadow: 0 12px 30px rgb(15 23 42 / 0.06); }
            .card h3 { margin: 0 0 10px; }
            .card p { margin: 8px 0; color: #475569; }
            .card small { color: #64748b; }
            .swatches { display: flex; height: 28px; margin-top: 10px; overflow: hidden; border-radius: 6px; border: 1px solid #e2e8f0; }
            .swatches span { flex: 1; }
            .target { margin-top: 20px; }
            .strip { display: flex; gap: 28px; overflow-x: auto; padding: 6px 0 22px; }
            .shot { flex: 0 0 220px; color: inherit; text-decoration: none; }
            .shot img { display: block; width: 220px; height: 320px; object-fit: contain; object-position: top center; border-radius: 8px; background: #e2e8f0; box-shadow: 0 18px 44px rgb(15 23 42 / 0.16); }
            .shot span { display: block; margin-top: 10px; font-size: 13px; overflow-wrap: anywhere; }
            .shot small { display: block; margin-top: 4px; color: #64748b; }
            .shot .priority { display: inline-block; color: #92400e; background: #fef3c7; border: 1px solid #fde68a; border-radius: 999px; padding: 3px 8px; }
            .is-hidden { display: none; }
          </style>
        </head>
        <body>
          <main>
            <h1>GitCI Screens Gallery</h1>
            <p>Static index for discovered scene sets, reusable packs, target profiles, palettes, themes, and generated outputs.</p>
            <h2>Scene Sets</h2>
            <div class="grid">\(sceneSetCards)</div>
            <h2>Built Outputs</h2>
            <p>The first three generated screenshots for each locale and target are highlighted because they can be the most visible store slots.</p>
            \(builtOutputs.isEmpty ? "" : "<div class=\"filters\">\(targetControls)\(localeControls)\(variantGroupControls)</div>")
            \(groupedOutputs.isEmpty ? "<p>No built output manifest found.</p>" : groupedOutputs)
            <h2>Packs</h2>
            <div class="grid">\(packCards)</div>
            <h2>Scene Templates</h2>
            <div class="grid">\(templateCards)</div>
            <h2>Scene Set Templates</h2>
            <div class="grid">\(sceneSetTemplateCards)</div>
            <h2>Components</h2>
            <div class="grid">\(componentCards)</div>
            <h2>Palettes</h2>
            <div class="grid">\(paletteCards)</div>
            <h2>Themes</h2>
            <div class="grid">\(themeCards)</div>
            <h2>Targets</h2>
            <div class="grid">\(targetCards)</div>
            <h2>Data</h2>
            <ul>
              <li><a href="data/scene-sets.json">scene-sets.json</a></li>
              <li><a href="data/packs.json">packs.json</a></li>
              <li><a href="data/scene-templates.json">scene-templates.json</a></li>
              <li><a href="data/scene-set-templates.json">scene-set-templates.json</a></li>
              <li><a href="data/components.json">components.json</a></li>
              <li><a href="data/palettes.json">palettes.json</a></li>
              <li><a href="data/themes.json">themes.json</a></li>
              <li><a href="data/targets.json">targets.json</a></li>
              <li><a href="data/built-outputs.json">built-outputs.json</a></li>
            </ul>
          </main>
          <script>
            const activeFilters = { target: 'all', locale: 'all', 'variant-group': 'all' };
            function applyFilters() {
              document.querySelectorAll('.output-group').forEach((group) => {
                const visible = Object.entries(activeFilters).every(([key, value]) => value === 'all' || group.getAttribute(`data-${key}`) === value);
                group.classList.toggle('is-hidden', !visible);
              });
            }
            document.querySelectorAll('.filter-button').forEach((button) => {
              button.addEventListener('click', () => {
                const key = button.dataset.filter;
                const value = button.dataset.value;
                activeFilters[key] = value;
                document.querySelectorAll(`.filter-button[data-filter="${key}"]`).forEach((peer) => {
                  peer.setAttribute('aria-pressed', String(peer === button));
                });
                applyFilters();
              });
            });
          </script>
        </body>
        </html>
        """
    }

    private static func filterButtons(label: String, attribute: String, values: [String]) -> String {
        guard !values.isEmpty else {
            return ""
        }
        let options = (["all"] + values).map { value in
            let title = value == "all" ? "All" : value
            return """
            <button class="filter-button" type="button" data-filter="\(escapeAttribute(attribute))" data-value="\(escapeAttribute(value))" aria-pressed="\(value == "all" ? "true" : "false")">\(escape(title))</button>
            """
        }.joined(separator: "\n")
        return """
        <div class="filter-group">
          <strong>\(escape(label))</strong>
          \(options)
        </div>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escape(value).replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func swatches(colors: [String]) -> String {
        colors.map { color in
            "<span title=\"\(escapeAttribute(color))\" style=\"background: \(escapeAttribute(color))\"></span>"
        }.joined()
    }

    private static func format(_ value: Double?) -> String {
        guard let value else {
            return "none"
        }
        return String(format: "%.2f", value)
    }
}

public struct GallerySceneSet: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var slots: [String]
}

public struct GalleryBuiltOutput: Codable, Equatable, Sendable {
    public var variantGroupId: String?
    public var variantGroupName: String?
    public var localeId: String?
    public var localeName: String?
    public var targetId: String
    public var screenshotIndex: Int
    public var isFirstThree: Bool
    public var slotId: String
    public var variantId: String
    public var path: String
    public var width: Int
    public var height: Int
    public var displayGapPx: Int
    public var span: Int
    public var spanIndex: Int
    public var compositeWidth: Int
    public var compositeHeight: Int
    public var clip: ClipRect
}
