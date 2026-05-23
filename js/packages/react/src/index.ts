import type { ReactNode } from 'react'

export type Appearance = 'light' | 'dark' | 'automatic'

export type AssetRef =
  | {
      kind: 'asset'
      path: string
      resolvedURL?: string
      alt?: string
    }
  | {
      kind: 'data'
      mediaType: string
      base64: string
      alt?: string
    }
  | {
      kind: 'generated'
      id: string
      alt?: string
    }

export type ThemeSelection = {
  id: string
  palette?: string
  paletteMap?: Record<string, number>
  overrides?: Record<string, string>
}

export type SceneVariant = {
  id: string
  sceneTemplate: string
  includeTargets?: string[]
  excludeTargets?: string[]
  props: Record<string, unknown>
}

export type SceneSlot = {
  id: string
  label?: string
  selectedVariant?: string
  variants: SceneVariant[]
}

export type SceneSetDefinition = {
  id: string
  name?: string
  targets: string[]
  appearanceByTarget?: Record<string, Appearance>
  theme?: ThemeSelection
  locales?: Array<{
    id: string
    name?: string
    strings: Record<string, string>
  }>
  slots: SceneSlot[]
}

export type RenderTargetContext = {
  id: string
  width: number
  height: number
  displayGapPx: number
  appearance: Exclude<Appearance, 'automatic'>
}

export type TimelineContext = {
  mode: 'static' | 'frame' | 'interactive'
  timeMs: number
  durationMs?: number
  frameIndex?: number
  fps?: number
}

export type SpanRect = {
  index: number
  x: number
  y: number
  width: number
  height: number
  left: number
  right: number
  top: number
  bottom: number
  centerX: number
  centerY: number
}

export type SpanGapRect = SpanRect & {
  beforeFrameIndex: number
  afterFrameIndex: number
}

export type SpanGapEdge = 'before' | 'after'

export type SpanLayout = {
  span: number
  frameWidth: number
  frameHeight: number
  gapWidth: number
  compositeWidth: number
  compositeHeight: number
  frames: SpanRect[]
  gaps: SpanGapRect[]
}

export type RenderSceneContext = {
  locale?: {
    id: string
    name?: string
  }
  slotId: string
  variantId: string
  target: RenderTargetContext
  span: number
  compositeWidth: number
  compositeHeight: number
  spanLayout?: SpanLayout
  themeVars: Record<string, string>
  assetBaseURL?: string
  timeline?: TimelineContext
}

export type SceneTemplateProps<P extends Record<string, unknown>> = {
  props: P
  context: RenderSceneContext
}

export type SceneTemplateComponent<
  P extends Record<string, unknown> = Record<string, unknown>
> = (input: SceneTemplateProps<P>) => ReactNode

export type Registry = {
  sceneTemplates: Record<string, SceneTemplateComponent<any>>
  components: Record<string, (props: any) => ReactNode>
}

export function defineSceneSet<T extends SceneSetDefinition>(definition: T): T {
  return definition
}

export function defineRegistry<T extends Registry>(registry: T): T {
  return registry
}

export function createSpanLayout(input: {
  span: number
  target: {
    width: number
    height: number
    displayGapPx: number
  }
  compositeWidth: number
  compositeHeight: number
}): SpanLayout {
  const span = Math.max(1, Math.floor(input.span))
  const frameWidth = input.target.width
  const frameHeight = input.target.height
  const gapWidth = input.target.displayGapPx
  const frames = Array.from({ length: span }, (_, index) => {
    const x = index * (frameWidth + gapWidth)
    return makeRect(index, x, 0, frameWidth, frameHeight)
  })
  const gaps = Array.from({ length: Math.max(0, span - 1) }, (_, index) => {
    const x = frameWidth + index * (frameWidth + gapWidth)
    return {
      ...makeRect(index, x, 0, gapWidth, frameHeight),
      beforeFrameIndex: index,
      afterFrameIndex: index + 1
    }
  })

  return {
    span,
    frameWidth,
    frameHeight,
    gapWidth,
    compositeWidth: input.compositeWidth,
    compositeHeight: input.compositeHeight,
    frames,
    gaps
  }
}

export function spanLayout(context: RenderSceneContext): SpanLayout {
  return context.spanLayout ?? createSpanLayout(context)
}

export function frameRect(context: RenderSceneContext, index: number): SpanRect {
  const rect = spanLayout(context).frames[index]
  if (!rect) {
    throw new Error(`No frame at span index ${index}`)
  }
  return rect
}

export function firstFrameRect(context: RenderSceneContext): SpanRect {
  return frameRect(context, 0)
}

export function lastFrameRect(context: RenderSceneContext): SpanRect {
  return frameRect(context, spanLayout(context).frames.length - 1)
}

export function gapRect(context: RenderSceneContext, index: number): SpanGapRect | undefined {
  return spanLayout(context).gaps[index]
}

export function gapEdgeX(
  context: RenderSceneContext,
  index: number,
  edge: SpanGapEdge
): number | undefined {
  const gap = gapRect(context, index)
  if (!gap) return undefined
  return edge === 'before' ? gap.left : gap.right
}

export function insetRect(rect: SpanRect, inset: number): SpanRect {
  return makeRect(
    rect.index,
    rect.x + inset,
    rect.y + inset,
    Math.max(0, rect.width - inset * 2),
    Math.max(0, rect.height - inset * 2)
  )
}

function makeRect(index: number, x: number, y: number, width: number, height: number): SpanRect {
  return {
    index,
    x,
    y,
    width,
    height,
    left: x,
    right: x + width,
    top: y,
    bottom: y + height,
    centerX: x + width / 2,
    centerY: y + height / 2
  }
}
