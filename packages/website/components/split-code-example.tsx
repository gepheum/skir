'use client'

import { skirLanguage } from '@/lib/skir-language'
import { cn } from '@/lib/utils'
import { useTheme } from 'next-themes'
import { useEffect, useRef, useState } from 'react'
import { Light as SyntaxHighlighter } from 'react-syntax-highlighter'
import cpp from 'react-syntax-highlighter/dist/esm/languages/hljs/cpp'
import csharp from 'react-syntax-highlighter/dist/esm/languages/hljs/csharp'
import dart from 'react-syntax-highlighter/dist/esm/languages/hljs/dart'
import elixir from 'react-syntax-highlighter/dist/esm/languages/hljs/elixir'
import go from 'react-syntax-highlighter/dist/esm/languages/hljs/go'
import java from 'react-syntax-highlighter/dist/esm/languages/hljs/java'
import kotlin from 'react-syntax-highlighter/dist/esm/languages/hljs/kotlin'
import python from 'react-syntax-highlighter/dist/esm/languages/hljs/python'
import rust from 'react-syntax-highlighter/dist/esm/languages/hljs/rust'
import swift from 'react-syntax-highlighter/dist/esm/languages/hljs/swift'
import typescript from 'react-syntax-highlighter/dist/esm/languages/hljs/typescript'
import { atomOneDark, atomOneLight } from 'react-syntax-highlighter/dist/esm/styles/hljs'

SyntaxHighlighter.registerLanguage('skir', skirLanguage)
SyntaxHighlighter.registerLanguage('typescript', typescript)
SyntaxHighlighter.registerLanguage('python', python)
SyntaxHighlighter.registerLanguage('csharp', csharp)
SyntaxHighlighter.registerLanguage('cpp', cpp)
SyntaxHighlighter.registerLanguage('go', go)
SyntaxHighlighter.registerLanguage('kotlin', kotlin)
SyntaxHighlighter.registerLanguage('java', java)
SyntaxHighlighter.registerLanguage('dart', dart)
SyntaxHighlighter.registerLanguage('elixir', elixir)
SyntaxHighlighter.registerLanguage('swift', swift)
SyntaxHighlighter.registerLanguage('rust', rust)

export type CodeTabId = string

type CodeTab = {
  id: CodeTabId
  label: string
  language?: string
}

type SplitCodeExampleProps = {
  skirCode: string
  codeExamples: Record<string, string>
  tabs?: CodeTab[]
  leftTitle?: string
  initialTab?: CodeTabId
  className?: string
}

const defaultTabs: CodeTab[] = [
  { id: 'typescript', label: 'TypeScript' },
  { id: 'python', label: 'Python' },
  { id: 'java', label: 'Java' },
  { id: 'csharp', label: 'C#', language: 'csharp' },
  { id: 'cpp', label: 'C++' },
  { id: 'go', label: 'Go' },
  { id: 'kotlin', label: 'Kotlin' },
  { id: 'swift', label: 'Swift' },
  { id: 'rust', label: 'Rust' },
  { id: 'dart', label: 'Dart' },
  { id: 'moonbit', label: 'MoonBit', language: 'plaintext' },
  { id: 'elixir', label: 'Elixir' },
]

export function SplitCodeExample({
  skirCode,
  codeExamples,
  tabs = defaultTabs,
  leftTitle = '.skir',
  initialTab = 'typescript',
  className,
}: SplitCodeExampleProps) {
  const fallbackTab = tabs[0]?.id ?? 'typescript'
  const [activeTab, setActiveTab] = useState<CodeTabId>(initialTab ?? fallbackTab)
  const activeTabConfig = tabs.find((tab) => tab.id === activeTab)
  const [mounted, setMounted] = useState(false)
  const tabsScrollRef = useRef<HTMLDivElement | null>(null)
  const { theme } = useTheme()

  useEffect(() => {
    setMounted(true)
  }, [])

  useEffect(() => {
    const tabsScrollEl = tabsScrollRef.current
    if (!tabsScrollEl) {
      return
    }

    // Start with the tabs scrolled all the way to the right.
    const scrollToMaxRight = () => {
      tabsScrollEl.scrollLeft = tabsScrollEl.scrollWidth
    }

    scrollToMaxRight()
    requestAnimationFrame(scrollToMaxRight)
  }, [tabs.length])

  // Use light theme during SSR for deterministic rendering before hydration.
  const resolvedTheme = !mounted || theme === 'light' ? 'light' : 'dark'
  const syntaxTheme = resolvedTheme === 'light' ? atomOneLight : atomOneDark

  return (
    <div
      className={cn(
        'split-code-example rounded-lg border border-border overflow-hidden bg-card',
        className,
      )}
    >
      <div className="flex h-[540px]">
        <div className="split-code-example__schema-pane w-[45%] border-r border-border flex flex-col">
          <div className="split-code-example__schema-title px-4 py-3 text-sm font-medium border-b border-border bg-secondary/30 text-primary">
            {leftTitle}
          </div>
          <div className="split-code-example__schema-code overflow-x-auto overflow-y-auto flex-1">
            <SyntaxHighlighter
              language="skir"
              style={syntaxTheme}
              customStyle={{
                margin: 0,
                borderRadius: 0,
                background: 'transparent',
                height: '100%',
                boxSizing: 'border-box',
                padding: '1rem',
              }}
              codeTagProps={{
                style: {
                  fontSize: '0.875rem',
                  fontFamily:
                    'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace',
                },
              }}
            >
              {skirCode}
            </SyntaxHighlighter>
          </div>
        </div>

        <div className="split-code-example__target-pane w-[55%] flex flex-col">
          <div className="split-code-example__tabs-row relative border-b border-border bg-secondary/30">
            <div ref={tabsScrollRef} className="overflow-x-auto thin-scrollbar">
              <div className="flex min-w-max">
                {tabs.map((tab) => (
                  <button
                    type="button"
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    data-active={activeTab === tab.id}
                    className={cn(
                      'split-code-example__tab shrink-0 cursor-pointer whitespace-nowrap px-4 py-3 text-sm font-medium transition-colors',
                      activeTab === tab.id
                        ? 'text-primary bg-card'
                        : 'text-muted-foreground hover:text-foreground',
                    )}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>
            </div>
            <div className="split-code-example__tabs-fade-left pointer-events-none absolute inset-y-0 left-0 w-6 bg-gradient-to-r from-secondary/80 to-transparent" />
            <div className="split-code-example__tabs-fade-right pointer-events-none absolute inset-y-0 right-0 w-6 bg-gradient-to-l from-secondary/80 to-transparent" />
          </div>

          <div
            key={activeTab}
            className="split-code-example__target-code overflow-x-auto overflow-y-auto flex-1"
          >
            <SyntaxHighlighter
              language={activeTabConfig?.language ?? activeTab}
              style={syntaxTheme}
              customStyle={{
                margin: 0,
                borderRadius: 0,
                background: 'transparent',
                height: '100%',
                boxSizing: 'border-box',
                padding: '1rem',
              }}
              codeTagProps={{
                style: {
                  fontSize: '0.875rem',
                  fontFamily:
                    'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace',
                },
              }}
            >
              {codeExamples[activeTab]}
            </SyntaxHighlighter>
          </div>
        </div>
      </div>
    </div>
  )
}
