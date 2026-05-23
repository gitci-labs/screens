import {
  frameRect,
  gapRect,
  insetRect,
  type AssetRef,
  type SceneTemplateProps
} from '@gitci/screens-react'

type SplitProofProps = {
  headline: string
  subheadline?: string
  screenshot: AssetRef
}

export function SplitProofScene({
  props,
  context
}: SceneTemplateProps<SplitProofProps>) {
  const isWide = context.compositeWidth / context.compositeHeight > 1.05
  const firstFrame = frameRect(context, 0)
  const firstSafe = insetRect(firstFrame, isWide ? 96 : 72)
  const firstGap = gapRect(context, 0)
  const secondFrame = context.span > 1 ? frameRect(context, 1) : undefined
  const imageLeft = firstGap && secondFrame ? firstGap.right + 96 : firstSafe.left
  const imageWidth = secondFrame
    ? Math.min(secondFrame.width - 192, context.compositeWidth * 0.44)
    : isWide
      ? context.compositeWidth * 0.44
      : context.compositeWidth * 0.68

  return (
    <section
      style={{
        position: 'relative',
        width: context.compositeWidth,
        height: context.compositeHeight,
        boxSizing: 'border-box',
        color: 'var(--gitci-color-fg)',
        background:
          'linear-gradient(135deg, color-mix(in oklab, var(--gitci-color-primary) 18%, var(--gitci-color-bg)), var(--gitci-color-bg) 52%, color-mix(in oklab, var(--gitci-color-secondary) 18%, var(--gitci-color-bg)))',
        fontFamily: 'var(--gitci-font-body)',
        overflow: 'hidden'
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: firstSafe.left,
          top: isWide ? 118 : 92,
          width: Math.min(firstSafe.width, isWide ? 980 : firstSafe.width)
        }}
      >
        <p
          style={{
            margin: '0 0 24px',
            fontSize: isWide ? 28 : 25,
            lineHeight: 1,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            color: 'var(--gitci-color-secondary)',
            fontWeight: 800
          }}
        >
          Scene spanning
        </p>
        <h1
          style={{
            margin: 0,
            fontFamily: 'var(--gitci-font-title)',
            fontSize: isWide ? 118 : 78,
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
              margin: '34px 0 0',
              maxWidth: 760,
              fontSize: isWide ? 35 : 29,
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
          position: 'absolute',
          left: imageLeft,
          top: isWide ? context.compositeHeight * 0.18 : context.compositeHeight * 0.32,
          width: imageWidth,
          borderRadius: 42,
          padding: 18,
          background: 'rgb(255 255 255 / 0.66)',
          boxShadow: '0 54px 140px rgb(15 23 42 / 0.22)',
          transform: isWide ? 'rotate(2deg)' : 'none'
        }}
      >
        <img
          src={props.screenshot.resolvedURL ?? props.screenshot.path}
          alt={props.screenshot.alt ?? ''}
          style={{
            display: 'block',
            width: '100%',
            borderRadius: 30
          }}
        />
      </div>
    </section>
  )
}
