import { DocsSidebar } from '@/components/docs-sidebar'
import { Header } from '@/components/header'
import { OnThisPage } from '@/components/on-this-page'
import React from 'react'

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4">
        <div className="flex gap-8 py-8">
          <DocsSidebar />
          <main className="flex-1 min-w-0">{children}</main>
          <OnThisPage />
        </div>
      </div>
    </div>
  )
}
