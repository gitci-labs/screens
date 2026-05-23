# Dogfooding Workflow

This is the shortest current path from an app repo with existing screenshots to App Store-ready PNGs.

## 1. Initialize

From the app repo root:

```sh
gitci-screens init . --name "My App" --github-workflow
```

This creates `gitci/screens` with a minimal renderable scene set.
The optional workflow writes `.github/workflows/gitci-screens.yml` so CI can build, gallery, archive, and upload screenshot zips.

## 2. Create a Templated Set

Use the starter scene set template and fill any screenshots you already have:

```sh
gitci-screens scene-sets create . \
  --template gitci.core.basic-launch \
  --id launch \
  --variant hero=device \
  --asset hero=Screenshots/iphone/hero.png \
  --asset detail=Screenshots/iphone/detail.png \
  --asset overview=Screenshots/ipad/overview.png
```

The `--asset` name is matched against the placeholder asset basename in the template. The CLI copies each source file into `gitci/screens/assets/...` and rewrites the scene set manifest to point at the copied file.
The `--variant` name is matched against a scene-set template slot id so you can choose a different preset without editing JSON.

## 3. Refresh Screenshots Later

When the app UI changes, update the existing scene set without recreating it:

```sh
gitci-screens scene-sets fill-assets . \
  --scene-set launch \
  --asset hero=Screenshots/iphone/hero-v2.png \
  --asset detail=Screenshots/iphone/detail-v2.png
```

## 4. Validate

```sh
gitci-screens validate . --scene-set launch --strict
```

Use `--json` in CI or editor integrations. Use `--strict` when warnings, such as a first-three screenshot missing headline text, should fail the run.

## 5. Export

```sh
gitci-screens export . --scene-set launch --strict
```

Outputs land under:

```text
gitci/screens/build/launch/
```

The zip archive at `gitci/screens/build/launch.zip` is suitable for CI artifacts or handoff. The gallery at `gitci/screens/build/launch/gallery/index.html` shows discovered templates plus built outputs and simulated App Store gaps.

If the scene set declares `locales`, export repeats the selected slots for each locale and writes files under `gitci/screens/build/launch/<locale>/<target>/...`. Keep localized marketing copy in the scene-set manifest with `{ "kind": "localized", "key": "...", "fallback": "..." }` props so the renderer still receives plain strings.

When iterating on one step, the underlying commands are still available:

```sh
gitci-screens build . --scene-set launch
gitci-screens gallery . --scene-set launch
gitci-screens archive . --scene-set launch
```

## Notes

- Keep scene set files in version control.
- Do not commit generated `gitci/screens/build` outputs unless a repo intentionally tracks examples.
- Use `discover --json` to inspect available targets, scene templates, scene set templates, palettes, themes, and components.
- Use `templates install` when a project depends on a released `screens-templates` archive instead of a local template checkout.
