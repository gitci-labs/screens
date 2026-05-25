# Authoring Scene Sets

A scene set is the app-specific source of truth for screenshot output. It owns target selection, screenshot order, theme, locales, and product-page variants.

The planner still consumes `SceneSetDefinition` data because Swift needs to validate and plan builds without guessing at arbitrary React trees. Authors do not need to hand-write that object. Use the JSX DSL from `@gitci/screens-react` when you want a SwiftUI-style declaration:

```tsx
import {
  Scene,
  SceneSet,
  Slot,
  VariantGroup,
  asset,
  defineSceneSetFromJSX
} from '@gitci/screens-react'

export const sceneSet = defineSceneSetFromJSX(
  <SceneSet
    id="launch"
    name="Launch Screens"
    targets={[
      'appstore.iphone.6_9.portrait',
      'appstore.ipad.13.portrait',
      'appstore.mac.16_10'
    ]}
    appearanceByTarget={{ 'appstore.*': 'light' }}
    theme={{
      id: 'gitci.theme.clean-editorial',
      palette: 'gitci.palette.gitci-blue',
      paletteMap: {
        '--gitci-color-bg': 0,
        '--gitci-color-fg': 1,
        '--gitci-color-primary': 0.5
      }
    }}
  >
    <VariantGroup id="ppo-a" name="PPO A" selections={{ hero: 'keyword' }} />

    <Slot id="hero" label="Hero">
      <Scene
        id="keyword"
        template="gitci.core.keyword-cards"
        headlineLines={[
          [{ text: 'Microplastics' }],
          [{ text: 'Food', emphasis: true }, { text: 'Scan' }]
        ]}
        screenshot={asset('../../assets/iphone/scan.png', 'Food scan screenshot')}
        mediaMode="device"
        badge={{ label: 'HIGH', value: '250 ng/g', tone: 'warning' }}
      />

      <Scene
        id="classic"
        template="gitci.core.hero-device"
        headline="Scan food in seconds"
        screenshot={asset('../../assets/iphone/scan.png')}
        device="iphone-2d"
      />
    </Slot>
  </SceneSet>
)
```

`<Scene>` has a few reserved props:

- `id`
- `template` or `sceneTemplate`
- `includeTargets`
- `excludeTargets`
- `props`

Every other prop becomes template props. This keeps common scenes readable while still allowing an explicit `props={{ ... }}` escape hatch.

Reusable scene set templates should be plain functions that return JSX:

```tsx
function StoreLaunchSet({
  appName,
  screenshot
}: {
  appName: string
  screenshot: ReturnType<typeof asset>
}) {
  return (
    <SceneSet id="launch" targets={['appstore.iphone.6_9.portrait']}>
      <Slot id="hero">
        <Scene
          id="default"
          template="gitci.core.keyword-cards"
          headline={`${appName} detects what matters`}
          highlightedWords={['detects']}
          screenshot={screenshot}
        />
      </Slot>
    </SceneSet>
  )
}

export const sceneSet = defineSceneSetFromJSX(
  <StoreLaunchSet
    appName="Manabi Reader"
    screenshot={asset('../../assets/iphone/reader.png')}
  />
)
```

This keeps the mental model close to SwiftUI: reusable templates are components/functions, and the final scene set is the concrete instance checked into the app repo.

Swift discovery still starts from `scene-set.gitci.json`, but that file can now be just an index:

```json
{
  "schemaVersion": 1,
  "id": "launch",
  "name": "Launch Screens",
  "entry": "./scene-set.tsx",
  "export": "sceneSet"
}
```

When `targets` or `slots` are absent, Swift asks a `SceneSetEvaluator` to materialize the TSX export into the same `SceneSetDefinition` shape before validation and planning. The sandbox app uses a WebView authoring harness backed by `esbuild-wasm`; the harness reads source files through a narrow Swift bridge and provides virtual authoring-only implementations of `@gitci/screens-react`, `react`, and `react/jsx-runtime`. That lets Swift reason about React-authored scene sets without maintaining a redundant JSON copy.
