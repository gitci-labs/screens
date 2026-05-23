import { describe, expect, it } from 'vitest'
import {
  createSpanLayout,
  firstFrameRect,
  frameRect,
  gapEdgeX,
  gapRect,
  insetRect,
  lastFrameRect
} from '../packages/react/src/index'

describe('span layout helpers', () => {
  it('describes frame and gap edges for spanned scenes', () => {
    const layout = createSpanLayout({
      span: 2,
      target: {
        width: 1320,
        height: 2868,
        displayGapPx: 80
      },
      compositeWidth: 2720,
      compositeHeight: 2868
    })

    expect(layout.frames[0].left).toBe(0)
    expect(layout.frames[0].right).toBe(1320)
    expect(layout.gaps[0].left).toBe(1320)
    expect(layout.gaps[0].right).toBe(1400)
    expect(layout.frames[1].left).toBe(1400)
    expect(layout.frames[1].right).toBe(2720)
  })

  it('can derive layout from a render context', () => {
    const context = {
      slotId: 'span',
      variantId: 'default',
      target: {
        id: 'appstore.iphone.6_9.portrait',
        width: 1320,
        height: 2868,
        displayGapPx: 80,
        appearance: 'light' as const
      },
      span: 2,
      compositeWidth: 2720,
      compositeHeight: 2868,
      themeVars: {}
    }

    expect(frameRect(context, 1).left).toBe(1400)
    expect(gapRect(context, 0)?.width).toBe(80)
  })

  it('exposes stable frame and gap-edge anchors for template layout', () => {
    const context = {
      slotId: 'span',
      variantId: 'default',
      target: {
        id: 'appstore.iphone.6_9.portrait',
        width: 1320,
        height: 2868,
        displayGapPx: 80,
        appearance: 'light' as const
      },
      span: 3,
      compositeWidth: 4120,
      compositeHeight: 2868,
      themeVars: {}
    }

    expect(firstFrameRect(context).left).toBe(0)
    expect(lastFrameRect(context).left).toBe(2800)
    expect(gapEdgeX(context, 0, 'before')).toBe(1320)
    expect(gapEdgeX(context, 0, 'after')).toBe(1400)
    expect(insetRect(lastFrameRect(context), 96).left).toBe(2896)
  })
})
