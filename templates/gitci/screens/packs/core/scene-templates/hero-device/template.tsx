import React from 'react'
import type { AssetRef, SceneTemplateProps } from '@gitci/screens-react'
import { DeviceFrame2D } from '../../components/device-frame-2d/DeviceFrame2D'

type HeroDeviceProps = {
  headline: string
  subheadline?: string
  screenshot: AssetRef
  device?: 'iphone-2d' | 'ipad-2d' | 'mac-2d' | 'iphone-3d'
  devicePose?: 'front' | 'tilt-left' | 'tilt-right' | 'floating'
}

function assertAsset(value: AssetRef | undefined): AssetRef {
  if (!value) {
    throw new Error('HeroDeviceScene requires props.screenshot')
  }
  return value
}

export function HeroDeviceScene({ props, context }: SceneTemplateProps<HeroDeviceProps>) {
  const isWide = context.compositeWidth / context.compositeHeight > 0.72
  const headlineSize = isWide ? 104 : 94
  const horizontalPadding = isWide ? 112 : 78
  const deviceKind = props.device?.startsWith('ipad')
    ? 'ipad'
    : props.device?.startsWith('mac')
      ? 'mac'
      : 'iphone'

  return (
    <section
      style={{
        width: context.compositeWidth,
        height: context.compositeHeight,
        display: 'grid',
        gridTemplateColumns: isWide ? '0.95fr 1.05fr' : '1fr',
        gridTemplateRows: isWide ? '1fr' : 'auto 1fr',
        alignItems: 'center',
        gap: isWide ? 72 : 46,
        padding: isWide ? `96px ${horizontalPadding}px` : `96px ${horizontalPadding}px`,
        boxSizing: 'border-box',
        color: 'var(--gitci-color-fg)',
        background:
          'radial-gradient(circle at 18% 14%, color-mix(in oklab, var(--gitci-color-primary) 24%, transparent), transparent 34%), linear-gradient(160deg, color-mix(in oklab, var(--gitci-color-secondary) 10%, var(--gitci-color-bg)), var(--gitci-color-bg) 54%)',
        fontFamily: 'var(--gitci-font-body)'
      }}
    >
      <div style={{ zIndex: 2 }}>
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 14,
            marginBottom: 30,
            color: 'var(--gitci-color-primary)',
            fontSize: 28,
            fontWeight: 760,
            letterSpacing: 0
          }}
        >
          <span
            style={{
              width: 22,
              height: 22,
              borderRadius: 999,
              background: 'var(--gitci-color-primary)',
              boxShadow: '0 0 0 9px color-mix(in oklab, var(--gitci-color-primary) 16%, transparent)'
            }}
          />
          GitCI Screens
        </div>
        <h1
          style={{
            margin: 0,
            fontFamily: 'var(--gitci-font-title)',
            fontSize: headlineSize,
            lineHeight: 0.94,
            letterSpacing: 0,
            textWrap: 'balance'
          }}
        >
          {props.headline}
        </h1>
        {props.subheadline ? (
          <p
            style={{
              margin: '30px 0 0',
              maxWidth: 680,
              fontSize: isWide ? 34 : 32,
              lineHeight: 1.18,
              color: 'var(--gitci-color-muted)',
              textWrap: 'balance'
            }}
          >
            {props.subheadline}
          </p>
        ) : null}
      </div>
      <div
        style={{
          display: 'grid',
          placeItems: 'center',
          alignSelf: isWide ? 'center' : 'start',
          transform:
            props.devicePose === 'tilt-right'
              ? 'rotate(-4deg)'
              : props.devicePose === 'tilt-left'
                ? 'rotate(4deg)'
                : 'none'
        }}
      >
        <DeviceFrame2D
          kind={deviceKind}
          screenshot={assertAsset(props.screenshot)}
          maxHeight={isWide ? context.compositeHeight * 0.78 : context.compositeHeight * 0.62}
          maxWidth={
            isWide
              ? (context.compositeWidth - horizontalPadding * 2 - 72) * 0.52
              : context.compositeWidth - horizontalPadding * 2
          }
        />
      </div>
    </section>
  )
}
