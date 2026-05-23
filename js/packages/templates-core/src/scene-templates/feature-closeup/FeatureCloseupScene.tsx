import React from 'react'
import {
  firstFrameRect,
  insetRect,
  lastFrameRect,
  type AssetRef,
  type SceneTemplateProps
} from '@gitci/screens-react'
import { DeviceFrame2D } from '../../components/device-frame-2d/DeviceFrame2D'

type FeatureCloseupProps = {
  headline: string
  subheadline?: string
  featureTitle?: string
  featureBody?: string
  eyebrow?: string
  screenshot: AssetRef
  device?: 'iphone-2d' | 'ipad-2d' | 'mac-2d'
}

function deviceKind(device: FeatureCloseupProps['device']): 'iphone' | 'ipad' | 'mac' {
  if (device?.startsWith('ipad')) return 'ipad'
  if (device?.startsWith('mac')) return 'mac'
  return 'iphone'
}

export function FeatureCloseupScene({ props, context }: SceneTemplateProps<FeatureCloseupProps>) {
  const isWide = context.compositeWidth / context.compositeHeight > 0.72
  const isSpanned = context.span > 1
  const paddingX = isWide ? 116 : 76
  const kind = deviceKind(props.device)
  const firstSafe = insetRect(firstFrameRect(context), paddingX)
  const lastSafe = insetRect(lastFrameRect(context), paddingX)

  if (isSpanned) {
    return (
      <section
        style={{
          position: 'relative',
          width: context.compositeWidth,
          height: context.compositeHeight,
          color: 'var(--gitci-color-fg)',
          background:
            'linear-gradient(155deg, var(--gitci-color-bg), color-mix(in oklab, var(--gitci-color-primary) 9%, var(--gitci-color-bg)))',
          fontFamily: 'var(--gitci-font-body)',
          overflow: 'hidden'
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: firstSafe.left,
            top: 0,
            width: firstSafe.width,
            height: context.compositeHeight,
            display: 'grid',
            placeItems: 'center'
          }}
        >
          <DeviceFrame2D
            kind={kind}
            screenshot={props.screenshot}
            maxHeight={context.compositeHeight * 0.78}
            maxWidth={firstSafe.width}
          />
        </div>
        <div
          style={{
            position: 'absolute',
            left: lastSafe.left,
            top: 0,
            width: Math.min(lastSafe.width, 820),
            height: context.compositeHeight,
            display: 'grid',
            alignContent: 'center',
            gap: 28
          }}
        >
          <FeatureCopy props={props} isWide={isWide} />
        </div>
      </section>
    )
  }

  return (
    <section
      style={{
        width: context.compositeWidth,
        height: context.compositeHeight,
        display: 'grid',
        gridTemplateColumns: isWide ? '1.08fr 0.92fr' : '1fr',
        gridTemplateRows: isWide ? '1fr' : 'auto 1fr',
        gap: isWide ? 78 : 48,
        alignItems: 'center',
        padding: `96px ${paddingX}px`,
        color: 'var(--gitci-color-fg)',
        background:
          'linear-gradient(155deg, var(--gitci-color-bg), color-mix(in oklab, var(--gitci-color-primary) 9%, var(--gitci-color-bg)))',
        fontFamily: 'var(--gitci-font-body)',
        overflow: 'hidden'
      }}
    >
      <div
        style={{
          display: 'grid',
          placeItems: 'center',
          order: isWide ? 0 : 1
        }}
      >
        <DeviceFrame2D
          kind={kind}
          screenshot={props.screenshot}
          maxHeight={isWide ? context.compositeHeight * 0.78 : context.compositeHeight * 0.58}
          maxWidth={isWide ? (context.compositeWidth - paddingX * 2 - 78) * 0.55 : context.compositeWidth - paddingX * 2}
        />
      </div>
      <div
        style={{
          display: 'grid',
          alignContent: 'center',
          gap: 28,
          order: isWide ? 1 : 0
        }}
      >
        <FeatureCopy props={props} isWide={isWide} />
      </div>
    </section>
  )
}

function FeatureCopy({
  props,
  isWide
}: {
  props: FeatureCloseupProps
  isWide: boolean
}) {
  return (
    <>
      <div
        style={{
          color: 'var(--gitci-color-primary)',
          fontSize: isWide ? 28 : 26,
          fontWeight: 780
        }}
      >
        {props.eyebrow ?? 'Focused workflow'}
      </div>
      <h1
        style={{
          margin: 0,
          fontFamily: 'var(--gitci-font-title)',
          fontSize: isWide ? 92 : 86,
          lineHeight: 0.96,
          letterSpacing: 0,
          textWrap: 'balance'
        }}
      >
        {props.headline}
      </h1>
      {props.subheadline ? (
        <p
          style={{
            margin: 0,
            maxWidth: 680,
            color: 'var(--gitci-color-muted)',
            fontSize: isWide ? 32 : 30,
            lineHeight: 1.18,
            textWrap: 'balance'
          }}
        >
          {props.subheadline}
        </p>
      ) : null}
      <div
        style={{
          marginTop: 18,
          padding: '34px 36px',
          borderRadius: 34,
          background: 'rgb(255 255 255 / 0.72)',
          boxShadow: '0 30px 90px rgb(15 23 42 / 0.12)'
        }}
      >
        <div
          style={{
            fontSize: 30,
            fontWeight: 800,
            marginBottom: 10
          }}
        >
          {props.featureTitle ?? 'Scene templates stay reusable'}
        </div>
        <div
          style={{
            color: 'var(--gitci-color-muted)',
            fontSize: 25,
            lineHeight: 1.22
          }}
        >
          {props.featureBody ?? 'Swap screenshots and copy without changing the renderer.'}
        </div>
      </div>
    </>
  )
}
