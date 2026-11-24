'use client'

import { cn } from '@/lib/utils'
import { usePathname } from 'next/navigation'
import { useEffect, useState } from 'react'

interface Section {
  id: string
  title: string
  level: number
}

export function OnThisPage() {
  const pathname = usePathname()
  const [sections, setSections] = useState<Section[]>([])
  const [activeId, setActiveId] = useState<string>('')

  useEffect(() => {
    // Reset sections when route changes, then scan for new headings
    setSections([])

    // Small timeout to allow content to render
    const timer = setTimeout(() => {
      const mainElement = document.querySelector('main')
      if (!mainElement) return

      const headings = mainElement.querySelectorAll('h2, h3, h4')
      const sectionsData: Section[] = []
      const usedIds = new Set<string>()

      headings.forEach((heading, index) => {
        let id = heading.id
        if (!id) {
          // Create slug from text content
          id = (heading.textContent || '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/(^-|-$)/g, '')

          if (!id) id = `section-${index}`
        }

        // Ensure unique ID
        let uniqueId = id
        let count = 1
        while (usedIds.has(uniqueId)) {
          uniqueId = `${id}-${count}`
          count++
        }
        usedIds.add(uniqueId)
        heading.id = uniqueId

        sectionsData.push({
          id: uniqueId,
          title: heading.textContent || '',
          level: parseInt(heading.tagName[1]),
        })
      })

      setSections(sectionsData)
    }, 100)

    return () => clearTimeout(timer)
  }, [pathname])

  useEffect(() => {
    if (sections.length === 0) return

    const visibleIds = new Set<string>()

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            visibleIds.add(entry.target.id)
          } else {
            visibleIds.delete(entry.target.id)
          }
        })

        // Find the first section that is currently visible
        const firstVisible = sections.find((section) => visibleIds.has(section.id))
        if (firstVisible) {
          setActiveId(firstVisible.id)
        }
      },
      { rootMargin: '-20% 0px -35% 0px' },
    )

    const headings = document.querySelectorAll('main h2, main h3, main h4')
    headings.forEach((heading) => observer.observe(heading))

    return () => observer.disconnect()
  }, [sections])

  if (sections.length === 0 || pathname === '/docs' || pathname === '/docs/examples') {
    return null
  }

  return (
    <aside className="hidden xl:block w-64 shrink-0">
      <div className="sticky top-24 pl-4 text-sm">
        <ul className="space-y-2">
          {sections.map((section) => (
            <li key={section.id}>
              <a
                href={`#${section.id}`}
                className={cn(
                  'block font-medium transition-colors hover:text-foreground',
                  activeId === section.id ? 'text-primary' : 'text-muted-foreground',
                  section.level === 3 && 'pl-4',
                  section.level === 4 && 'pl-8',
                )}
                onClick={(e) => {
                  e.preventDefault()
                  document.getElementById(section.id)?.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start',
                  })
                  setActiveId(section.id)
                  // Update URL hash without jumping
                  history.pushState(null, '', `#${section.id}`)
                }}
              >
                {section.title}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </aside>
  )
}
