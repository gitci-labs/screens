import { defineSceneSet } from '@gitci/screens-react'

// Phase 1 uses scene-set.gitci.json as the authoritative manifest so Swift can
// plan builds without executing template code. This mirrors the JSON file and
// shows the intended TypeScript authoring shape for later registry/codegen work.
export const sceneSet = defineSceneSet({
  id: 'launch',
  name: 'Launch Screens',
  targets: [
    'appstore.iphone.6_9.portrait',
    'appstore.ipad.13.portrait',
    'appstore.mac.16_10'
  ],
  appearanceByTarget: {
    'appstore.*': 'light'
  },
  theme: {
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
  },
  slots: [
    {
      id: 'hero',
      label: 'Hero',
      variants: [
        {
          id: 'iphone',
          sceneTemplate: 'gitci.core.hero-device',
          includeTargets: ['appstore.iphone.*'],
          props: {
            headline: 'Ship polished App Store screens from your repo',
            subheadline: 'Compose screenshots, text, themes, and reusable React scenes.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/iphone/inbox.svg',
              alt: 'Example app inbox screenshot'
            },
            device: 'iphone-2d',
            devicePose: 'tilt-right'
          }
        },
        {
          id: 'ipad',
          sceneTemplate: 'gitci.core.hero-device',
          includeTargets: ['appstore.ipad.*'],
          props: {
            headline: 'One scene set, every App Store target',
            subheadline: 'Target-aware variants keep iPhone, iPad, and Mac output intentional.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/ipad/board.svg',
              alt: 'Example app board screenshot'
            },
            device: 'ipad-2d',
            devicePose: 'tilt-left'
          }
        },
        {
          id: 'mac',
          sceneTemplate: 'gitci.core.hero-device',
          includeTargets: ['appstore.mac.*'],
          props: {
            headline: 'Deterministic renders for CI',
            subheadline: 'Swift plans the build. Playwright captures exact pixels.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/mac/dashboard.svg',
              alt: 'Example app dashboard screenshot'
            },
            device: 'mac-2d',
            devicePose: 'front'
          }
        }
      ]
    },
    {
      id: 'workflow',
      label: 'Workflow',
      variants: [
        {
          id: 'iphone',
          sceneTemplate: 'gitci.core.feature-closeup',
          includeTargets: ['appstore.iphone.*'],
          props: {
            eyebrow: 'Plan first',
            headline: 'Every output is predictable',
            subheadline: 'Build plans make CI runs reviewable before pixels are rendered.',
            featureTitle: 'Manifest in, screenshots out',
            featureBody: 'The CLI writes both render plans and output manifests for automation.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/iphone/inbox.svg',
              alt: 'Example app inbox screenshot'
            },
            device: 'iphone-2d'
          }
        },
        {
          id: 'ipad',
          sceneTemplate: 'gitci.core.feature-closeup',
          includeTargets: ['appstore.ipad.*'],
          props: {
            eyebrow: 'Browse variants',
            headline: 'Templates can scale up',
            subheadline: 'The same authoring model works for app projects and reusable packs.',
            featureTitle: 'Target-aware by default',
            featureBody: 'Scene variants can specialize copy, assets, and device frames per target.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/ipad/board.svg',
              alt: 'Example app board screenshot'
            },
            device: 'ipad-2d'
          }
        },
        {
          id: 'mac',
          sceneTemplate: 'gitci.core.feature-closeup',
          includeTargets: ['appstore.mac.*'],
          props: {
            eyebrow: 'CI-friendly',
            headline: 'Render exact pixels',
            subheadline: 'Chromium captures the same planned viewport every time.',
            featureTitle: 'No manual export checklist',
            featureBody: 'Targets, appearance, filenames, and screenshot order live in source control.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/mac/dashboard.svg',
              alt: 'Example app dashboard screenshot'
            },
            device: 'mac-2d'
          }
        }
      ]
    },
    {
      id: 'span',
      label: 'Spanning Scene',
      variants: [
        {
          id: 'default',
          sceneTemplate: 'example.minimal.split-proof',
          props: {
            headline: 'Wide scenes stay wide',
            subheadline:
              'When a layout needs more horizontal space, the planner spans multiple screenshot slots and clips out valid uploads.',
            screenshot: {
              kind: 'asset',
              path: '../../assets/iphone/inbox.svg',
              alt: 'Example app inbox screenshot'
            }
          }
        }
      ]
    }
  ]
})
