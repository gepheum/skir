import {
  ArrowRight,
  BookOpen,
  Globe,
  Layers,
  LayoutGrid,
  Package,
  PenTool,
  RefreshCw,
  Wrench,
  Zap,
} from 'lucide-react'
import Link from 'next/link'

export const metadata = {
  title: 'Documentation - Skir Documentation',
  description: 'Practical rules for writing future-proof schemas and robust APIs.',
}

const sections = [
  {
    title: 'Quickstart',
    description: 'Set up Skir in your project and learn the basic workflow.',
    href: '/docs/setup',
    icon: BookOpen,
  },
  {
    title: 'Project Examples',
    description: 'Explore real-world repositories and starter projects across languages.',
    href: '/docs/examples',
    icon: LayoutGrid,
  },
  {
    title: 'Language Reference',
    description: 'Complete guide to the Skir schema language syntax and features.',
    href: '/docs/language-reference',
    icon: Zap,
  },
  {
    title: 'Serialization',
    description: 'Learn about JSON and binary serialization formats.',
    href: '/docs/serialization',
    icon: Layers,
  },
  {
    title: 'Schema Evolution',
    description: 'Guidelines for evolving your schema without breaking compatibility.',
    href: '/docs/schema-evolution',
    icon: RefreshCw,
  },
  {
    title: 'SkirRPC',
    description: 'Build typesafe APIs with SkirRPC services.',
    href: '/docs/skirrpc',
    icon: Globe,
  },
  {
    title: 'GitHub imports',
    description: 'Import types from other GitHub repositories.',
    href: '/docs/github-imports',
    icon: Package,
  },
  {
    title: 'Best Practices',
    description: 'Practical rules for writing future-proof schemas and robust APIs.',
    href: '/docs/best-practices',
    icon: PenTool,
  },
  {
    title: 'Building Code Generators',
    description: 'Implement custom generators and understand the compiler input/output contract.',
    href: '/docs/code-generators',
    icon: Wrench,
  },
  {
    title: 'Protobuf vs Skir',
    description: 'Compare design choices and trade-offs between Protobuf and Skir.',
    href: '/docs/protobuf',
    icon: Globe,
  },
]

export default function DocsPage() {
  return (
    <div className="max-w-4xl">
      <div className="mb-12">
        <h1 className="mb-4 text-4xl font-bold">Documentation</h1>
        <p className="text-lg text-muted-foreground">
          Skir is a declarative language for representing data types and APIs. Define your schema
          once in a <code className="text-primary font-mono">.skir</code> file and generate
          idiomatic, type-safe code for TypeScript, Python, Java, C#, C++, Kotlin, Dart, Swift, Go,
          Rust, Zig, Gleam, MoonBit, and Elixir.
        </p>
      </div>

      <div className="grid sm:grid-cols-2 gap-4 mb-12">
        {sections.map((section) => {
          const Icon = section.icon
          return (
            <Link
              key={section.href}
              href={section.href}
              className="soft-surface group rounded-xl p-6 transition-colors hover:border-primary/40"
            >
              <div className="mb-3 flex items-center gap-3">
                <div className="rounded-lg bg-primary/10 p-2 text-primary">
                  <Icon className="h-5 w-5" />
                </div>
                <h2 className="font-semibold">{section.title}</h2>
              </div>
              <p className="text-sm text-muted-foreground mb-3">{section.description}</p>
              <span className="text-sm text-primary flex items-center gap-1 group-hover:gap-2 transition-all">
                Learn more
                <ArrowRight className="h-4 w-4" />
              </span>
            </Link>
          )
        })}
      </div>

      <div className="soft-surface rounded-xl p-6">
        <h2 className="mb-2 font-semibold">Supported Languages</h2>
        <p className="mb-4 text-sm text-muted-foreground">
          Skir generates idiomatic code for all major programming languages.
        </p>
        <div className="flex flex-wrap gap-2">
          {[
            { name: 'TypeScript', href: '/docs/typescript' },
            { name: 'Python', href: '/docs/python' },
            { name: 'C++', href: '/docs/cpp' },
            { name: 'Go', href: '/docs/go' },
            { name: 'Java', href: '/docs/java' },
            { name: 'C#', href: '/docs/csharp' },
            { name: 'Kotlin', href: '/docs/kotlin' },
            { name: 'Dart', href: '/docs/dart' },
            { name: 'Swift', href: '/docs/swift' },
            { name: 'Rust', href: '/docs/rust' },
            { name: 'Zig', href: '/docs/zig' },
            { name: 'Gleam', href: '/docs/gleam' },
            { name: 'MoonBit', href: '/docs/moonbit' },
            { name: 'Elixir', href: '/docs/elixir' },
          ].map((lang) => (
            <Link
              key={lang.name}
              href={lang.href}
              className="px-3 py-1 text-sm rounded-full border border-border hover:border-primary/50 hover:text-primary transition-colors"
            >
              {lang.name}
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
