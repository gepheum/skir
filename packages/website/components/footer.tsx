import { Github as GitHubIcon } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'

const footerLinks = {
  documentation: [
    { name: 'Quickstart', href: '/docs/setup' },
    { name: 'Language Reference', href: '/docs/language-reference' },
    { name: 'Serialization', href: '/docs/serialization' },
    { name: 'Schema Evolution', href: '/docs/schema-evolution' },
  ],
  languages: [
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
  resources: [
    {
      name: 'Why I Built Skir (Blog)',
      href: 'https://medium.com/@gepheum/i-spent-15-years-with-protobuf-then-i-built-skir-9cf61cc65631',
      external: true,
    },
    { name: 'Converter App', href: 'converter', external: true },
    { name: 'GitHub', href: 'https://github.com/gepheum/skir', external: true },
    { name: 'Discord', href: 'https://discord.gg/FsKrGwJ9AP', external: true },
  ],
}

export function Footer() {
  return (
    <footer className="border-t border-border bg-card/40">
      <div className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="mb-4 flex items-center gap-3">
              <Image
                src="/octopus.svg"
                alt="Skir"
                width={36}
                height={36}
                className="rounded-full bg-primary/8 p-0.5"
              />
              <span className="text-xl font-bold">Skir</span>
            </Link>
            <p className="mb-4 text-sm text-muted-foreground">Types that travel.</p>
            <a
              href="https://github.com/gepheum/skir"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <GitHubIcon className="h-4 w-4" />
              <span>gepheum/skir</span>
            </a>
          </div>

          <div>
            <h3 className="mb-4 font-semibold">Documentation</h3>
            <ul className="space-y-2">
              {footerLinks.documentation.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3 className="mb-4 font-semibold">Languages</h3>
            <ul className="space-y-2">
              {footerLinks.languages.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3 className="mb-4 font-semibold">Resources</h3>
            <ul className="space-y-2">
              {footerLinks.resources.map((link) => (
                <li key={link.name}>
                  {'external' in link && link.external ? (
                    <a
                      href={link.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                    >
                      {link.name}
                    </a>
                  ) : (
                    <Link
                      href={link.href}
                      className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                    >
                      {link.name}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="mt-12 border-t border-border pt-8 text-center text-sm text-muted-foreground">
          <p>Released under the MIT License. Copyright 2024-present Gepheum.</p>
        </div>
      </div>
    </footer>
  )
}
