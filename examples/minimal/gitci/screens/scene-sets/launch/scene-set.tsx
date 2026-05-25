import {
  Scene,
  SceneSet,
  Slot,
  VariantGroup,
  asset,
  defineSceneSetFromJSX
} from '@gitci/screens-react'

// Swift currently plans from scene-set.gitci.json. This TSX file shows the
// preferred authoring shape: JSX that compiles to the same SceneSetDefinition.
export const sceneSet = defineSceneSetFromJSX(
  <SceneSet
    id="launch"
    name="Launch Screens"
    targets={[
      'appstore.iphone.6_9.portrait',
      'appstore.ipad.13.portrait',
      'appstore.mac.16_10'
    ]}
    appearanceByTarget={{
      'appstore.*': 'light'
    }}
    theme={{
      id: 'gitci.theme.clean-editorial',
      palette: 'gitci.palette.gitci-blue',
      paletteMap: {
        '--gitci-color-bg': 0,
        '--gitci-color-fg': 1,
        '--gitci-color-primary': 0.5,
        '--gitci-color-secondary': 0.75
      },
      overrides: {
        '--gitci-color-secondary': '#14b8a6'
      }
    }}
  >
    <VariantGroup id="baseline" name="Baseline" selections={{ span: 'default' }} />
    <VariantGroup id="ppo-a" name="PPO A" selections={{ span: 'concise' }} />

    <Slot id="hero" label="Hero">
      <Scene
        id="iphone"
        template="gitci.core.hero-device"
        includeTargets={['appstore.iphone.*']}
        headline="Ship polished App Store screens from your repo"
        subheadline="Compose screenshots, text, themes, and reusable React scenes."
        screenshot={asset('../../assets/iphone/inbox.svg', 'Example app inbox screenshot')}
        device="iphone-2d"
        devicePose="tilt-right"
      />
      <Scene
        id="ipad"
        template="gitci.core.hero-device"
        includeTargets={['appstore.ipad.*']}
        headline="One scene set, every App Store target"
        subheadline="Target-aware variants keep iPhone, iPad, and Mac output intentional."
        screenshot={asset('../../assets/ipad/board.svg', 'Example app board screenshot')}
        device="ipad-2d"
        devicePose="tilt-left"
      />
      <Scene
        id="mac"
        template="gitci.core.hero-device"
        includeTargets={['appstore.mac.*']}
        headline="Deterministic renders for CI"
        subheadline="Swift plans the build. Playwright captures exact pixels."
        screenshot={asset('../../assets/mac/dashboard.svg', 'Example app dashboard screenshot')}
        device="mac-2d"
        devicePose="front"
      />
    </Slot>

    <Slot id="workflow" label="Workflow">
      <Scene
        id="iphone"
        template="gitci.core.feature-closeup"
        includeTargets={['appstore.iphone.*']}
        eyebrow="Plan first"
        headline="Every output is predictable"
        subheadline="Build plans make CI runs reviewable before pixels are rendered."
        featureTitle="Manifest in, screenshots out"
        featureBody="The CLI writes both render plans and output manifests for automation."
        screenshot={asset('../../assets/iphone/inbox.svg', 'Example app inbox screenshot')}
        device="iphone-2d"
      />
      <Scene
        id="ipad"
        template="gitci.core.feature-closeup"
        includeTargets={['appstore.ipad.*']}
        eyebrow="Browse variants"
        headline="Templates can scale up"
        subheadline="The same authoring model works for app projects and reusable packs."
        featureTitle="Target-aware by default"
        featureBody="Scene variants can specialize copy, assets, and device frames per target."
        screenshot={asset('../../assets/ipad/board.svg', 'Example app board screenshot')}
        device="ipad-2d"
      />
      <Scene
        id="mac"
        template="gitci.core.feature-closeup"
        includeTargets={['appstore.mac.*']}
        eyebrow="CI-friendly"
        headline="Render exact pixels"
        subheadline="Chromium captures the same planned viewport every time."
        featureTitle="No manual export checklist"
        featureBody="Targets, appearance, filenames, and screenshot order live in source control."
        screenshot={asset('../../assets/mac/dashboard.svg', 'Example app dashboard screenshot')}
        device="mac-2d"
      />
    </Slot>

    <Slot id="span" label="Spanning Scene">
      <Scene
        id="default"
        template="example.minimal.split-proof"
        headline="Wide scenes stay wide"
        subheadline="When a layout needs more horizontal space, the planner spans multiple screenshot slots and clips out valid uploads."
        screenshot={asset('../../assets/iphone/inbox.svg', 'Example app inbox screenshot')}
      />
      <Scene
        id="concise"
        template="example.minimal.split-proof"
        headline="Test wide campaign art"
        subheadline="Named variant groups let CI export product-page experiments from the same scene set."
        screenshot={asset('../../assets/iphone/inbox.svg', 'Example app inbox screenshot')}
      />
    </Slot>
  </SceneSet>
)
