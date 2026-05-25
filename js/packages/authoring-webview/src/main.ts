import * as esbuild from 'esbuild-wasm'
import wasmURL from 'esbuild-wasm/esbuild.wasm?url'

type SceneSetDefinition = {
  schemaVersion?: number
  id: string
  name?: string
  entry?: string
  export?: string
  targets: string[]
  appearanceByTarget?: Record<string, 'light' | 'dark' | 'automatic'>
  theme?: unknown
  locales?: unknown[]
  variantGroups?: unknown[]
  slots: unknown[]
}

type EvaluateSceneSetInput = {
  entryPath: string
  exportName: string
  manifest: {
    schemaVersion: number
    id: string
    name?: string
    entry?: string
    export?: string
  }
}

declare global {
  interface Window {
    gitciReadTextFile?: (path: string) => Promise<string>
    gitciScreensAuthoring?: {
      evaluateSceneSet(input: EvaluateSceneSetInput): Promise<SceneSetDefinition>
      evaluateSceneSetJSON(inputJSON: string): Promise<string>
    }
    gitciScreensAuthoringReady?: boolean
  }
}

const fileLoaders = new Map<string, esbuild.Loader>([
  ['.js', 'js'],
  ['.jsx', 'jsx'],
  ['.ts', 'ts'],
  ['.tsx', 'tsx'],
  ['.json', 'json'],
  ['.css', 'css']
])

let initialized: Promise<void> | undefined

function initializeEsbuild() {
  initialized ??= esbuild.initialize({
    wasmURL,
    worker: false
  })
  return initialized
}

async function evaluateSceneSet(input: EvaluateSceneSetInput): Promise<SceneSetDefinition> {
  await initializeEsbuild()
  const entryPath = normalizePath(input.entryPath)
  const result = await esbuild.build({
    entryPoints: [entryPath],
    bundle: true,
    write: false,
    format: 'esm',
    platform: 'browser',
    target: 'es2022',
    jsx: 'automatic',
    absWorkingDir: '/',
    plugins: [gitciAuthoringPlugin()]
  })
  const bundled = result.outputFiles[0]?.text
  if (!bundled) {
    throw new Error(`No bundle output for ${entryPath}`)
  }

  const moduleURL = URL.createObjectURL(new Blob([bundled], { type: 'text/javascript' }))
  try {
    const module = await import(/* @vite-ignore */ moduleURL)
    const exported = module[input.exportName]
    if (exported === undefined) {
      throw new Error(`Missing export ${input.exportName}`)
    }
    const sceneSet = normalizeSceneSetExport(exported, input.manifest)
    return {
      schemaVersion: 1,
      name: input.manifest.name,
      entry: input.manifest.entry,
      export: input.manifest.export,
      ...sceneSet,
      id: sceneSet.id || input.manifest.id
    }
  } finally {
    URL.revokeObjectURL(moduleURL)
  }
}

function gitciAuthoringPlugin(): esbuild.Plugin {
  return {
    name: 'gitci-authoring-webview',
    setup(build) {
      build.onResolve({ filter: /^@gitci\/screens-react$/ }, () => ({
        path: '@gitci/screens-react',
        namespace: 'gitci-virtual'
      }))
      build.onResolve({ filter: /^react\/jsx-runtime$/ }, () => ({
        path: 'react/jsx-runtime',
        namespace: 'gitci-virtual'
      }))
      build.onResolve({ filter: /^react$/ }, () => ({
        path: 'react',
        namespace: 'gitci-virtual'
      }))
      build.onResolve({ filter: /^file:\/\// }, args => ({
        path: normalizePath(new URL(args.path).pathname),
        namespace: 'gitci-file'
      }))
      build.onResolve({ filter: /^\// }, args => ({
        path: normalizePath(args.path),
        namespace: 'gitci-file'
      }))
      build.onResolve({ filter: /^\./ }, args => ({
        path: normalizePath(joinPath(args.resolveDir || '/', args.path)),
        namespace: 'gitci-file'
      }))

      build.onLoad({ filter: /.*/, namespace: 'gitci-virtual' }, args => ({
        contents: virtualModule(args.path),
        loader: 'js'
      }))
      build.onLoad({ filter: /.*/, namespace: 'gitci-file' }, async args => {
        const contents = await readTextFile(args.path)
        return {
          contents,
          loader: loaderForPath(args.path),
          resolveDir: dirname(args.path)
        }
      })
    }
  }
}

