import { describe, expect, it } from 'vitest'
import {
  Scene,
  SceneSet,
  Slot,
  VariantGroup,
  asset,
  defineSceneSetFromJSX
} from '../src/index'

function LaunchTemplate({
  screenshot
}: {
  screenshot: ReturnType<typeof asset>
}) {
  return (
    <SceneSet
      id="launch"
      name="Launch Screens"
      targets={['appstore.iphone.6_9.portrait']}
      appearanceByTarget={{ 'appstore.*': 'light' }}
      theme={{
        id: 'gitci.theme.clean-editorial'
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
          screenshot={screenshot}
          badge={{ label: 'HIGH', value: '250 ng/g', tone: 'warning' }}
        />
      </Slot>
    </SceneSet>
  )
}

describe('JSX scene set authoring', () => {
  it('compiles SwiftUI-like JSX into a scene set definition', () => {
    const sceneSet = defineSceneSetFromJSX(
      <LaunchTemplate screenshot={asset('../../assets/iphone/inbox.png', 'Inbox')} />
    )

    expect(sceneSet.id).toBe('launch')
    expect(sceneSet.variantGroups?.[0].selections).toEqual({ hero: 'keyword' })
    expect(sceneSet.slots).toHaveLength(1)
    expect(sceneSet.slots[0].variants[0]).toMatchObject({
      id: 'keyword',
      sceneTemplate: 'gitci.core.keyword-cards',
      props: {
        screenshot: {
          kind: 'asset',
          path: '../../assets/iphone/inbox.png',
          alt: 'Inbox'
        },
        badge: {
          label: 'HIGH',
          value: '250 ng/g',
          tone: 'warning'
        }
      }
    })
  })
})
