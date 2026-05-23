import { describe, expect, it } from 'vitest'
import Ajv2020 from 'ajv/dist/2020.js'
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { basename, join, resolve } from 'node:path'

const repoRoot = resolve(import.meta.dirname, '../..')

function readJSON(path: string): unknown {
  return JSON.parse(readFileSync(path, 'utf8'))
}

function walk(root: string): string[] {
  return readdirSync(root)
    .flatMap(name => {
      const path = join(root, name)
      if (statSync(path).isDirectory()) return walk(path)
      return [path]
    })
}

describe('GitCI manifest schemas', () => {
  const ajv = new Ajv2020({ allErrors: true })
  for (const schemaPath of walk(join(repoRoot, 'schemas')).filter(path => path.endsWith('.schema.json'))) {
    ajv.addSchema(readJSON(schemaPath))
  }

  const manifestSchemaByName: Record<string, string> = {
    'project.gitci.json': 'https://screens.gitci.com/schemas/project.gitci.schema.json',
    'scene-set.gitci.json': 'https://screens.gitci.com/schemas/scene-set.gitci.schema.json',
    'pack.gitci.json': 'https://screens.gitci.com/schemas/pack.gitci.schema.json',
    'scene-template.gitci.json': 'https://screens.gitci.com/schemas/scene-template.gitci.schema.json',
    'component.gitci.json': 'https://screens.gitci.com/schemas/component.gitci.schema.json',
    'theme.gitci.json': 'https://screens.gitci.com/schemas/theme.gitci.schema.json',
    'palette.gitci.json': 'https://screens.gitci.com/schemas/palette.gitci.schema.json',
    'appstore.gitci.json': 'https://screens.gitci.com/schemas/targets.gitci.schema.json'
  }

  const manifestPaths = [
    ...walk(join(repoRoot, 'examples')),
    ...walk(join(repoRoot, 'templates'))
  ].filter(path => manifestSchemaByName[basename(path)])

  it.each(manifestPaths.map(path => [path]))('validates %s', path => {
    const schemaId = manifestSchemaByName[basename(path)]
    const validate = ajv.getSchema(schemaId)
    expect(validate, `Missing schema ${schemaId}`).toBeDefined()
    const valid = validate!(readJSON(path))
    expect(validate!.errors).toEqual(null)
    expect(valid).toBe(true)
  })

  it('validates a generated output manifest shape', () => {
    const validate = ajv.getSchema('https://screens.gitci.com/schemas/output-manifest.gitci.schema.json')
    expect(validate, 'Missing output manifest schema').toBeDefined()
    const valid = validate!({
      schemaVersion: 1,
      buildId: 'launch-2026-05-23T06-00-00Z',
      sceneSet: {
        id: 'launch',
        name: 'Launch Screens'
      },
      targets: [
        {
          id: 'appstore.iphone.6_9.portrait',
          width: 1320,
          height: 2868,
          displayGapPx: 80,
          appearance: 'light',
          screenshots: [
            {
              slotId: 'span',
              variantId: 'default',
              sceneTemplate: 'example.minimal.split-proof',
              path: 'appstore.iphone.6_9.portrait/04-span-2.png',
              width: 1320,
              height: 2868,
              span: 2,
              spanIndex: 1,
              compositeWidth: 2720,
              compositeHeight: 2868,
              clip: {
                x: 1400,
                y: 0,
                width: 1320,
                height: 2868
              }
            }
          ]
        }
      ]
    })
    expect(validate!.errors).toEqual(null)
    expect(valid).toBe(true)
  })
})
