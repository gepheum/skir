'use client'

import { ThemeToggle } from '@/components/theme-toggle'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { ChevronDown, Github, Menu, X } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { useState } from 'react'

type NavigationItem = {
  name: string
  href?: string
  external?: boolean
  items?: { name: string; href: string }[]
}

const navigation: NavigationItem[] = [
  { name: 'Docs', href: '/docs' },
  { name: 'Quickstart', href: '/docs/setup' },
  { name: 'Language reference', href: '/docs/language-reference' },
  {
    name: 'Generated code',
    items: [
      { name: 'C++', href: '/docs/cpp' },
      { name: 'C#', href: '/docs/csharp' },
      { name: 'Dart', href: '/docs/dart' },
      { name: 'Elixir', href: '/docs/elixir' },
      { name: 'Gleam', href: '/docs/gleam' },
      { name: 'Go', href: '/docs/go' },
      { name: 'Java', href: '/docs/java' },
      { name: 'Kotlin', href: '/docs/kotlin' },
      { name: 'MoonBit', href: '/docs/moonbit' },
      { name: 'Python', href: '/docs/python' },
      { name: 'Rust', href: '/docs/rust' },
      { name: 'Swift', href: '/docs/swift' },
      { name: 'TypeScript', href: '/docs/typescript' },
      { name: 'Zig', href: '/docs/zig' },
    ],
  },
]

function DiscordIcon() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      aria-hidden="true"
      className="h-5 w-5"
      fill="currentColor"
    >
      <path d="M13.545 2.907a13.2 13.2 0 0 0-3.257-1.011.05.05 0 0 0-.052.025c-.141.25-.297.577-.406.833a12.2 12.2 0 0 0-3.658 0 8 8 0 0 0-.412-.833.05.05 0 0 0-.052-.025c-1.125.194-2.22.534-3.257 1.011a.04.04 0 0 0-.021.018C.356 6.024-.213 9.047.066 12.032q.003.022.021.037a13.3 13.3 0 0 0 3.995 2.02.05.05 0 0 0 .056-.019q.463-.63.818-1.329a.05.05 0 0 0-.01-.059l-.018-.011a9 9 0 0 1-1.248-.595.05.05 0 0 1-.02-.066l.015-.019q.127-.095.248-.195a.05.05 0 0 1 .051-.007c2.619 1.196 5.454 1.196 8.041 0a.05.05 0 0 1 .053.007q.121.1.248.195a.05.05 0 0 1-.004.085 8 8 0 0 1-1.249.594.05.05 0 0 0-.03.03.05.05 0 0 0 .003.041c.24.465.515.909.817 1.329a.05.05 0 0 0 .056.019 13.2 13.2 0 0 0 4.001-2.02.05.05 0 0 0 .021-.037c.334-3.451-.559-6.449-2.366-9.106a.03.03 0 0 0-.02-.019m-8.198 7.307c-.789 0-1.438-.724-1.438-1.612s.637-1.613 1.438-1.613c.807 0 1.45.73 1.438 1.613 0 .888-.637 1.612-1.438 1.612m5.316 0c-.788 0-1.438-.724-1.438-1.612s.637-1.613 1.438-1.613c.807 0 1.451.73 1.438 1.613 0 .888-.631 1.612-1.438 1.612" />
    </svg>
  )
}

function ConverterInvaderIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="h-6 w-6">
      <path
        d="M6 9V6h2V4h8v2h2v3h2v8h-2v3h-2v-2h-2v2h-4v-2H8v2H6v-3H4V9h2z"
        fill="white"
        stroke="black"
        strokeWidth="1.75"
        strokeLinejoin="round"
      />
      <circle cx="9.5" cy="11.5" r="1.2" fill="black" />
      <circle cx="14.5" cy="11.5" r="1.2" fill="black" />
    </svg>
  )
}

