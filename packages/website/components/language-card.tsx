import type { ReactNode } from 'react'

import { cn } from '@/lib/utils'
import { ArrowRight } from 'lucide-react'
import Link from 'next/link'

interface LanguageCardProps {
  name: string
  icon: ReactNode
  href: string
  className?: string
}

export function LanguageCard({ name, icon, href, className }: LanguageCardProps) {
  return (
    <Link
      href={href}
      className={cn(
        'soft-surface group flex cursor-pointer items-center justify-between rounded-xl p-4 transition-colors hover:border-primary/40 hover:bg-card/80',
        className,
      )}
    >
      <div className="flex items-center gap-3">
        <div
          className="flex h-10 w-10 items-center justify-center rounded-lg bg-background/70 text-foreground [&_svg]:h-6 [&_svg]:w-6"
          aria-hidden="true"
        >
          {icon}
        </div>
        <span className="font-medium">{name}</span>
      </div>
      <ArrowRight className="h-4 w-4 text-muted-foreground transition-colors group-hover:text-primary" />
    </Link>
  )
}
