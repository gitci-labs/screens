# Authoring Templates

Templates are React components registered by id. The bundled core pack currently provides:

- `gitci.core.hero-device`
- `gitci.core.feature-closeup`

The Swift planner only needs a manifest-level template id and constraints. The renderer resolves the id through a registry.

Scene templates receive:

- `props`: user-provided content such as screenshots and copy
- `context`: target dimensions, appearance, theme vars, span information, and a static timeline

Templates should be deterministic at `timeline.timeMs = 0`. Future animation support should be externally driven by timeline values rather than wall-clock timers.

Project-local templates live under `gitci/screens/packs/<pack-id>/scene-templates/<template-id>/`. Each template needs a `scene-template.gitci.json` with an `entry` and `export`. Relative entries are resolved from the manifest directory:

```json
{
  "schemaVersion": 1,
  "id": "example.minimal.split-proof",
  "name": "Split Proof",
  "entry": "./template.tsx",
  "export": "SplitProofScene",
  "minAspectRatio": 0.94,
  "supportedTargets": ["appstore.iphone.*", "appstore.ipad.*"],
  "propsSchema": {
    "type": "object",
    "required": ["headline", "screenshot"],
    "properties": {
      "headline": { "type": "string" },
      "screenshot": { "$ref": "#/$defs/assetRef" }
    }
  }
}
```

`supportedTargets` is enforced during planning. If a scene set selects the template for a target that does not match one of those wildcard patterns, the build fails before rendering. Leave it empty only for templates that truly work across every target family.

The Node renderer turns the selected scene template manifests into a generated Vite registry for the build. Remote template repositories are intentionally still out of scope.

## Spanned Scenes

When `minAspectRatio` forces a scene to span more than one screenshot, the composite render includes the preview gap between upload frames:

```text
frame 0 | hidden gap | frame 1
```

The gap is intentionally not exported into either PNG. Templates should avoid putting important copy or UI controls across that hidden band. Use the helpers from `@gitci/screens-react`:

```tsx
import { frameRect, gapRect, insetRect } from '@gitci/screens-react'

const firstFrame = frameRect(context, 0)
const safeTextArea = insetRect(firstFrame, 96)
const firstGap = gapRect(context, 0)
const secondFrame = frameRect(context, 1)

const imageLeft = firstGap ? firstGap.right + 96 : safeTextArea.left
```

`frameRect` returns upload-frame edges in composite pixels. `gapRect` returns the skipped inter-frame band, so a wide layout can snap content to `gap.left` or `gap.right` instead of guessing where the App Store card spacing will land.

## Device Components

The production default is `gitci.core.device-frame-2d`, a CSS-only frame that avoids licensed frame assets.

An experimental React Three Fiber component is available from `@gitci/screens-templates-core/experimental`. It is intentionally not part of the default renderer bundle. GLB models should eventually follow the project convention of a named `GitCI_Screen` mesh or a `.gitci-model.json` sidecar that describes screen placement and default camera. Until that rigging pipeline is proven, templates should keep a 2D fallback.
