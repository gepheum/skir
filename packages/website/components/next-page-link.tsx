'use client'

import { ArrowRight } from 'lucide-react'
import Link from 'next/link'

interface NextPageLinkProps {
  title: string
  href: string
}

export function NextPageLink({ title, href }: NextPageLinkProps) {
  return (
    <div className="mt-12 pt-8 border-t border-border flex justify-end">
      <Link href={href} className="group inline-flex flex-col items-end text-right">
        <span className="text-sm text-muted-foreground mb-1">Next</span>
        <span className="font-medium text-primary flex items-center gap-2">
          {title}
          <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
        </span>
      </Link>
    </div>
  )
}
