import { CodeExample } from '@/components/code-example'
import { CopyCommandButton } from '@/components/copy-command-button'
import { FeatureCard } from '@/components/feature-card'
import { Footer } from '@/components/footer'
import { Header } from '@/components/header'
import { HoverVideo } from '@/components/hover-video'
import { LanguageCard } from '@/components/language-card'
import { Button } from '@/components/ui/button'
import { ArrowRight, Moon, Package, Terminal, Zap } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { FaJava } from 'react-icons/fa6'
import {
  SiCplusplus,
  SiDart,
  SiElixir,
  SiGleam,
  SiGo,
  SiKotlin,
  SiPython,
  SiRust,
  SiSharp,
  SiSwift,
  SiTypescript,
  SiZig,
} from 'react-icons/si'

function WaveDivider({ colorClass, flip = false }: { colorClass: string; flip?: boolean }) {
  return (
    <div
      aria-hidden="true"
      className={`pointer-events-none absolute inset-x-0 ${flip ? 'top-0 -translate-y-px rotate-180' : 'bottom-0 translate-y-px'} ${colorClass}`}
    >
      <svg viewBox="0 0 1440 120" preserveAspectRatio="none" className="h-16 w-full md:h-24">
        <path
          fill="currentColor"
          d="M0,96L48,90.7C96,85,192,75,288,58.7C384,43,480,21,576,16C672,11,768,21,864,37.3C960,53,1056,75,1152,85.3C1248,96,1344,96,1392,96L1440,96L1440,121L1392,121C1344,121,1248,121,1152,121C1056,121,960,121,864,121C768,121,672,121,576,121C480,121,384,121,288,121C192,121,96,121,48,121L0,121Z"
        />
      </svg>
    </div>
  )
}

