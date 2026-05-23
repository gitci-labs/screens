# GitCI Screens

GitCI Screens is a Swift-led toolchain for generating App Store screenshot assets from reusable React scenes. Phase 1 is intentionally small: Swift discovers a `gitci/screens` project, emits a JSON render plan, and a Node/Playwright renderer captures a bundled React scene at exact App Store pixel dimensions.

## Quickstart

```sh
swift test
swift build
cd js && pnpm install && pnpm build && cd ..
.build/debug/gitci-screens build examples/minimal
python3 scripts/check-png-size.py examples/minimal/gitci/screens/build/launch/appstore.iphone.6_9.portrait/01-hero.png 1320 2868
```

The renderer installs Playwright Chromium on first render if it is not already cached.

The minimal example writes:

```text
examples/minimal/gitci/screens/build/launch/appstore.iphone.6_9.portrait/01-hero.png
```

It also includes a project-local template pack under `examples/minimal/gitci/screens/packs/minimal` to prove that app repos can bring their own React scene templates. The `span` scene has a wide minimum aspect ratio, so the planner renders one composite scene and clips it into multiple uploadable screenshots on iPhone and iPad.

For spanned scenes, templates can use `frameRect`, `gapRect`, and `insetRect` from `@gitci/screens-react` to snap layout to upload-frame edges and avoid placing important content inside the hidden App Store-style gap.

The current built-in App Store targets are:

- `appstore.iphone.6_9.portrait` at `1320x2868`
- `appstore.ipad.13.portrait` at `2064x2752`
- `appstore.mac.16_10` at `2880x1800`

## Commands

```sh
.build/debug/gitci-screens doctor examples/minimal
.build/debug/gitci-screens doctor examples/minimal --json
.build/debug/gitci-screens discover examples/minimal --json
.build/debug/gitci-screens validate examples/minimal
.build/debug/gitci-screens plan examples/minimal --scene-set launch
.build/debug/gitci-screens build examples/minimal --scene-set launch
.build/debug/gitci-screens archive examples/minimal --scene-set launch
.build/debug/gitci-screens gallery examples/minimal --scene-set launch
.build/debug/gitci-screens init path/to/my-app --name "My App"
.build/debug/gitci-screens scene-sets create path/to/my-app --template gitci.core.basic-launch --id launch
.build/debug/gitci-screens templates install --repo gitci-labs/screens-templates --version v0.1.0 --archive path/to/screens-templates-v0.1.0.tar.gz
.build/debug/gitci-screens templates list
```

You can also run the packaged Docker image once it has been published:

```sh
docker run --rm -v "$PWD":/workspace ghcr.io/gitci-labs/screens:main build /workspace/examples/minimal
```

By convention, a project has a `gitci/screens` directory containing `project.gitci.json`, assets, and one or more `scene-sets`.

Projects can declare reusable template roots in `project.gitci.json` with local `sources`; packaged installs can also provide `GITCI_SCREENS_TEMPLATES_ROOT`.

Release archives use a `bin/gitci-screens` plus `share/gitci-screens` layout. The CLI also honors `GITCI_SCREENS_HOME` when you want to point a copied binary at a specific renderer/templates bundle.

Template releases can be cached with `templates install` and inspected with `templates list --json`. By default the CLI stores archives under `~/.gitci/screens/templates/<repo-name>/<version>/`, which matches `githubRelease` source discovery. Use `GITCI_SCREENS_TEMPLATE_CACHE_ROOT` to point install, listing, and discovery at another cache directory.

To build the release archive layout locally:

```sh
mise run package-local
```

`init` writes a placeholder SVG screenshot so the generated project can be validated and rendered immediately. Replace `gitci/screens/assets/iphone/screenshot.svg` with a real app screenshot when you are ready. `scene-sets create` instantiates a reusable scene set template into the project and writes placeholder SVG assets for any missing `.svg` asset references.

`build` writes `manifest.gitci-output.json` next to the render plan. The output manifest includes each screenshot's target dimensions plus span, span index, composite canvas, display gap, and clip rectangle metadata so galleries and future editors can reconstruct wide scenes precisely. `archive` zips an existing scene-set build directory for CI artifacts or sharing. `gallery` writes a static HTML index under the selected scene set build directory.

## Current Scope

Implemented:

- SwiftPM package with `GitCIScreensCore` and `gitci-screens`
- versioned JSON project and scene-set manifests
- built-in iPhone, iPad, and Mac App Store target profiles
- target-aware scene variants
- scene span and clip math
- palette-mapped theme variables with explicit overrides
- one built-in React scene template: `gitci.core.hero-device`
- one feature scene template: `gitci.core.feature-closeup`
- project-local scene template packs rendered through generated Vite registry bundles
- CSS 2D device frame plus an experimental React Three Fiber 3D device component
- output manifests and a minimal static gallery
- file-backed pack, component, theme, palette, target, scene-template, and scene-set-template manifests
- JSON Schema files with AJV tests against the bundled example and core pack
- deterministic Playwright rendering with `deviceScaleFactor = 1`, CSS-pixel screenshots, and disabled animations

Not implemented yet:

- arbitrary remote template repositories
- TypeScript scene-set execution as the authoritative source
- native SwiftUI app
- browser/WASM build

## Repo Map

- [`gitci-labs/screens`](https://github.com/gitci-labs/screens): CLI, Swift core, JS renderer, schemas, Docker, CI, and bundled bootstrap templates.
- [`gitci-labs/screens-templates`](https://github.com/gitci-labs/screens-templates): canonical reusable template packs and target definitions.
- [`gitci-labs/screens-demos`](https://github.com/gitci-labs/screens-demos): public demo projects with fake screenshots.
- `gitci-labs/gitci-dev`: private meta repo with submodules and product specs.
- `gitci-labs/screens-app`: private native Apple app.
- `gitci-labs/screens-internal-assets`: private asset storage.

## References

- [Architecture](docs/architecture.md)
- [Schemas](docs/schema.md)
- [Targets](docs/targets.md)
- [Template authoring](docs/authoring-templates.md)
