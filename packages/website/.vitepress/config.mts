import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig, type SiteConfig } from 'vitepress'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const SITE_URL = 'https://skir.build'

const docsPagesForLlms = [
  'setup.md',
  'examples.md',
  'language-reference.md',
  'serialization.md',
  'schema-evolution.md',
  'skirrpc.md',
  'github-imports.md',
  'best-practices.md',
  'code-generators.md',
  'protobuf.md',
  'languages/cpp.md',
  'languages/csharp.md',
  'languages/dart.md',
  'languages/elixir.md',
  'languages/fsharp.md',
  'languages/gleam.md',
  'languages/go.md',
  'languages/java.md',
  'languages/kotlin.md',
  'languages/moonbit.md',
  'languages/ocaml.md',
  'languages/python.md',
  'languages/ruby.md',
  'languages/rust.md',
  'languages/scala.md',
  'languages/swift.md',
  'languages/typescript.md',
  'languages/zig.md',
]

function generateLlmsFiles(siteConfig: SiteConfig): void {
  const docsRoot = path.resolve(__dirname, '../../../docs')
  const fullSections: string[] = ['# Skir Documentation', '', `Source: ${SITE_URL}`]

  for (const relDocPath of docsPagesForLlms) {
    const srcPath = path.join(docsRoot, relDocPath)
    if (!fs.existsSync(srcPath)) continue
    const raw = fs.readFileSync(srcPath, 'utf8').trim()
    const outRelPath = relDocPath.startsWith('languages/')
      ? `docs/${path.basename(relDocPath)}`
      : `docs/${relDocPath}`
    const outMdPath = path.join(siteConfig.outDir, outRelPath)
    fs.mkdirSync(path.dirname(outMdPath), { recursive: true })
    fs.writeFileSync(outMdPath, `${raw}\n`, 'utf8')

    const url = `${SITE_URL}/${outRelPath}`
    fullSections.push('', '---', '', `<!-- Source: ${url} -->`, '', raw)
  }

  fs.writeFileSync(
    path.join(siteConfig.outDir, 'llms-full.txt'),
    `${fullSections.join('\n')}\n`,
    'utf8',
  )
}

/**
 * Custom syntax highlighter for `skir` fenced code blocks.
 * Emits VitePress / Shiki dual-theme CSS variables (`--shiki-light` / `--shiki-dark`)
 * so light/dark mode switches instantaneously without client-side JS flashes.
 */
