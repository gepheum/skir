'use client'

import { cn } from '@/lib/utils'
import { useTheme } from 'next-themes'
import type { ReactNode } from 'react'
import { useEffect, useRef, useState } from 'react'
// Use Light build to allow custom language registration
import { skirLanguage } from '@/lib/skir-language'
import { Light as SyntaxHighlighter } from 'react-syntax-highlighter'
import bash from 'react-syntax-highlighter/dist/esm/languages/hljs/bash'
import cmake from 'react-syntax-highlighter/dist/esm/languages/hljs/cmake'
import cpp from 'react-syntax-highlighter/dist/esm/languages/hljs/cpp'
import csharp from 'react-syntax-highlighter/dist/esm/languages/hljs/csharp'
import dart from 'react-syntax-highlighter/dist/esm/languages/hljs/dart'
import elixir from 'react-syntax-highlighter/dist/esm/languages/hljs/elixir'
import go from 'react-syntax-highlighter/dist/esm/languages/hljs/go'
import java from 'react-syntax-highlighter/dist/esm/languages/hljs/java'
import json from 'react-syntax-highlighter/dist/esm/languages/hljs/json'
import kotlin from 'react-syntax-highlighter/dist/esm/languages/hljs/kotlin'
import python from 'react-syntax-highlighter/dist/esm/languages/hljs/python'
import rust from 'react-syntax-highlighter/dist/esm/languages/hljs/rust'
import swift from 'react-syntax-highlighter/dist/esm/languages/hljs/swift'
import typescript from 'react-syntax-highlighter/dist/esm/languages/hljs/typescript'
import yaml from 'react-syntax-highlighter/dist/esm/languages/hljs/yaml'
import { atomOneDark, atomOneLight } from 'react-syntax-highlighter/dist/esm/styles/hljs'

// Register all languages used in docs
SyntaxHighlighter.registerLanguage('skir', skirLanguage)
SyntaxHighlighter.registerLanguage('typescript', typescript)
SyntaxHighlighter.registerLanguage('python', python)
SyntaxHighlighter.registerLanguage('csharp', csharp)
SyntaxHighlighter.registerLanguage('cpp', cpp)
SyntaxHighlighter.registerLanguage('go', go)
SyntaxHighlighter.registerLanguage('java', java)
SyntaxHighlighter.registerLanguage('kotlin', kotlin)
SyntaxHighlighter.registerLanguage('dart', dart)
SyntaxHighlighter.registerLanguage('elixir', elixir)
SyntaxHighlighter.registerLanguage('swift', swift)
SyntaxHighlighter.registerLanguage('rust', rust)
SyntaxHighlighter.registerLanguage('yaml', yaml)
SyntaxHighlighter.registerLanguage('bash', bash)
SyntaxHighlighter.registerLanguage('cmake', cmake)
SyntaxHighlighter.registerLanguage('json', json)

interface ProseProps {
  children: ReactNode
  className?: string
}

export function Prose({ children, className }: ProseProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const headings = container.querySelectorAll<HTMLElement>('h1, h2, h3, h4')
    if (headings.length === 0) return

    const usedIds = new Set<string>()

    const slugify = (value: string) =>
      value
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '')

    const ensureUniqueId = (baseId: string) => {
      let uniqueId = baseId
      let count = 1
      while (usedIds.has(uniqueId)) {
        uniqueId = `${baseId}-${count}`
        count++
      }
      usedIds.add(uniqueId)
      return uniqueId
    }

    headings.forEach((heading, index) => {
      // Skip if we already decorated this heading on a previous render.
      if (heading.dataset.skirAnchored === 'true') {
        if (heading.id) usedIds.add(heading.id)
        return
      }

      const text = heading.textContent || ''
      const baseId = heading.id || slugify(text) || `section-${index}`
      const uniqueId = ensureUniqueId(baseId)
      heading.id = uniqueId

      heading.classList.add('group')

      const anchor = document.createElement('a')
      anchor.href = `#${uniqueId}`
      anchor.className =
        'heading-anchor ml-2 inline-flex align-middle opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity'
      anchor.setAttribute('aria-label', 'Link to this section')
      anchor.setAttribute('data-skir-heading-anchor', 'true')

      // Inline SVG keeps textContent clean (used by OnThisPage).
      anchor.innerHTML =
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>'

      heading.appendChild(anchor)
      heading.dataset.skirAnchored = 'true'
    })

    // If the page loads with a hash, ensure we scroll once IDs exist.
    if (typeof window !== 'undefined' && window.location.hash.length > 1) {
      const id = window.location.hash.slice(1)
      const el = document.getElementById(id)
      if (el) el.scrollIntoView({ block: 'start' })
    }
  }, [children])

  return (
    <div
      ref={containerRef}
      className={cn(
        'max-w-none',
        // Headings
        '[&_h1]:scroll-mt-24 [&_h1]:text-3xl [&_h1]:font-bold [&_h1]:mb-6 [&_h1]:mt-8 [&_h1]:first:mt-0',
        '[&_h2]:scroll-mt-24 [&_h2]:text-2xl [&_h2]:font-semibold [&_h2]:mb-4 [&_h2]:mt-10 [&_h2]:pt-6 [&_h2]:border-t [&_h2]:border-border [&_h2]:first:border-0 [&_h2]:first:pt-0',
        '[&_h3]:scroll-mt-24 [&_h3]:text-xl [&_h3]:font-semibold [&_h3]:mb-3 [&_h3]:mt-8',
        '[&_h4]:scroll-mt-24 [&_h4]:text-lg [&_h4]:font-semibold [&_h4]:mb-2 [&_h4]:mt-6',
        // Paragraphs
        '[&_p]:text-muted-foreground [&_p]:leading-7 [&_p]:mb-4',
        // Lists
        '[&_ul]:list-disc [&_ul]:pl-6 [&_ul]:mb-4 [&_ul]:space-y-2 [&_ul]:text-muted-foreground',
        '[&_ol]:list-decimal [&_ol]:pl-6 [&_ol]:mb-4 [&_ol]:space-y-2 [&_ol]:text-muted-foreground',
        '[&_li]:leading-7',
        // Links
        '[&_a]:text-primary [&_a]:underline [&_a]:underline-offset-4 [&_a]:hover:text-primary/80',
        // Heading anchor links (override default link styles)
        '[&_.heading-anchor]:no-underline [&_.heading-anchor]:text-muted-foreground [&_.heading-anchor]:hover:text-foreground',
        // Strong / Bold
        '[&_strong]:text-foreground [&_strong]:font-semibold',
        className,
      )}
    >
      {children}
    </div>
  )
}

