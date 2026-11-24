'use client'

import { Button } from '@/components/ui/button'
import { Copy } from 'lucide-react'
import { useEffect, useState } from 'react'

const COMMAND = 'npx skir init'

export function CopyCommandButton() {
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!copied) return

    const timeoutId = window.setTimeout(() => setCopied(false), 1800)
    return () => window.clearTimeout(timeoutId)
  }, [copied])

  const copyCommand = async () => {
    try {
      await navigator.clipboard.writeText(COMMAND)
      setCopied(true)
    } catch {
      const textarea = document.createElement('textarea')
      textarea.value = COMMAND
      textarea.setAttribute('readonly', '')
      textarea.style.position = 'absolute'
      textarea.style.left = '-9999px'
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand('copy')
      document.body.removeChild(textarea)
      setCopied(true)
    }
  }

  return (
    <div className="group relative inline-flex">
      <span
        aria-live="polite"
        className={`pointer-events-none absolute -top-7 left-1/2 -translate-x-1/2 rounded-md border border-border/80 bg-background px-2 py-0.5 text-xs font-medium lowercase text-muted-foreground shadow-sm transition-all duration-150 ${
          copied
            ? 'translate-y-0 opacity-100'
            : '-translate-y-1 opacity-0 group-hover:translate-y-0 group-hover:opacity-100'
        }`}
      >
        {copied ? 'Copied!' : 'copy'}
      </span>

      <Button
        variant="outline"
        size="lg"
        className="cursor-pointer rounded-full bg-transparent font-mono text-base"
        onClick={copyCommand}
        aria-label="Copy npx skir init command"
      >
        <span className="mr-2 text-muted-foreground/45">$</span>
        <span>{COMMAND}</span>
        <Copy className="ml-3 h-4 w-4 text-muted-foreground/70" />
      </Button>
    </div>
  )
}