async function readTextFile(path: string): Promise<string> {
  if (!window.gitciReadTextFile) {
    throw new Error('gitciReadTextFile bridge is not installed')
  }
  return window.gitciReadTextFile(path)
}

function virtualModule(path: string): string {
  switch (path) {
    case 'react/jsx-runtime':
      return jsxRuntimeModule
    case 'react':
      return reactCompatModule
    case '@gitci/screens-react':
      return gitciScreensReactAuthoringModule
    default:
      throw new Error(`Unknown virtual module: ${path}`)
  }
}

function normalizeSceneSetExport(
  exported: unknown,
  manifest: EvaluateSceneSetInput['manifest']
): SceneSetDefinition {
  const value = typeof exported === 'function' ? exported() : exported
  if (isSceneSetDefinition(value)) {
    return value
  }
  const runtime = globalThis as typeof globalThis & {
    __gitciDefineSceneSetFromJSX?: (node: unknown) => SceneSetDefinition
  }
  if (runtime.__gitciDefineSceneSetFromJSX) {
    const definition = runtime.__gitciDefineSceneSetFromJSX(value)
    if (isSceneSetDefinition(definition)) {
      return definition
    }
  }
  throw new Error(`Export ${manifest.export ?? 'sceneSet'} did not produce a scene set definition`)
}

function isSceneSetDefinition(value: unknown): value is SceneSetDefinition {
  return Boolean(
    value &&
      typeof value === 'object' &&
      typeof (value as { id?: unknown }).id === 'string' &&
      Array.isArray((value as { targets?: unknown }).targets) &&
      Array.isArray((value as { slots?: unknown }).slots)
  )
}

function normalizePath(path: string) {
  return path.replace(/\/+/g, '/')
}

function joinPath(base: string, relative: string) {
  const parts = [...base.split('/'), ...relative.split('/')]
  const stack: string[] = []
  for (const part of parts) {
    if (!part || part === '.') continue
    if (part === '..') {
      stack.pop()
    } else {
      stack.push(part)
    }
  }
  return `/${stack.join('/')}`
}

function dirname(path: string) {
  const normalized = normalizePath(path)
  const index = normalized.lastIndexOf('/')
  return index <= 0 ? '/' : normalized.slice(0, index)
}

function loaderForPath(path: string): esbuild.Loader {
  for (const [suffix, loader] of fileLoaders) {
    if (path.endsWith(suffix)) return loader
  }
  return 'text'
}

window.gitciScreensAuthoring = {
  evaluateSceneSet,
  async evaluateSceneSetJSON(inputJSON: string) {
    return JSON.stringify(await evaluateSceneSet(JSON.parse(inputJSON) as EvaluateSceneSetInput))
  }
}
window.gitciScreensAuthoringReady = true

const jsxRuntimeModule = `
const ELEMENT = Symbol.for('gitci.screens.element');
export const Fragment = Symbol.for('gitci.screens.fragment');
export function jsx(type, props, key) {
  return { $$typeof: ELEMENT, type, key: key ?? null, props: props ?? {} };
}
export const jsxs = jsx;
export const jsxDEV = jsx;
`