export default function HomePage() {
  return (
    <div className="min-h-screen bg-background">
      <Header />

      {/* Hero Section */}
      <section className="relative overflow-hidden px-4 pb-22 pt-20 md:px-5 md:pb-28 md:pt-26">
        <div className="absolute inset-0 -z-10">
          <div className="absolute left-1/2 top-0 h-[620px] w-[840px] -translate-x-1/2 rounded-full bg-primary/12 blur-[120px]" />
          <div className="absolute left-8 top-28 h-40 w-40 rounded-full bg-accent/35 blur-3xl" />
          <div className="friendly-grid absolute inset-x-0 top-0 h-[480px] opacity-40" />
        </div>

        <div className="container mx-auto">
          <div className="max-w-4xl mx-auto text-center">
            <a
              href="https://github.com/gepheum/skir"
              target="_blank"
              rel="noopener noreferrer"
              className="soft-surface mb-8 inline-flex items-center gap-2 rounded-full px-4 py-2 transition-colors hover:text-foreground"
            >
              <span className="text-primary font-medium">v1.2</span>
              <span className="text-muted-foreground">Types that travel.</span>
            </a>

            <h1 className="mb-6 text-balance text-3xl font-bold tracking-tight md:text-5xl lg:text-6xl">
              The single <span className="text-teal-500 dark:text-teal-400">source of truth</span>
              <br /> for your data types
            </h1>

            <p className="mx-auto mb-10 max-w-2xl text-pretty text-lg text-muted-foreground md:text-xl">
              Skir is a modern declarative schema language for data models and APIs.
              <br />
              Write once in a <code className="text-primary font-mono">.skir</code> file - instantly
              generate clean, idiomatic, and fully type-safe code in TypeScript, Python, Java, Go,
              C++, and more languages.
            </p>

            <div className="mb-12 flex flex-col justify-center gap-4 sm:flex-row">
              <Button asChild size="lg" className="rounded-full px-6 text-base">
                <Link href="/docs/setup">
                  Get Started
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
              <CopyCommandButton />
            </div>

            {/* Quick Example Video */}
            <div className="mx-auto max-w-[1000px]">
              <HoverVideo src="/greet.mp4" className="max-w-[900px]" />
            </div>
          </div>
        </div>
      </section>

      {/* Code Example Section */}
      <section className="relative overflow-hidden border-t border-border px-4 py-14 md:px-5 md:py-20">
        <div className="container mx-auto">
          <div className="max-w-5xl mx-auto">
            <div className="text-center mb-12">
              <h2 className="mb-4 text-balance text-3xl font-bold md:text-4xl">
                One schema, 10+ languages, zero headaches
              </h2>
              <p className="mx-auto max-w-2xl text-lg text-muted-foreground">
                One YAML file. One command.
                <br />
                No manual reruns: watch mode refreshes generated code on every change.
                <br />
                Zero-install compiler (<code>npx</code>), easy to integrate into any workflow.
              </p>
            </div>

            <CodeExample />
          </div>
        </div>
      </section>

      <section className="border-t border-border py-14 md:py-20">
        <div className="container mx-auto px-4">
          <div className="mx-auto max-w-3xl text-center">
            <h2 className="text-balance text-2xl font-bold md:text-3xl">
              LLMs make 10x fewer mistakes with strong types
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-lg text-muted-foreground">
              Skir gives your AI coding tools the type information they crave.
              <br />A 2025
              <a
                href="https://arxiv.org/pdf/2504.09246?"
                target="_blank"
                rel="noopener noreferrer"
                className="ml-1 underline decoration-muted-foreground/50 transition-colors hover:text-foreground"
              >
                study
              </a>{' '}
              reports that nearly 94% of common LLM coding errors are type-related, which helps
              explain why strong typing can drastically reduce mistakes.
              <br />
              Don&apos;t believe it?
              <a
                href="https://gemini.google.com/share/ea387c7e27e9"
                target="_blank"
                rel="noopener noreferrer"
                className="ml-1 underline decoration-muted-foreground/50 transition-colors hover:text-foreground"
              >
                Ask AI
              </a>
              .
            </p>
          </div>
        </div>
      </section>

      {/* Schema Evolution Section */}
      <section className="border-t border-border py-14 md:py-20">
        <div className="container mx-auto">
          <div className="max-w-5xl mx-auto text-center">
            <h2 className="mb-4 text-balance text-3xl font-bold md:text-4xl">
              Serialize now, deserialize in 100 years
            </h2>
            <p className="mx-auto mb-12 max-w-2xl text-lg text-muted-foreground">
              Modifying schemas in a long-lived or distributed system is risky—one wrong move can
              break clients or make it impossible to deserialize old data.
              <br />
              Skir has simple guidelines and built-in checks to evolve your schema safely.
            </p>

            <div className="mx-auto flex max-w-[980px] items-center justify-center gap-2 md:gap-3">
              <div className="soft-surface w-[48%] overflow-hidden rounded-xl p-2">
                <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Before
                </div>
                <Image
                  src="/shapes-before.png"
                  alt="Schema before evolution changes"
                  width={0}
                  height={0}
                  sizes="(max-width: 768px) 48vw, 500px"
                  className="h-auto w-full rounded-lg"
                />
              </div>
              <div className="soft-surface w-[48%] overflow-hidden rounded-xl p-2">
                <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  After
                </div>
                <Image
                  src="/shapes-after.png"
                  alt="Schema after evolution changes"
                  width={0}
                  height={0}
                  sizes="(max-width: 768px) 48vw, 500px"
                  className="h-auto w-full rounded-lg"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* RPC Example Section */}
      <section className="border-t border-border bg-card/30 py-14 md:py-20">
        <div className="container mx-auto">
          <div className="mb-12 max-w-6xl mx-auto text-center">
            <h2 className="mb-4 text-balance text-3xl font-bold md:text-4xl">
              End-to-end typesafety with SkirRPC
            </h2>
            <p className="mx-auto mb-6 max-w-2xl text-lg text-muted-foreground">
              SkirRPC is a lightweight HTTP protocol for typesafe cross-service or frontend↔backend
              communication. It integrates with your existing web framework. Your client and server
              use the same generated method definitions, so contract mismatches are caught before
              runtime.
            </p>
          </div>
          <div className="max-w-5xl mx-auto">
            <HoverVideo src="/rpc-studio.mp4" className="max-w-[900px]" />
            <p className="mt-4 text-center text-sm text-muted-foreground">
              Every SkirRPC service ships with a built-in Studio app for browsing and testing its
              methods.
            </p>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="border-t border-border py-14 md:py-20">
        <div className="container mx-auto">
          <div className="mb-12 text-center">
            <h2 className="mb-4 text-3xl font-bold md:text-4xl">More features</h2>
          </div>

          <div className="mx-auto grid max-w-6xl gap-6 md:grid-cols-3">
            <FeatureCard
              icon={<Zap className="h-6 w-6" />}
              title="Serialization to JSON or binary"
              description="Choose between dense JSON for web APIs and databases, readable JSON for debugging, or binary for raw performance."
            />
            <FeatureCard
              icon={<Package className="h-6 w-6" />}
              title="GitHub imports"
              description="Don't copy files. Import types directly from any GitHub repository. Share common data structures across projects."
            />
            <FeatureCard
              icon={<SiRust className="h-6 w-6" />}
              title="Polymorphism done right"
              description={
                <>
                  Model polymorphism clearly with sum types. Skir lets you attach typed data
                  payloads to individual <code>enum</code> variants.
                </>
              }
            />
            <FeatureCard
              icon={<Package className="h-6 w-6" />}
              title="Prioritizes immutability"
              description="Skir generates deeply immutable types with all fields required at construction time in target languages where that is idiomatic."
            />
            <FeatureCard
              icon={<Package className="h-6 w-6" />}
              title="Constants you can share"
              description={
                <>
                  Define constants in your <code>.skir</code> files. They ship in generated code, so
                  services share the same values without runtime config reads.
                </>
              }
            />
            <FeatureCard
              icon={<Zap className="h-6 w-6" />}
              title="Serializable schemas"
              description={
                <>
                  Skir schemas can be serialized and deserialized as JSON. This enables generic
                  tools, like the Studio app, to understand schema structure.
                </>
              }
            />
            <FeatureCard
              icon={<Package className="h-6 w-6" />}
              title="Key-indexed arrays"
              description={
                <>
                  The array type allows you to specify a key field, e.g. <code>[User|user_id]</code>
                  . On the wire, this is just like an array, but the generated code will give you
                  fast key-based lookups.
                </>
              }
            />
            <FeatureCard
              icon={<Terminal className="h-6 w-6" />} // Using Terminal for Dev Experience
              title="First-class IDE support"
              description={
                <>
                  A powerful{' '}
                  <a
                    href="https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="underline decoration-muted-foreground/50 hover:text-foreground transition-colors"
                  >
                    VS Code extension
                  </a>{' '}
                  and{' '}
                  <a
                    href="https://github.com/gepheum/skir-language-server"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="underline decoration-muted-foreground/50 hover:text-foreground transition-colors"
                  >
                    LSP
                  </a>{' '}
                  with all the features you need. Real-time validation, code completion, automatic
                  code formatting and more.
                </>
              }
            />
            <FeatureCard
              icon={<Terminal className="h-6 w-6" />}
              title="Easy to extend"
              description="Code generators are regular NPM modules, so you can add custom ones without hacking the compiler."
            />
          </div>
        </div>
      </section>

      {/* Language Support Section */}
      <section className="border-t border-border py-14 md:py-20">
        <div className="container mx-auto">
          <div className="mb-12 text-center">
            <h2 className="mb-4 text-3xl font-bold md:text-4xl">Supported languages</h2>
            <p className="mx-auto max-w-2xl text-lg text-muted-foreground">
              Generate production-ready code for all major programming languages.
            </p>
          </div>

          <div className="mx-auto grid max-w-4xl gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <LanguageCard
              name="TypeScript"
              icon={<SiTypescript className="text-[#3178C6]" />}
              href="/docs/typescript"
            />
            <LanguageCard
              name="Python"
              icon={<SiPython className="text-[#3776AB]" />}
              href="/docs/python"
            />
            <LanguageCard
              name="Java"
              icon={<FaJava className="text-[#E76F00]" />}
              href="/docs/java"
            />
            <LanguageCard
              name="C#"
              icon={<SiSharp className="text-[#239120]" />}
              href="/docs/csharp"
            />
            <LanguageCard
              name="C++"
              icon={<SiCplusplus className="text-[#00599C]" />}
              href="/docs/cpp"
            />
            <LanguageCard name="Go" icon={<SiGo className="text-[#00ADD8]" />} href="/docs/go" />
            <LanguageCard
              name="Kotlin"
              icon={<SiKotlin className="text-[#7F52FF]" />}
              href="/docs/kotlin"
            />
            <LanguageCard
              name="Dart"
              icon={<SiDart className="text-[#0175C2]" />}
              href="/docs/dart"
            />
            <LanguageCard
              name="Swift"
              icon={<SiSwift className="text-[#F05138]" />}
              href="/docs/swift"
            />
            <LanguageCard
              name="Rust"
              icon={<SiRust className="text-[#000000] dark:text-[#DEA584]" />}
              href="/docs/rust"
            />
            <LanguageCard name="Zig" icon={<SiZig className="text-[#F7A41D]" />} href="/docs/zig" />
            <LanguageCard
              name="Gleam"
              icon={<SiGleam className="text-[#FFAFF3]" />}
              href="/docs/gleam"
            />
            <LanguageCard
              name="Elixir"
              icon={<SiElixir className="text-[#4B275F] dark:text-[#B99ACD]" />}
              href="/docs/elixir"
            />
            <LanguageCard
              name="MoonBit"
              icon={<Moon className="text-[#F5C84B]" />}
              href="/docs/moonbit"
            />
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="border-t border-border py-14 md:py-20">
        <div className="container mx-auto">
          <div className="max-w-3xl mx-auto text-center">
            <h2 className="mb-4 text-balance text-3xl font-bold md:text-4xl">
              Ready to get started?
            </h2>
            <p className="mb-8 text-lg text-muted-foreground">
              Set up your first Skir project in minutes. Manage your entire project configuration
              from a single YAML file.
            </p>
            <div className="flex flex-col justify-center gap-4 sm:flex-row">
              <Button asChild size="lg" className="rounded-full px-6">
                <Link href="/docs">
                  Read the Docs
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </section>

      <section className="relative overflow-hidden bg-card/30 py-10 md:py-14">
        <WaveDivider colorClass="text-card/30" flip />
        <div className="container mx-auto">
          <div className="max-w-2xl mx-auto text-center">
            <h2 className="mb-3 text-2xl font-semibold md:text-3xl">Join our Discord</h2>
            <p className="mb-6 text-muted-foreground">
              Ask questions, share feedback, and get help from the community.
            </p>
            <Button asChild variant="outline" className="rounded-full px-6">
              <a href="https://discord.gg/FsKrGwJ9AP" target="_blank" rel="noopener noreferrer">
                Join Discord
                <ArrowRight className="ml-2 h-4 w-4" />
              </a>
            </Button>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  )
}
