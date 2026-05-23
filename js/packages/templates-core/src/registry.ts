import { defineRegistry } from '@gitci/screens-react'
import { DeviceFrame2D } from './components/device-frame-2d/DeviceFrame2D'
import { FeatureCloseupScene } from './scene-templates/feature-closeup/FeatureCloseupScene'
import { HeroDeviceScene } from './scene-templates/hero-device/HeroDeviceScene'

export const registry = defineRegistry({
  sceneTemplates: {
    'gitci.core.feature-closeup': FeatureCloseupScene,
    'gitci.core.hero-device': HeroDeviceScene
  },
  components: {
    'gitci.core.device-frame-2d': DeviceFrame2D
  }
})
