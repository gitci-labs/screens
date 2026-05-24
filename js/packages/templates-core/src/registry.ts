import { defineRegistry } from '@gitci/screens-react'
import { DeviceFrame2D } from './components/device-frame-2d/DeviceFrame2D'
import { FeatureCloseupScene } from './scene-templates/feature-closeup/FeatureCloseupScene'
import { HeroDeviceScene } from './scene-templates/hero-device/HeroDeviceScene'
import { KeywordCardsScene } from './scene-templates/keyword-cards/KeywordCardsScene'

export const registry = defineRegistry({
  sceneTemplates: {
    'gitci.core.feature-closeup': FeatureCloseupScene,
    'gitci.core.hero-device': HeroDeviceScene,
    'gitci.core.keyword-cards': KeywordCardsScene
  },
  components: {
    'gitci.core.device-frame-2d': DeviceFrame2D
  }
})
