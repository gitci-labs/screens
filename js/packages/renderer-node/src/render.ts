import { createServer, type IncomingMessage, type ServerResponse } from 'node:http'
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises'
import { createReadStream } from 'node:fs'
import { dirname, extname, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { chromium } from 'playwright'
import react from '@vitejs/plugin-react'
import { build as viteBuild } from 'vite'

declare global {
  interface Window {
    __gitciScreensReady?: boolean
    __gitciScreensError?: string
  }
}

type Clip = {
  x: number
  y: number
  width: number
  height: number
}

type Output = {
  slotId: string
  variantId: string
  sceneTemplate: string
  compositeWidth: number
  compositeHeight: number
  clip: Clip
  outputPath: string
  props: unknown
}

type Target = {
  id: string
  width: number
  height: number
  appearance: 'light' | 'dark'
  outputs: Output[]
}

type RenderPlan = {
  outputDirectory: string
  registry: {
    moduleURL: string
    sceneTemplates?: RegistryEntry[]
  }
  targets: Target[]
}

type RegistryEntry = {
  id: string
  entry: string
  exportName: string
}

type Args = {
  planPath: string
}

function parseArgs(): Args {
  const planIndex = process.argv.indexOf('--plan')
  if (planIndex === -1 || !process.argv[planIndex + 1]) {
    throw new Error('Missing --plan path')
  }
  return {
    planPath: resolve(process.argv[planIndex + 1])
  }
}

function contentType(pathname: string): string {
  switch (extname(pathname)) {
    case '.html':
      return 'text/html; charset=utf-8'
    case '.js':
      return 'text/javascript; charset=utf-8'
    case '.css':
      return 'text/css; charset=utf-8'
    case '.json':
      return 'application/json; charset=utf-8'
    case '.svg':
      return 'image/svg+xml'
    case '.png':
      return 'image/png'
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg'
    case '.webp':
      return 'image/webp'
    default:
      return 'application/octet-stream'
  }
}

function rewriteAssetsForBrowser(value: unknown, baseURL: string): unknown {
  if (Array.isArray(value)) {
    return value.map(item => rewriteAssetsForBrowser(item, baseURL))
  }
  if (!value || typeof value !== 'object') {
    return value
  }

  const object = value as Record<string, unknown>
  const rewritten: Record<string, unknown> = {}
  for (const [key, item] of Object.entries(object)) {
    rewritten[key] = rewriteAssetsForBrowser(item, baseURL)
  }

  if (rewritten.kind === 'asset' && typeof rewritten.resolvedURL === 'string') {
    const resolved = new URL(rewritten.resolvedURL)
    if (resolved.protocol === 'file:') {
      rewritten.resolvedURL = `${baseURL}/__gitci_asset?path=${encodeURIComponent(fileURLToPath(resolved))}`
    }
  }
  return rewritten
}

function makeBrowserPlan(plan: RenderPlan, baseURL: string, registryURL?: string): RenderPlan {
  const browserPlan = rewriteAssetsForBrowser(plan, baseURL) as RenderPlan
  if (registryURL) {
    browserPlan.registry = {
      ...browserPlan.registry,
      moduleURL: registryURL
    }
  }
  return browserPlan
}

function packageRoot(): string {
  return resolve(dirname(fileURLToPath(import.meta.url)), '..')
}

function harnessDist(): string {
  return resolve(packageRoot(), '../../apps/renderer-harness/dist')
}

function workspaceRoot(): string {
  return resolve(packageRoot(), '../..')
}

function importSpecifier(entry: string): string {
  if (entry.startsWith('/') || entry.startsWith('.') || entry.startsWith('@') || /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(entry)) {
    return entry
  }
  return entry
}

function generatedRegistrySource(entries: RegistryEntry[]): string {
  const imports = entries.map((entry, index) => {
    return `import { ${entry.exportName} as SceneTemplate${index} } from ${JSON.stringify(importSpecifier(entry.entry))}`
  })
  const sceneTemplates = entries.map((entry, index) => {
    return `${JSON.stringify(entry.id)}: SceneTemplate${index}`
  })
  return [
    "import { defineRegistry } from '@gitci/screens-react'",
    ...imports,
    '',
    'export const registry = defineRegistry({',
    '  sceneTemplates: {',
    `    ${sceneTemplates.join(',\n    ')}`,
    '  },',
    '  components: {}',
    '})',
    ''
  ].join('\n')
}

async function buildGeneratedRegistry(plan: RenderPlan): Promise<{ bundlePath?: string; tempDir?: string }> {
  const entries = plan.registry.sceneTemplates ?? []
  if (plan.registry.moduleURL === 'builtin:gitci.core' || entries.length === 0) {
    return {}
  }

  const tempDir = await mkdtemp(resolve(tmpdir(), 'gitci-screens-registry-'))
  const entryPath = resolve(tempDir, 'registry.ts')
  const outDir = resolve(tempDir, 'dist')
  await writeFile(entryPath, generatedRegistrySource(entries), 'utf8')

  const root = workspaceRoot()
  await viteBuild({
    root,
    logLevel: 'warn',
    plugins: [react()],
    define: {
      'process.env.NODE_ENV': JSON.stringify('production')
    },
    resolve: {
      alias: [
        {
          find: 'react/jsx-runtime',
          replacement: resolve(root, 'packages/templates-core/node_modules/react/jsx-runtime.js')
        },
        {
          find: 'react',
          replacement: resolve(root, 'packages/templates-core/node_modules/react/index.js')
        },
        {
          find: '@gitci/screens-react',
          replacement: resolve(root, 'packages/react/src/index.ts')
        },
        {
          find: '@gitci/screens-templates-core/experimental',
          replacement: resolve(root, 'packages/templates-core/src/experimental.ts')
        },
        {
          find: '@gitci/screens-templates-core',
          replacement: resolve(root, 'packages/templates-core/src/index.ts')
        }
      ]
    },
    build: {
      emptyOutDir: true,
      outDir,
      lib: {
        entry: entryPath,
        formats: ['es'],
        fileName: () => 'registry.mjs'
      }
    }
  })

  return {
    bundlePath: resolve(outDir, 'registry.mjs'),
    tempDir
  }
}

async function serveStaticFile(root: string, pathname: string, response: ServerResponse) {
  const normalized = pathname === '/' ? '/index.html' : pathname
  const filePath = resolve(root, `.${decodeURIComponent(normalized)}`)
  if (!filePath.startsWith(root)) {
    response.writeHead(403)
    response.end('Forbidden')
    return
  }

  try {
    await stat(filePath)
    response.writeHead(200, { 'content-type': contentType(filePath) })
    createReadStream(filePath).pipe(response)
  } catch {
    response.writeHead(404)
    response.end('Not found')
  }
}

async function createRenderServer(plan: RenderPlan, registryBundlePath?: string) {
  const root = harnessDist()
  const server = createServer(async (request: IncomingMessage, response: ServerResponse) => {
    try {
      const host = request.headers.host ?? '127.0.0.1'
      const url = new URL(request.url ?? '/', `http://${host}`)
      const baseURL = `http://${host}`

      if (url.pathname === '/__gitci_plan.json') {
        const registryURL = registryBundlePath ? `${baseURL}/__gitci_registry.mjs` : undefined
        const browserPlan = makeBrowserPlan(plan, baseURL, registryURL)
        response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' })
        response.end(JSON.stringify(browserPlan))
        return
      }

      if (url.pathname === '/__gitci_registry.mjs' && registryBundlePath) {
        response.writeHead(200, { 'content-type': 'text/javascript; charset=utf-8' })
        createReadStream(registryBundlePath).pipe(response)
        return
      }

      if (url.pathname === '/__gitci_asset') {
        const assetPath = url.searchParams.get('path')
        if (!assetPath) {
          response.writeHead(400)
          response.end('Missing asset path')
          return
        }
        response.writeHead(200, { 'content-type': contentType(assetPath) })
        createReadStream(assetPath).pipe(response)
        return
      }

      await serveStaticFile(root, url.pathname, response)
    } catch (error) {
      response.writeHead(500)
      response.end(error instanceof Error ? error.message : String(error))
    }
  })

  await new Promise<void>((resolveServer, rejectServer) => {
    server.once('error', rejectServer)
    server.listen(0, '127.0.0.1', () => resolveServer())
  })
  const address = server.address()
  if (!address || typeof address === 'string') {
    throw new Error('Could not determine render server address')
  }
  return {
    server,
    baseURL: `http://127.0.0.1:${address.port}`
  }
}

async function main() {
  const args = parseArgs()
  const plan = JSON.parse(await readFile(args.planPath, 'utf8')) as RenderPlan
  const generatedRegistry = await buildGeneratedRegistry(plan)
  const { server, baseURL } = await createRenderServer(plan, generatedRegistry.bundlePath)
  const browser = await chromium.launch({ headless: true })

  try {
    for (const [targetIndex, target] of plan.targets.entries()) {
      for (const [outputIndex, output] of target.outputs.entries()) {
        const context = await browser.newContext({
          viewport: {
            width: output.compositeWidth,
            height: output.compositeHeight
          },
          deviceScaleFactor: 1,
          colorScheme: target.appearance
        })
        const page = await context.newPage()
        const url = new URL(baseURL)
        url.searchParams.set('plan', `${baseURL}/__gitci_plan.json`)
        url.searchParams.set('target', String(targetIndex))
        url.searchParams.set('output', String(outputIndex))

        await page.goto(url.toString(), { waitUntil: 'load' })
        await page.waitForFunction(() => {
          return window.__gitciScreensReady === true || Boolean(window.__gitciScreensError)
        })
        const error = await page.evaluate(() => window.__gitciScreensError)
        if (error) {
          throw new Error(error)
        }

        const outputPath = resolve(plan.outputDirectory, output.outputPath)
        await mkdir(dirname(outputPath), { recursive: true })
        await page.screenshot({
          path: outputPath,
          type: 'png',
          clip: output.clip,
          scale: 'css',
          animations: 'disabled',
          caret: 'hide'
        })
        await context.close()
      }
    }
  } finally {
    await browser.close()
    await new Promise<void>(resolveClose => server.close(() => resolveClose()))
    if (generatedRegistry.tempDir) {
      await rm(generatedRegistry.tempDir, { recursive: true, force: true })
    }
  }
}

main().catch(error => {
  console.error(error)
  process.exit(1)
})
