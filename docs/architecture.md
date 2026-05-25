# Architecture

GitCI Screens separates planning from rendering.

Swift owns deterministic, inspectable build planning:

- locating `gitci/screens`
- decoding versioned manifests
- resolving scene sets, targets, assets, themes, and appearance
- calculating scene spans and output clip rectangles
- writing render and output manifests

React owns visual layout:

- responsive scene templates
- CSS variables
- device frames
- future Three.js and anime.js composition

The boundary for final rendering is `plan.gitci-render.json`. The renderer should not rediscover project files; it receives the full output plan and fails if a referenced template or asset is unavailable.

The boundary for authoring is an evaluated scene-set model. A `scene-set.gitci.json` file may be only an index with `id`, `entry`, and `export`; Swift asks a `SceneSetEvaluator` to materialize the authored TSX into a `SceneSetManifest` before validation. The sandbox app evaluator runs the authoring bundle in WebView with `esbuild-wasm`, so Swift can reason about React-authored scene sets without a Node process or a redundant JSON copy.

Native editing is driven by `EditableSceneSetDocument` and `SceneSetEdit`. SwiftUI forms and WYSIWYG controls patch stable slot/variant/prop paths, the preview updates from the edited model, and source syncing can rewrite the TSX as a separate transaction. See `docs/live-editor.md` for the two-way sync model.

The authoritative renderer is Node + Playwright + Chromium. The current renderer uses exact viewport dimensions, `deviceScaleFactor = 1`, CSS-pixel screenshot scaling, disabled animations, hidden carets, and clip rectangles for multi-frame scene spans.

When a render plan references scene template entries, the Node renderer generates a small registry module and builds it with Vite before launching Playwright. This keeps Swift out of React execution while still allowing local app repos to define their own `gitci/screens/packs/.../template.tsx` scene templates.

`manifest.gitci-output.json` is the post-build index for consumers. It records the screenshot order, locale, final dimensions, display gap, span count, span index, composite scene size, and clip rectangle for every output. Wide scenes can therefore be reconstructed in a gallery or editor without guessing where upload frames and hidden gaps were. The `fastlane` command consumes the same manifest to copy PNGs into `fastlane/screenshots/<locale>/...` for App Store Connect upload pipelines.

Packaged environments can set:

- `GITCI_SCREENS_HOME`
- `GITCI_SCREENS_JS_WORKSPACE`
- `GITCI_SCREENS_TEMPLATE_CACHE_ROOT`
- `GITCI_SCREENS_TEMPLATES_ROOT`

Release archives place the executable in `bin/` and runtime files under `share/gitci-screens/`. The CLI checks that layout automatically. The Docker image uses explicit environment variables so a mounted app repo does not need to contain the renderer source.

Future renderers should keep the same plan contract:

- `node-playwright`
- `web-live-preview`
- `wkwebview-snapshot`
- `future-video`

Remote template repositories are executable code. Browser demos must not run arbitrary remote template JavaScript in the main origin. The safe default is official demos only, then sandboxed iframes or CI-backed rendering later.