const reactCompatModule = `
const ELEMENT = Symbol.for('gitci.screens.element');
export const Children = {
  toArray(children) {
    return children == null ? [] : Array.isArray(children) ? children.flat(Infinity) : [children];
  }
};
export function isValidElement(value) {
  return Boolean(value && typeof value === 'object' && value.$$typeof === ELEMENT);
}
export function createElement(type, props, ...children) {
  return {
    $$typeof: ELEMENT,
    type,
    key: props && props.key != null ? String(props.key) : null,
    props: { ...(props ?? {}), ...(children.length ? { children: children.length === 1 ? children[0] : children } : {}) }
  };
}
export default { Children, isValidElement, createElement };
`

const gitciScreensReactAuthoringModule = `
const ELEMENT = Symbol.for('gitci.screens.element');
const RESERVED_SCENE_PROPS = new Set(['id', 'template', 'sceneTemplate', 'includeTargets', 'excludeTargets', 'props', 'children']);

export function defineSceneSet(definition) {
  return definition;
}
export function SceneSet(_props) { return null; }
export function Slot(_props) { return null; }
export function Scene(_props) { return null; }
export function VariantGroup(_props) { return null; }
export function asset(path, options) {
  return { kind: 'asset', path, alt: typeof options === 'string' ? options : options?.alt };
}
export function dataAsset(input) {
  return { kind: 'data', mediaType: input.mediaType, base64: input.base64, alt: input.alt };
}
export function defineSceneSetFromJSX(node) {
  const element = resolveAuthoringElement(node);
  assertElementType(element, SceneSet, 'SceneSet');
  const { children, variantGroups: declaredVariantGroups, ...sceneSetProps } = element.props;
  const variantGroups = [...(declaredVariantGroups ?? [])];
  const slots = [];
  for (const child of childAuthoringElements(children)) {
    if (child.type === VariantGroup) {
      const { children: _children, ...variantGroup } = child.props;
      variantGroups.push(variantGroup);
    } else if (child.type === Slot) {
      slots.push(slotFromElement(child));
    } else {
      throw new Error('SceneSet children must be <Slot> or <VariantGroup> elements');
    }
  }
  return defineSceneSet({
    ...sceneSetProps,
    variantGroups: variantGroups.length ? variantGroups : undefined,
    slots
  });
}
globalThis.__gitciDefineSceneSetFromJSX = defineSceneSetFromJSX;

function slotFromElement(element) {
  const { children, ...slotProps } = element.props;
  const variants = childAuthoringElements(children).map(child => {
    assertElementType(child, Scene, 'Scene');
    return sceneFromElement(child);
  });
  return { ...slotProps, variants };
}
function sceneFromElement(element) {
  const { id, template, sceneTemplate, includeTargets, excludeTargets, props, children, ...inlineProps } = element.props;
  if (children != null) {
    throw new Error('<Scene> does not support children yet');
  }
  const resolvedTemplate = sceneTemplate ?? template;
  if (!resolvedTemplate || typeof resolvedTemplate !== 'string') {
    throw new Error('<Scene> requires template or sceneTemplate');
  }
  return {
    id,
    sceneTemplate: resolvedTemplate,
    includeTargets,
    excludeTargets,
    props: { ...inlineProps, ...(props ?? {}) }
  };
}
function childAuthoringElements(children) {
  const values = children == null ? [] : Array.isArray(children) ? children.flat(Infinity) : [children];
  return values.filter(value => value !== null && value !== undefined && value !== false).map(resolveAuthoringElement);
}
function resolveAuthoringElement(node) {
  if (!isValidElement(node)) {
    throw new Error('Expected a GitCI Screens authoring element');
  }
  if (
    typeof node.type === 'function' &&
    ![SceneSet, Slot, Scene, VariantGroup].includes(node.type)
  ) {
    return resolveAuthoringElement(node.type(node.props));
  }
  return node;
}
function assertElementType(element, type, name) {
  if (element.type !== type) {
    throw new Error('Expected <' + name + '>');
  }
}
function isValidElement(value) {
  return Boolean(value && typeof value === 'object' && value.$$typeof === ELEMENT);
}
`