interface CodeBlockProps {
  children: string
  language?: string
  filename?: string
}

export function CodeBlock({ children, language, filename }: CodeBlockProps) {
  const [mounted, setMounted] = useState(false)
  const { theme } = useTheme()

  useEffect(() => {
    setMounted(true)
  }, [])

  // Use light theme during SSR for deterministic rendering before hydration.
  const syntaxTheme = !mounted || theme === 'light' ? atomOneLight : atomOneDark

  // Use Skir highlighting for Skir code
  const highlightLanguage = language === 'skir' ? 'skir' : language || 'plaintext'

  // Display name mapping for the language label
  const displayLanguage = language === 'skir' ? 'Skir' : language

  return (
    <div className="mb-4 rounded-lg border border-border overflow-hidden">
      {(filename || language) && (
        <div className="px-4 py-2 bg-secondary/50 border-b border-border text-sm text-muted-foreground flex items-center gap-2">
          {filename && <span className="font-medium">{filename}</span>}
          {displayLanguage && !filename && <span>{displayLanguage}</span>}
        </div>
      )}
      <SyntaxHighlighter
        language={highlightLanguage}
        style={syntaxTheme}
        customStyle={{
          margin: 0,
          borderRadius: 0,
          background: 'transparent',
        }}
        codeTagProps={{
          style: {
            fontSize: '0.875rem',
            fontFamily:
              'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace',
          },
        }}
      >
        {children}
      </SyntaxHighlighter>
    </div>
  )
}

interface NoteProps {
  children: ReactNode
  type?: 'info' | 'warning' | 'tip'
}

export function Note({ children, type = 'info' }: NoteProps) {
  const styles = {
    info: 'border-primary/50 bg-primary/5',
    warning: 'border-yellow-500/50 bg-yellow-500/5',
    tip: 'border-green-500/50 bg-green-500/5',
  }

  const labels = {
    info: 'Note',
    warning: 'Warning',
    tip: 'Tip',
  }

  return (
    <div className={cn('rounded-lg border-l-4 p-4 mb-4', styles[type])}>
      <p className="font-semibold text-foreground mb-1">{labels[type]}</p>
      <div className="text-sm text-muted-foreground [&_p]:mb-0">{children}</div>
    </div>
  )
}

// Heading components
export function H1({ children }: { children: ReactNode }) {
  return <h1 className="text-3xl font-bold mb-6 mt-8 first:mt-0">{children}</h1>
}

export function H2({ children }: { children: ReactNode }) {
  return (
    <h2 className="text-2xl font-semibold mb-4 mt-10 pt-6 border-t border-border first:border-0 first:pt-0">
      {children}
    </h2>
  )
}

export function H3({ children }: { children: ReactNode }) {
  return <h3 className="text-xl font-semibold mb-3 mt-8">{children}</h3>
}

export function H4({ children }: { children: ReactNode }) {
  return <h4 className="text-lg font-semibold mb-2 mt-6">{children}</h4>
}

// Text components
export function P({ children }: { children: ReactNode }) {
  return <p className="text-muted-foreground leading-7 mb-4">{children}</p>
}

export function InlineCode({ children }: { children: ReactNode }) {
  return <code className="font-mono text-sm bg-secondary px-1.5 py-0.5 rounded">{children}</code>
}

// List components
export function List({ children, ordered = false }: { children: ReactNode; ordered?: boolean }) {
  const Component = ordered ? 'ol' : 'ul'
  const listStyle = ordered ? 'list-decimal' : 'list-disc'
  return (
    <Component className={cn(listStyle, 'pl-6 mb-4 space-y-2 text-muted-foreground')}>
      {children}
    </Component>
  )
}

export function ListItem({ children }: { children: ReactNode }) {
  return <li className="leading-7">{children}</li>
}
