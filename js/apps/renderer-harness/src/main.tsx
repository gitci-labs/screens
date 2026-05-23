import React from 'react'
import { createRoot } from 'react-dom/client'
import { createSpanLayout, type Registry } from '@gitci/screens-react'
import { registry as builtinRegistry } from '@gitci/screens-templates-core'
import './style.css'

type RenderPlan = {
  schemaVersion: number
  targets: Array<{
    id: string
    width: number
    height: number
    displayGapPx: number
    appearance: 'light' | 'dark'
    themeVars: Record<string, string>
    outputs: Array<{
      locale?: {
        id: string
        name?: string
      }
      slotId: string
      variantId: string
      sceneTemplate: string
      span: number
      compositeWidth: number
      compositeHeight: number
      props: Record<string, unknown>
    }>
  }>
  registry: {
    moduleURL: string
  }
}

declare global {
  interface Window {
    __gitciScreensReady?: boolean
    __gitciScreensError?: string
  }
}

function applyThemeVars(vars: Record<string, string>) {
  const root = document.documentElement
  for (const [key, value] of Object.entries(vars)) {
    root.style.setProperty(key, value)
  }
}

async function loadRegistry(moduleURL: string): Promise<Registry> {
  if (moduleURL === 'builtin:gitci.core') {
    return builtinRegistry
  }
  const module = await import(/* @vite-ignore */ moduleURL)
  return module.registry as Registry
}

function RenderOne({
  registry,
  target,
  output
}: {
  registry: Registry
  target: RenderPlan['targets'][number]
  output: RenderPlan['targets'][number]['outputs'][number]
}) {
  const Template = registry.sceneTemplates[output.sceneTemplate]
  if (!Template) {
    throw new Error(`Missing scene template: ${output.sceneTemplate}`)
  }
  applyThemeVars(target.themeVars)

  const spanLayout = createSpanLayout({
    span: output.span,
    target: {
      width: target.width,
      height: target.height,
      displayGapPx: target.displayGapPx
    },
    compositeWidth: output.compositeWidth,
    compositeHeight: output.compositeHeight
  })

  return (
    <div
      id="gitci-render-root"
      data-gitci-ready="false"
      style={{
        width: output.compositeWidth,
        height: output.compositeHeight,
        overflow: 'hidden',
        background: 'var(--gitci-color-bg)'
      }}
    >
      <Template
        props={output.props}
        context={{
          locale: output.locale,
          slotId: output.slotId,
          variantId: output.variantId,
          target: {
            id: target.id,
            width: target.width,
            height: target.height,
            displayGapPx: target.displayGapPx,
            appearance: target.appearance
          },
          span: output.span,
          compositeWidth: output.compositeWidth,
          compositeHeight: output.compositeHeight,
          spanLayout,
          themeVars: target.themeVars,
          timeline: {
            mode: 'static',
            timeMs: 0
          }
        }}
      />
    </div>
  )
}

async function waitForAssets() {
  await document.fonts?.ready
  const images = Array.from(document.images)
  await Promise.all(
    images.map(image => {
      if (image.complete) return Promise.resolve()
      return new Promise<void>((resolve, reject) => {
        image.onload = () => resolve()
        image.onerror = () => reject(new Error(`Image failed: ${image.src}`))
      })
    })
  )
  await new Promise(requestAnimationFrame)
  await new Promise(requestAnimationFrame)
}

async function boot() {
  try {
    const searchParams = new URLSearchParams(location.search)
    const planURL = searchParams.get('plan')
    if (!planURL) {
      throw new Error('Missing ?plan=')
    }
    const outputIndex = Number(searchParams.get('output') ?? '0')
    const targetIndex = Number(searchParams.get('target') ?? '0')
    const plan = (await fetch(planURL).then(response => response.json())) as RenderPlan
    const registry = await loadRegistry(plan.registry.moduleURL)
    const target = plan.targets[targetIndex]
    const output = target.outputs[outputIndex]

    document.body.style.margin = '0'
    document.body.style.width = `${output.compositeWidth}px`
    document.body.style.height = `${output.compositeHeight}px`
    document.documentElement.style.width = `${output.compositeWidth}px`
    document.documentElement.style.height = `${output.compositeHeight}px`

    createRoot(document.getElementById('root')!).render(
      <RenderOne registry={registry} target={target} output={output} />
    )
    await waitForAssets()
    document.getElementById('gitci-render-root')?.setAttribute('data-gitci-ready', 'true')
    window.__gitciScreensReady = true
  } catch (error) {
    window.__gitciScreensError = error instanceof Error ? error.message : String(error)
    window.__gitciScreensReady = false
    throw error
  }
}

boot()