function highlightSkirCode(code: string): string {
  const TOKENS = {
    comment: '--shiki-light:#6A737D;--shiki-dark:#6A737D;font-style:italic;',
    docComment: '--shiki-light:#22863A;--shiki-dark:#85E89D;font-style:italic;',
    docRef: '--shiki-light:#015D67;--shiki-dark:#0CC8C1;font-weight:600;',
    keyword: '--shiki-light:#D73A49;--shiki-dark:#F97583;',
    primitive: '--shiki-light:#005CC5;--shiki-dark:#79B8FF;',
    typeIdent: '--shiki-light:#6F42C1;--shiki-dark:#B392F0;',
    number: '--shiki-light:#005CC5;--shiki-dark:#79B8FF;',
    string: '--shiki-light:#032F62;--shiki-dark:#9ECBFF;',
    plain: '--shiki-light:#24292E;--shiki-dark:#E1E4E8;',
  }

  const KEYWORDS = new Set([
    'struct',
    'enum',
    'method',
    'const',
    'import',
    'from',
    'as',
    'removed',
    'true',
    'false',
    'null',
    'Infinity',
    '-Infinity',
    'NaN',
  ])

  const PRIMITIVES = new Set([
    'bool',
    'int32',
    'int64',
    'hash64',
    'float32',
    'float64',
    'timestamp',
    'string',
    'bytes',
  ])

  function escapeHtml(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
  }

  function span(style: string, text: string): string {
    return `<span style="${style}">${escapeHtml(text)}</span>`
  }

  function highlightDocCommentLine(line: string): string {
    const parts: string[] = []
    const regex = /\[[^\]]+\]/g
    let last = 0
    let m: RegExpExecArray | null
    while ((m = regex.exec(line)) !== null) {
      if (m.index > last) {
        parts.push(span(TOKENS.docComment, line.slice(last, m.index)))
      }
      parts.push(span(TOKENS.docRef, m[0]))
      last = m.index + m[0].length
    }
    if (last < line.length) {
      parts.push(span(TOKENS.docComment, line.slice(last)))
    }
    return parts.join('')
  }

  function highlightCodeLine(line: string): string {
    const trimmed = line.trimStart()
    if (trimmed.startsWith('///')) {
      const leadLen = line.length - trimmed.length
      const lead = leadLen > 0 ? span(TOKENS.plain, line.slice(0, leadLen)) : ''
      return lead + highlightDocCommentLine(trimmed)
    }

    const tokenRegex =
      /(\/\/.*$)|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|\b(-?(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?))\b|\b([A-Za-z_][A-Za-z0-9_]*)\b/g

    const out: string[] = []
    let lastIdx = 0
    let match: RegExpExecArray | null
    while ((match = tokenRegex.exec(line)) !== null) {
      if (match.index > lastIdx) {
        out.push(span(TOKENS.plain, line.slice(lastIdx, match.index)))
      }
      const [full, comment, strLit, numLit, ident] = match
      if (comment !== undefined) {
        out.push(span(TOKENS.comment, full))
      } else if (strLit !== undefined) {
        out.push(span(TOKENS.string, full))
      } else if (numLit !== undefined) {
        out.push(span(TOKENS.number, full))
      } else if (ident !== undefined) {
        if (KEYWORDS.has(ident)) {
          out.push(span(TOKENS.keyword, full))
        } else if (PRIMITIVES.has(ident)) {
          out.push(span(TOKENS.primitive, full))
        } else if (/^[A-Z]/.test(ident) && ident !== ident.toUpperCase()) {
          out.push(span(TOKENS.typeIdent, full))
        } else {
          out.push(span(TOKENS.plain, full))
        }
      }
      lastIdx = match.index + full.length
    }
    if (lastIdx < line.length) {
      out.push(span(TOKENS.plain, line.slice(lastIdx)))
    }
    return out.join('')
  }

  const rawLines = code.replace(/\n$/, '').split('\n')
  const renderedLines = rawLines.map((l) => `<span class="line">${highlightCodeLine(l)}</span>`)
  return `<pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0" v-pre><code>${renderedLines.join('\n')}</code></pre>`
}

