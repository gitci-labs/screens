import React, { Suspense, useMemo } from 'react'
import { Canvas, useLoader } from '@react-three/fiber'
import { useGLTF } from '@react-three/drei'
import { TextureLoader } from 'three'
import type { AssetRef } from '@gitci/screens-react'

type DeviceFrame3DProps = {
  modelURL: string
  screenshot: AssetRef
  width: number
  height: number
  pose?: 'front' | 'tilt-left' | 'tilt-right'
}

function assetURL(asset: AssetRef): string {
  if (asset.kind === 'asset') return asset.resolvedURL ?? asset.path
  if (asset.kind === 'data') return `data:${asset.mediaType};base64,${asset.base64}`
  return ''
}

function DeviceModel({
  modelURL,
  screenshot,
  pose
}: Omit<DeviceFrame3DProps, 'width' | 'height'>) {
  const gltf = useGLTF(modelURL)
  const texture = useLoader(TextureLoader, assetURL(screenshot))
  const rotationY = pose === 'tilt-left' ? -0.28 : pose === 'tilt-right' ? 0.28 : 0
  const screenPlane = useMemo(
    () => ({
      position: [0, 0, 0.025] as [number, number, number],
      args: [2.58, 5.58] as [number, number]
    }),
    []
  )

  return (
    <group rotation={[0, rotationY, 0]}>
      <primitive object={gltf.scene} />
      <mesh position={screenPlane.position}>
        <planeGeometry args={screenPlane.args} />
        <meshBasicMaterial map={texture} toneMapped={false} />
      </mesh>
    </group>
  )
}

export function DeviceFrame3D({ modelURL, screenshot, width, height, pose = 'front' }: DeviceFrame3DProps) {
  return (
    <div style={{ width, height }}>
      <Canvas
        dpr={1}
        frameloop="demand"
        camera={{ position: [0.8, 0.35, 7.5], fov: 28 }}
        gl={{
          antialias: true,
          alpha: true,
          preserveDrawingBuffer: true
        }}
      >
        <ambientLight intensity={2.2} />
        <directionalLight position={[3, 5, 6]} intensity={2.4} />
        <Suspense fallback={null}>
          <DeviceModel modelURL={modelURL} screenshot={screenshot} pose={pose} />
        </Suspense>
      </Canvas>
    </div>
  )
}
