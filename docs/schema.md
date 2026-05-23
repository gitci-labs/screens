# Schema

Phase 1 uses versioned JSON manifests that Swift can parse without executing React or TypeScript.

## Project

`project.gitci.json` declares the project identity, default scene set, and asset policy.

```json
{
  "schemaVersion": 1,
  "id": "com.example.todo.gitci-screens",
  "name": "Todo App Screens",
  "sources": [
    {
      "id": "gitci.core",
      "kind": "local",
      "path": "../../../../templates/gitci/screens"
    }
  ],
  "defaultSceneSet": "launch",
  "assetPolicy": {
    "allowRemoteAssets": false
  }
}
```

`sources` can point at local reusable template roots that contain a `packs` directory. `githubRelease` sources resolve from the local template cache; install a release archive with `gitci-screens templates install --repo gitci-labs/screens-templates --version v0.1.0` and inspect installed releases with `gitci-screens templates list --json`. The CLI looks under `~/.gitci/screens/templates/<repo-name>/<version>/gitci/screens`; for example `gitci-labs/screens-templates` version `v0.1.0` resolves to `~/.gitci/screens/templates/screens-templates/v0.1.0/gitci/screens`. `GITCI_SCREENS_TEMPLATE_CACHE_ROOT` can override the cache root. Packaged template roots and `GITCI_SCREENS_TEMPLATES_ROOT` are also discovered.

## Scene Set

`scene-sets/<id>/scene-set.gitci.json` declares targets, appearance, theme, slots, variants, and props.

`entry` and `export` are optional metadata for the matching TypeScript authoring file. The MVP planner still reads the JSON manifest directly; future GUI/codegen work can use the TypeScript entry point as the editable source.

Target-aware variants are selected by `includeTargets` and `excludeTargets`. If `selectedVariant` is omitted, the planner picks the first variant matching the current target.

Asset references are resolved relative to the scene set directory:

```json
{
  "kind": "asset",
  "path": "../../assets/iphone/inbox.png"
}
```

Remote assets are rejected unless `assetPolicy.allowRemoteAssets` is true.

Themes can also map named CSS vars to reusable palette stops. Stops are normalized from `0` to `1`, so differently sized palettes still map predictably:

```json
{
  "theme": {
    "id": "gitci.theme.clean-editorial",
    "palette": "gitci.palette.gitci-blue",
    "paletteMap": {
      "--gitci-color-bg": 0,
      "--gitci-color-primary": 0.5,
      "--gitci-color-secondary": 0.75,
      "--gitci-color-fg": 1
    },
    "overrides": {
      "--gitci-color-secondary": "#14b8a6"
    }
  }
}
```

Resolution order is base theme vars, then palette-mapped vars, then explicit overrides.

## Template Packs

Template packs live under `gitci/screens/packs/<pack-id>` or in an installed templates root such as `templates/gitci/screens/packs/<pack-id>`.

Supported manifest filenames:

- `pack.gitci.json`
- `scene-template.gitci.json`
- `component.gitci.json`
- `theme.gitci.json`
- `palette.gitci.json`
- target collections such as `appstore.gitci.json`

The manifests use JSON Schema Draft 2020-12 style `propsSchema` objects. Swift reads enough of `propsSchema.required` to catch missing required props before handing work to the renderer.

Scene template manifests must include renderable module metadata:

```json
{
  "schemaVersion": 1,
  "id": "example.minimal.split-proof",
  "name": "Split Proof",
  "entry": "./template.tsx",
  "export": "SplitProofScene"
}
```

Package entries such as `@gitci/screens-templates-core` are passed through. Relative entries are resolved from the manifest directory and written into the render plan so the Node renderer can generate a Vite registry without rediscovering files.

## Output Manifest

`manifest.gitci-output.json` is generated next to `plan.gitci-render.json` after a successful build. It uses `schemas/output-manifest.gitci.schema.json` and is intended for galleries, CI artifacts, and future GUI inspection.

Each screenshot entry records the final upload image dimensions plus the source composite scene size, display gap, span count, span index, and clip rectangle. Consumers can reconstruct a wide scene strip from the manifest without re-running the planner.
