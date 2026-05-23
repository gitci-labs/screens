import React from 'react'
import type { AssetRef } from '@gitci/screens-react'

type DeviceFrame2DProps = {
  kind: 'iphone' | 'ipad' | 'mac'
  screenshot: AssetRef
  maxHeight: number
  maxWidth?: number
}

function imageURL(asset: AssetRef): string {
  if (asset.kind === 'asset') {
    return asset.resolvedURL ?? asset.path
  }
  if (asset.kind === 'data') {
    return `data:${asset.mediaType};base64,${asset.base64}`
  }
  return ''
}

export function DeviceFrame2D({ kind, screenshot, maxHeight, maxWidth }: DeviceFrame2DProps) {
  const aspect = kind === 'mac' ? 16 / 10 : kind === 'ipad' ? 3 / 4 : 9 / 19.5
  const height = Math.min(maxHeight, maxWidth ? maxWidth / aspect : maxHeight)
  const width = height * aspect
  const radius = kind === 'iphone' ? width * 0.12 : kind === 'ipad' ? width * 0.06 : 28
  const bezel = kind === 'iphone' ? width * 0.035 : kind === 'ipad' ? width * 0.025 : 18

  return (
    <div
      style={{
        width,
        height,
        borderRadius: radius,
        padding: bezel,
        background: 'linear-gradient(145deg, #3a3a3c, #050505)',
        boxShadow: '0 54px 120px rgb(15 23 42 / 0.32)',
        boxSizing: 'border-box'
      }}
    >
      <div
        style={{
          position: 'relative',
          width: '100%',
          height: '100%',
          overflow: 'hidden',
          borderRadius: Math.max(8, radius - bezel),
          background: '#000'
        }}
      >
        <img
          src={imageURL(screenshot)}
          alt={screenshot.alt ?? ''}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block'
          }}
        />
      </div>
    </div>
  )
}
