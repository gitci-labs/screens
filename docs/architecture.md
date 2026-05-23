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

The boundary is `plan.gitci-render.json`. The renderer should not rediscover project files; it receives the full output plan and fails if a referenced template or asset is unavailable.

The authoritative renderer is Node + Playwright + Chromium. The current renderer uses exact viewport dimensions, `deviceScaleFactor = 1`, CSS-pixel screenshot scaling, disabled animations, hidden carets, and clip rectangles for multi-frame scene spans.

When a render plan references scene template entries, the Node renderer generates a small registry module and builds it with Vite before launching Playwright. This keeps Swift out of React execution while still allowing local app repos to define their own `gitci/screens/packs/.../template.tsx` scene templates.

Packaged environments can set:

- `GITCI_SCREENS_JS_WORKSPACE`
- `GITCI_SCREENS_TEMPLATES_ROOT`

The Docker image uses these so a mounted app repo does not need to contain the renderer source.

Future renderers should keep the same plan contract:

- `node-playwright`
- `web-live-preview`
- `wkwebview-snapshot`
- `future-video`

Remote template repositories are executable code. Browser demos must not run arbitrary remote template JavaScript in the main origin. The safe default is official demos only, then sandboxed iframes or CI-backed rendering later.
