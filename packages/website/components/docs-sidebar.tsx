'use client'

import { cn } from '@/lib/utils'
import { ChevronDown, ChevronRight } from 'lucide-react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useEffect, useState } from 'react'

const navigation = [
  {
    title: 'Quickstart',
    items: [
      { title: 'Setup & workflow', href: '/docs/setup' },
      { title: 'Project examples', href: '/docs/examples' },
    ],
  },
  {
    title: 'Core concepts',
    items: [
      { title: 'Language reference', href: '/docs/language-reference' },
      { title: 'Serialization', href: '/docs/serialization' },
      { title: 'Schema evolution', href: '/docs/schema-evolution' },
      { title: 'SkirRPC', href: '/docs/skirrpc' },
      { title: 'GitHub imports', href: '/docs/github-imports' },
      { title: 'Best practices', href: '/docs/best-practices' },
    ],
  },
  {
    title: 'Extensibility',
    items: [{ title: 'Building a generator', href: '/docs/code-generators' }],
  },
  {
    title: 'Comparison',
    items: [{ title: 'Skir vs Protobuf', href: '/docs/protobuf' }],
  },
  {
    title: 'Generated code',
    items: [
      { title: 'C++', href: '/docs/cpp' },
      { title: 'C#', href: '/docs/csharp' },
      { title: 'Dart', href: '/docs/dart' },
      { title: 'Elixir', href: '/docs/elixir' },
      { title: 'Gleam', href: '/docs/gleam' },
      { title: 'Go', href: '/docs/go' },
      { title: 'Java', href: '/docs/java' },
      { title: 'Kotlin', href: '/docs/kotlin' },
      { title: 'MoonBit', href: '/docs/moonbit' },
      { title: 'Python', href: '/docs/python' },
      { title: 'Rust', href: '/docs/rust' },
      { title: 'Swift', href: '/docs/swift' },
      { title: 'TypeScript', href: '/docs/typescript' },
      { title: 'Zig', href: '/docs/zig' },
    ],
  },
]

export function DocsSidebar() {
  const pathname = usePathname()
  const [openSections, setOpenSections] = useState<string[]>(() =>
    navigation.map((section) => section.title),
  )

  const toggleSection = (title: string) => {
    setOpenSections((prev) =>
      prev.includes(title) ? prev.filter((t) => t !== title) : [...prev, title],
    )
  }

  useEffect(() => {
    const activeSection = navigation.find((section) =>
      section.items.some((item) => item.href === pathname),
    )

    if (!activeSection) {
      return
    }

    setOpenSections((prev) =>
      prev.includes(activeSection.title) ? prev : [...prev, activeSection.title],
    )
  }, [pathname])

  return (
    <aside className="hidden md:block w-64 shrink-0">
      <div className="sticky top-24 max-h-[calc(100vh-8rem)] overflow-y-auto pr-2">
        <nav className="space-y-6">
          {navigation.map((section) => (
            <div key={section.title}>
              <button
                type="button"
                onClick={() => toggleSection(section.title)}
                className="mb-2 flex w-full items-center justify-between text-sm font-semibold text-foreground transition-colors hover:text-primary"
              >
                {section.title}
                {openSections.includes(section.title) ? (
                  <ChevronDown className="h-4 w-4" />
                ) : (
                  <ChevronRight className="h-4 w-4" />
                )}
              </button>
              {openSections.includes(section.title) && (
                <ul className="ml-2 space-y-1 border-l border-border pl-4">
                  {section.items.map((item) => (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        className={cn(
                          'block py-1 text-sm transition-colors',
                          pathname === item.href
                            ? 'text-primary font-medium'
                            : 'text-muted-foreground hover:text-foreground',
                        )}
                      >
                        {item.title}
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </nav>
      </div>
    </aside>
  )
}
