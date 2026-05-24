import React from 'react'
import {
  firstFrameRect,
  insetRect,
  lastFrameRect,
  type AssetRef,
  type SceneTemplateProps
} from '@gitci/screens-react'
import { DeviceFrame2D } from '../../components/device-frame-2d/DeviceFrame2D'

type KeywordTone = 'primary' | 'secondary' | 'danger' | 'warning' | 'light'

type KeywordToken = {
  text: string
  emphasis?: boolean
  tone?: KeywordTone
  rotate?: number
}

type BadgeProps = {
  label?: string
  value?: string
  tone?: KeywordTone
}

type KeywordCardsProps = {
  headline?: string
  highlightedWords?: string[]
  headlineLines?: KeywordToken[][]
  subheadline?: string
  screenshot: AssetRef
  mediaMode?: 'photo' | 'device'
  device?: 'iphone-2d' | 'ipad-2d' | 'mac-2d'
  badge?: BadgeProps
}

function toneColor(tone: KeywordTone | undefined) {
  switch (tone) {
    case 'secondary':
      return 'var(--gitci-color-secondary)'
    case 'danger':
      return '#ef4444'
    case 'warning':
      return '#f59e0b'
    case 'light':
      return 'rgb(255 255 255 / 0.94)'
    case 'primary':
    default:
      return 'var(--gitci-color-primary)'
  }
}

function toneTextColor(tone: KeywordTone | undefined) {
  return tone === 'light' ? 'var(--gitci-color-fg)' : '#fff'
}

function deviceKind(device: KeywordCardsProps['device']): 'iphone' | 'ipad' | 'mac' {
  if (device?.startsWith('ipad')) return 'ipad'
  if (device?.startsWith('mac')) return 'mac'
  return 'iphone'
}

function assetSource(asset: AssetRef): string {
  if (asset.kind === 'asset') {
    return asset.resolvedURL ?? asset.path
  }
  if (asset.kind === 'data') {
    return `data:${asset.mediaType};base64,${asset.base64}`
  }
  throw new Error(`KeywordCardsScene cannot render generated asset ${asset.id}`)
}

function linesFromProps(props: KeywordCardsProps): KeywordToken[][] {
  if (props.headlineLines?.length) {
    return props.headlineLines
  }

  const highlighted = new Set((props.highlightedWords ?? []).map(word => word.toLocaleLowerCase()))
  const words = (props.headline ?? 'Keyword driven screens')
    .split(/\s+/)
    .map(word => word.trim())
    .filter(Boolean)

  return [
    words.map(word => ({
      text: word,
      emphasis: highlighted.has(word.toLocaleLowerCase())
    }))
  ]
}

export function KeywordCardsScene({ props, context }: SceneTemplateProps<KeywordCardsProps>) {
  const isWide = context.compositeWidth / context.compositeHeight > 0.72
  const isSpanned = context.span > 1
  const paddingX = isWide ? 112 : 74
  const firstSafe = insetRect(firstFrameRect(context), paddingX)
  const lastSafe = insetRect(lastFrameRect(context), paddingX)
  const mediaMode = props.mediaMode ?? 'device'
  const lines = linesFromProps(props)

  if (isSpanned) {
    return (
      <section
        style={{
          position: 'relative',
          width: context.compositeWidth,
          height: context.compositeHeight,
          overflow: 'hidden',
          color: 'var(--gitci-color-fg)',
          background: 'linear-gradient(180deg, color-mix(in oklab, var(--gitci-color-primary) 9%, var(--gitci-color-bg)), var(--gitci-color-bg))',
          fontFamily: 'var(--gitci-font-body)'
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: firstSafe.left,
            top: 138,
            width: firstSafe.width
          }}
        >
          <KeywordHeadline lines={lines} isWide={isWide} />
          <Subheadline text={props.subheadline} isWide={isWide} />
        </div>
        <div
          style={{
            position: 'absolute',
            left: lastSafe.left,
            top: 0,
            width: lastSafe.width,
            height: context.compositeHeight,
            display: 'grid',
            placeItems: 'center'
          }}
        >
          <MediaPanel
            props={props}
            mode={mediaMode}
            isWide={isWide}
            maxWidth={lastSafe.width}
            maxHeight={context.compositeHeight * 0.78}
          />
        </div>
      </section>
    )
  }

  return (
    <section
      style={{
        position: 'relative',
        width: context.compositeWidth,
        height: context.compositeHeight,
        overflow: 'hidden',
        display: 'grid',
        gridTemplateRows: mediaMode === 'photo' ? '1fr auto' : 'auto 1fr',
        gap: mediaMode === 'photo' ? 46 : 56,
        padding: `82px ${paddingX}px 86px`,
        boxSizing: 'border-box',
        color: 'var(--gitci-color-fg)',
        background: 'linear-gradient(180deg, color-mix(in oklab, var(--gitci-color-primary) 9%, var(--gitci-color-bg)), var(--gitci-color-bg))',
        fontFamily: 'var(--gitci-font-body)'
      }}
    >
      {mediaMode === 'photo' ? (
        <>
          <MediaPanel
            props={props}
            mode={mediaMode}
            isWide={isWide}
            maxWidth={context.compositeWidth - paddingX * 2}
            maxHeight={context.compositeHeight * 0.66}
          />
          <div>
            <KeywordHeadline lines={lines} isWide={isWide} />
            <Subheadline text={props.subheadline} isWide={isWide} />
          </div>
        </>
      ) : (
        <>
          <div>
            <KeywordHeadline lines={lines} isWide={isWide} />
            <Subheadline text={props.subheadline} isWide={isWide} />
          </div>
          <MediaPanel
            props={props}
            mode={mediaMode}
            isWide={isWide}
            maxWidth={context.compositeWidth - paddingX * 2}
            maxHeight={context.compositeHeight * 0.62}
          />
        </>
      )}
    </section>
  )
}