export function Header() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/80 bg-background/90 backdrop-blur supports-[backdrop-filter]:bg-background/70">
      <nav className="container mx-auto flex h-16 items-center justify-between gap-4 px-4">
        <div className="flex items-center gap-8">
          <Link href="/" className="flex items-center gap-2.5">
            <Image
              src="/octopus.svg"
              alt="Skir"
              width={32}
              height={32}
              className="rounded-full bg-primary/8 p-0.5"
            />
            <span className="text-xl font-bold">Skir</span>
          </Link>

          <div className="hidden md:flex items-center gap-6">
            {navigation.map((item) =>
              item.items ? (
                <DropdownMenu key={item.name}>
                  <DropdownMenuTrigger className="flex cursor-pointer items-center text-base font-medium text-muted-foreground transition-colors hover:text-foreground focus:outline-none">
                    {item.name}
                    <ChevronDown className="ml-1 h-4 w-4" />
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="start">
                    {item.items.map((subItem) => (
                      <Link key={subItem.name} href={subItem.href}>
                        <DropdownMenuItem className="cursor-pointer text-base font-medium text-muted-foreground transition-colors data-[highlighted]:bg-primary/16 data-[highlighted]:text-foreground">
                          {subItem.name}
                        </DropdownMenuItem>
                      </Link>
                    ))}
                  </DropdownMenuContent>
                </DropdownMenu>
              ) : item.external ? (
                <a
                  key={item.name}
                  href={item.href!}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-base font-medium text-muted-foreground transition-colors hover:text-foreground"
                >
                  {item.name}
                </a>
              ) : (
                <Link
                  key={item.name}
                  href={item.href!}
                  className="text-base font-medium text-muted-foreground transition-colors hover:text-foreground"
                >
                  {item.name}
                </Link>
              ),
            )}
          </div>
        </div>

        <div className="flex items-center gap-4">
          <a
            href="/llms.txt"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden md:inline-flex items-center text-[10px] font-mono text-muted-foreground hover:text-foreground transition-colors border border-border rounded px-1 py-0.5"
          >
            llms.txt
          </a>
          <Button
            asChild
            variant="ghost"
            size="icon"
            className="hidden md:flex h-10 w-10 rounded-full"
          >
            <a
              href="/converter.html"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Converter"
              className="inline-flex items-center justify-center leading-none"
            >
              <ConverterInvaderIcon />
            </a>
          </Button>
          <Button asChild variant="ghost" size="icon" className="hidden md:flex rounded-full">
            <a href="https://discord.gg/FsKrGwJ9AP" target="_blank" rel="noopener noreferrer">
              <DiscordIcon />
              <span className="sr-only">Discord</span>
            </a>
          </Button>
          <Button asChild variant="ghost" size="icon" className="hidden md:flex rounded-full">
            <a href="https://github.com/gepheum/skir" target="_blank" rel="noopener noreferrer">
              <Github className="h-5 w-5" />
              <span className="sr-only">GitHub</span>
            </a>
          </Button>
          <ThemeToggle />

          <Button
            variant="ghost"
            size="icon"
            className="rounded-full md:hidden"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          >
            {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </Button>
        </div>
      </nav>

      {/* Mobile menu */}
      {mobileMenuOpen && (
        <div className="border-t border-border bg-background/95 md:hidden">
          <div className="container mx-auto space-y-4 px-4 py-4">
            {navigation.map((item) =>
              item.items ? (
                <div key={item.name} className="space-y-3">
                  <div className="text-base font-medium text-foreground">{item.name}</div>
                  <div className="ml-1 space-y-3 border-l border-border pl-4">
                    {item.items.map((subItem) => (
                      <Link
                        key={subItem.name}
                        href={subItem.href}
                        className="block text-base text-muted-foreground transition-colors hover:text-foreground"
                        onClick={() => setMobileMenuOpen(false)}
                      >
                        {subItem.name}
                      </Link>
                    ))}
                  </div>
                </div>
              ) : item.external ? (
                <a
                  key={item.name}
                  href={item.href!}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block text-base text-muted-foreground transition-colors hover:text-foreground"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  {item.name}
                </a>
              ) : (
                <Link
                  key={item.name}
                  href={item.href!}
                  className="block text-base text-muted-foreground transition-colors hover:text-foreground"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  {item.name}
                </Link>
              ),
            )}
            <div className="flex items-center gap-4 border-t border-border pt-4">
              <Button asChild variant="outline" size="sm" className="h-10 w-10 rounded-full p-0">
                <a
                  href="converter"
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label="Converter"
                  className="inline-flex items-center justify-center leading-none"
                >
                  <ConverterInvaderIcon />
                </a>
              </Button>
              <ThemeToggle />
              <Button asChild variant="outline" size="sm">
                <a href="https://github.com/gepheum/skir" target="_blank" rel="noopener noreferrer">
                  <Github className="mr-2 h-4 w-4" />
                  GitHub
                </a>
              </Button>
            </div>
          </div>
        </div>
      )}
    </header>
  )
}
