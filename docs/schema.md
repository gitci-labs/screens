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

`scene-sets/<id>/scene-set.gitci.json` declares targets, appearance, theme, optional locales, slots, variants, and props.

`entry` and `export` are optional metadata for the matching TypeScript authoring file. The MVP planner still reads the JSON manifest directly; future GUI/codegen work can use the TypeScript entry point as the editable source.

Target-aware variants are selected by `includeTargets` and `excludeTargets`. If `selectedVariant` is omitted, the planner picks the first variant matching the current target.

`--pseudo-locale` and `--overflow-locale` are planner options rather than scene set fields. They add synthetic locales named `qps-ploc` and `qps-overflow` when a scene set uses localized string refs, without changing the checked-in manifest.

Named `variantGroups` let CI build product-page experiments without editing slot defaults. Pass `--variant-group ppo-a` to `validate`, `plan`, `build`, `export`, `gallery`, `archive`, or `fastlane` to apply the slot selections and use `build/<scene-set>/<variant-group>/` as the default output directory. Pass `validate --all-variant-groups` to check every declared group before doing a full render:

```json
{
  "variantGroups": [
    {
      "id": "baseline",
      "name": "Baseline",
      "selections": {
        "hero": "device",
        "details": "lookup"
      }
    },
    {
      "id": "ppo-a",
      "name": "Product Page Optimization A",
      "selections": {
        "hero": "social-proof",
        "details": "lookup"
      }
    }
  ]
}
```

Selection keys can also target a specific output family with `slot-id@target-pattern`. The planner applies the most specific matching target-pattern selection first, then falls back to the plain slot id. This lets one PPO/custom-product-page group keep separate iPhone, iPad, and Mac variants in sync without duplicating a whole scene set:

```json
{
  "variantGroups": [
    {
      "id": "ppo-a",
      "name": "Product Page Optimization A",
      "selections": {
        "hero@appstore.iphone.*": "iphone-social-proof",
        "hero@appstore.ipad.*": "ipad-productivity",
        "hero@appstore.mac.*": "mac-dashboard",
        "details": "lookup"
      }
    }
  ]
}
```

Asset references are resolved relative to the scene set directory:

```json
{
  "kind": "asset",
  "path": "../../assets/iphone/inbox.png"
}
```

Remote assets are rejected unless `assetPolicy.allowRemoteAssets` is true.

Localized copy is declared once per scene set and referenced from any prop with a localized string object. The planner resolves these objects to plain strings before rendering, repeats the output set once per locale, and writes localized files under `<locale>/<target>/...`:

```json
{
  "locales": [
    {
      "id": "en-US",
      "name": "English (US)",
      "strings": {
        "hero.headline": "Ship screenshots from source"
      }
    },
    {
      "id": "ja-JP",
      "name": "Japanese",
      "strings": {
        "hero.headline": "ソースからスクリーンショットを生成"
      }
    }
  ],
  "slots": [
    {
      "id": "hero",
      "variants": [
        {
          "id": "default",
          "sceneTemplate": "gitci.core.hero-device",
          "props": {
            "headline": {
              "kind": "localized",
              "key": "hero.headline",
              "fallback": "Ship screenshots"
            }
          }
        }
      ]
    }
  ]
}
```

If a localized string key is missing and no `fallback` is provided, validation and planning fail with `locale.string-missing`.

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
- `scene-set-template.gitci.json`
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

Scene set template manifests are browseable presets for creating a project scene set. They wrap a full `sceneSet` object with pack metadata, summary text, and tags so the CLI gallery and future GUI can present starter sets without evaluating TypeScript:

```json
{
  "schemaVersion": 1,
  "id": "gitci.core.basic-launch",
  "name": "Basic Launch Screens",
  "pack": "gitci.core",
  "sceneSet": {
    "schemaVersion": 1,
    "id": "launch",
    "targets": ["appstore.iphone.6_9.portrait"],
    "slots": [
      {
        "id": "hero",
        "variants": [
          {
            "id": "device",
            "sceneTemplate": "gitci.core.hero-device",
            "props": {}
          }
        ]
      }
    ]
  }
}
```

## Output Manifest

`manifest.gitci-output.json` is generated next to `plan.gitci-render.json` after a successful build. It uses `schemas/output-manifest.gitci.schema.json` and is intended for galleries, CI artifacts, and future GUI inspection. Localized screenshots include `locale` metadata on each screenshot entry.

Each screenshot entry records the final upload image dimensions plus the source composite scene size, display gap, span count, span index, and clip rectangle. Consumers can reconstruct a wide scene strip from the manifest without re-running the planner.