function KeywordHeadline({
  lines,
  isWide
}: {
  lines: KeywordToken[][]
  isWide: boolean
}) {
  return (
    <h1
      style={{
        margin: 0,
        display: 'grid',
        justifyItems: 'center',
        gap: isWide ? 18 : 14,
        fontFamily: 'var(--gitci-font-title)',
        fontSize: isWide ? 88 : 82,
        lineHeight: 0.98,
        letterSpacing: 0,
        textAlign: 'center'
      }}
    >
      {lines.map((line, index) => (
        <span
          key={index}
          style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            gap: 18,
            flexWrap: 'wrap'
          }}
        >
          {line.map((token, tokenIndex) => (
            <KeywordWord key={`${token.text}-${tokenIndex}`} token={token} />
          ))}
        </span>
      ))}
    </h1>
  )
}

function KeywordWord({ token }: { token: KeywordToken }) {
  if (!token.emphasis) {
    return <span>{token.text}</span>
  }

  const rotate = token.rotate ?? -2.5
  return (
    <span
      style={{
        display: 'inline-block',
        padding: '0.08em 0.34em 0.13em',
        borderRadius: '0.33em',
        color: toneTextColor(token.tone),
        background: toneColor(token.tone),
        boxShadow: '0 18px 38px rgb(15 23 42 / 0.14)',
        transform: `rotate(${rotate}deg)`,
        transformOrigin: '50% 58%'
      }}
    >
      {token.text}
    </span>
  )
}

function Subheadline({
  text,
  isWide
}: {
  text?: string
  isWide: boolean
}) {
  if (!text) {
    return null
  }
  return (
    <p
      style={{
        margin: '28px auto 0',
        maxWidth: isWide ? 760 : 680,
        color: 'var(--gitci-color-muted)',
        fontSize: isWide ? 30 : 29,
        lineHeight: 1.18,
        textAlign: 'center',
        textWrap: 'balance'
      }}
    >
      {text}
    </p>
  )
}

function MediaPanel({
  props,
  mode,
  isWide,
  maxWidth,
  maxHeight
}: {
  props: KeywordCardsProps
  mode: 'photo' | 'device'
  isWide: boolean
  maxWidth: number
  maxHeight: number
}) {
  const screenshot = props.screenshot
  if (mode === 'photo') {
    const width = Math.min(maxWidth, isWide ? 900 : 820)
    return (
      <div
        style={{
          position: 'relative',
          width,
          height: maxHeight,
          justifySelf: 'center',
          alignSelf: 'center',
          borderRadius: 54,
          overflow: 'hidden',
          background: '#111',
          boxShadow: '0 42px 110px rgb(15 23 42 / 0.22)'
        }}
      >
        <img
          src={assetSource(screenshot)}
          alt={screenshot.alt ?? ''}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block'
          }}
        />
        <div
          style={{
            position: 'absolute',
            inset: 'auto 0 0',
            height: '34%',
            background: 'linear-gradient(180deg, transparent, color-mix(in oklab, var(--gitci-color-primary) 82%, transparent))'
          }}
        />
        <Badge badge={props.badge} />
      </div>
    )
  }

  return (
    <div
      style={{
        position: 'relative',
        display: 'grid',
        placeItems: 'center',
        justifySelf: 'center',
        alignSelf: 'center'
      }}
    >
      <DeviceFrame2D
        kind={deviceKind(props.device)}
        screenshot={screenshot}
        maxHeight={maxHeight}
        maxWidth={maxWidth}
      />
      <Badge badge={props.badge} />
    </div>
  )
}

function Badge({ badge }: { badge?: BadgeProps }) {
  if (!badge?.label && !badge?.value) {
    return null
  }

  return (
    <div
      style={{
        position: 'absolute',
        right: 24,
        bottom: 34,
        display: 'grid',
        justifyItems: 'center',
        gap: 8,
        padding: '16px 26px 20px',
        borderRadius: 24,
        color: toneTextColor(badge.tone),
        background: toneColor(badge.tone ?? 'primary'),
        boxShadow: '0 20px 44px rgb(15 23 42 / 0.22)',
        transform: 'rotate(-2deg)'
      }}
    >
      {badge.label ? (
        <span style={{ fontSize: 28, lineHeight: 1, fontWeight: 860 }}>{badge.label}</span>
      ) : null}
      {badge.value ? (
        <span style={{ fontSize: 46, lineHeight: 1, fontWeight: 900 }}>{badge.value}</span>
      ) : null}
    </div>
  )
}