export default defineConfig({
  title: 'Skir',
  titleTemplate: ':title - Skir Documentation',
  description:
    'Skir is a modern declarative schema language for data models and APIs. Write once in a .skir file - instantly generate clean, idiomatic, and fully type-safe code.',
  srcDir: './src',
  outDir: './out',
  cleanUrls: true,
  ignoreDeadLinks: ['/converter.html'],
  buildEnd: generateLlmsFiles,
  rewrites: {
    'docs/README.md': 'docs/index.md',
    'docs/languages/:lang.md': 'docs/:lang.md',
  },

  vite: {
    publicDir: path.resolve(__dirname, '../public'),
    resolve: {
      preserveSymlinks: true,
    },
    server: {
      fs: {
        allow: [path.resolve(__dirname, '../../..')],
      },
    },
  },

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/icon.svg' }],
    ['link', { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/icon-32x32.png' }],
    ['link', { rel: 'apple-touch-icon', sizes: '180x180', href: '/icon-180x180.png' }],
    ['meta', { name: 'theme-color', content: '#0baaaa' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'Skir' }],
    [
      'meta',
      {
        property: 'og:title',
        content: 'Skir — The single source of truth for your data types',
      },
    ],
    [
      'meta',
      {
        property: 'og:description',
        content:
          'Skir is a modern declarative schema language for data models and APIs. Write once in a .skir file - instantly generate clean, idiomatic, and fully type-safe code.',
      },
    ],
    [
      'script',
      {
        defer: '',
        src: 'https://cloud.umami.is/script.js',
        'data-website-id': '7ef7116d-938a-4cf3-bbfb-679c0f57c0c9',
        'data-domains': 'skir.build',
      },
    ],
  ],

  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark',
    },
    languageAlias: {
      gradle: 'groovy',
      moonbit: 'rust',
    },
    config(md) {
      const defaultCodeInline = md.renderer.rules.code_inline!
      md.renderer.rules.code_inline = (tokens, idx, options, env, self) => {
        tokens[idx].attrSet('v-pre', '')
        return defaultCodeInline(tokens, idx, options, env, self)
      }

      const defaultFence = md.renderer.rules.fence!
      md.renderer.rules.fence = (tokens, idx, options, env, self) => {
        const token = tokens[idx]
        const info = token.info ? md.utils.unescapeAll(token.info).trim() : ''
        const langName = info.split(/\s+/g)[0]
        if (langName === 'skir') {
          const titleMatch = info.match(/\[([^\]]+)\]/)
          const preHtml = highlightSkirCode(token.content)
          const dataTitle = titleMatch ? ` data-title="${md.utils.escapeHtml(titleMatch[1])}"` : ''
          return `<div class="language-skir vp-adaptive-theme"${dataTitle}><button title="Copy Code" class="copy"></button><span class="lang">skir</span>${preHtml}</div>`
        }
        return defaultFence(tokens, idx, options, env, self)
      }
    },
  },

  themeConfig: {
    logo: '/icon.svg',
    siteTitle: 'Skir',

    nav: [
      { text: 'Docs', link: '/docs' },
      { text: 'Quickstart', link: '/docs/setup' },
      { text: 'Language reference', link: '/docs/language-reference' },
      {
        text: 'Generated code',
        items: [
          { text: 'C++', link: '/docs/cpp' },
          { text: 'C#', link: '/docs/csharp' },
          { text: 'Dart', link: '/docs/dart' },
          { text: 'Elixir', link: '/docs/elixir' },
          { text: 'F#', link: '/docs/fsharp' },
          { text: 'Gleam', link: '/docs/gleam' },
          { text: 'Go', link: '/docs/go' },
          { text: 'Java', link: '/docs/java' },
          { text: 'Kotlin', link: '/docs/kotlin' },
          { text: 'MoonBit', link: '/docs/moonbit' },
          { text: 'OCaml', link: '/docs/ocaml' },
          { text: 'Python', link: '/docs/python' },
          { text: 'Ruby', link: '/docs/ruby' },
          { text: 'Rust', link: '/docs/rust' },
          { text: 'Scala', link: '/docs/scala' },
          { text: 'Swift', link: '/docs/swift' },
          { text: 'TypeScript', link: '/docs/typescript' },
          { text: 'Zig', link: '/docs/zig' },
        ],
      },
      { text: 'Converter', link: '/converter.html', target: '_blank' },
    ],

    sidebar: [
      {
        text: 'Quickstart',
        items: [
          { text: 'Setup & workflow', link: '/docs/setup' },
          { text: 'Project examples', link: '/docs/examples' },
        ],
      },
      {
        text: 'Core concepts',
        items: [
          { text: 'Language reference', link: '/docs/language-reference' },
          { text: 'Serialization', link: '/docs/serialization' },
          { text: 'Schema evolution', link: '/docs/schema-evolution' },
          { text: 'SkirRPC', link: '/docs/skirrpc' },
          { text: 'GitHub imports', link: '/docs/github-imports' },
          { text: 'Best practices', link: '/docs/best-practices' },
        ],
      },
      {
        text: 'Extensibility',
        items: [{ text: 'Building a generator', link: '/docs/code-generators' }],
      },
      {
        text: 'Comparison',
        items: [{ text: 'Skir vs Protobuf', link: '/docs/protobuf' }],
      },
      {
        text: 'Generated code',
        items: [
          { text: 'C++', link: '/docs/cpp' },
          { text: 'C#', link: '/docs/csharp' },
          { text: 'Dart', link: '/docs/dart' },
          { text: 'Elixir', link: '/docs/elixir' },
          { text: 'F#', link: '/docs/fsharp' },
          { text: 'Gleam', link: '/docs/gleam' },
          { text: 'Go', link: '/docs/go' },
          { text: 'Java', link: '/docs/java' },
          { text: 'Kotlin', link: '/docs/kotlin' },
          { text: 'MoonBit', link: '/docs/moonbit' },
          { text: 'OCaml', link: '/docs/ocaml' },
          { text: 'Python', link: '/docs/python' },
          { text: 'Ruby', link: '/docs/ruby' },
          { text: 'Rust', link: '/docs/rust' },
          { text: 'Scala', link: '/docs/scala' },
          { text: 'Swift', link: '/docs/swift' },
          { text: 'TypeScript', link: '/docs/typescript' },
          { text: 'Zig', link: '/docs/zig' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'discord', link: 'https://discord.gg/FsKrGwJ9AP' },
      { icon: 'github', link: 'https://github.com/gepheum/skir' },
    ],

    search: {
      provider: 'local',
    },

    outline: {
      level: [2, 3],
      label: 'On this page',
    },
  },
})
