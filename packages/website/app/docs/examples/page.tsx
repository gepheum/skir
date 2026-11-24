import { Prose } from '@/components/prose'

export const metadata = {
  title: 'Project examples - Skir Documentation',
  description: 'Explore real-world Skir projects and starter repositories across languages.',
}

const languageStarters = [
  {
    title: 'C++',
    href: 'https://github.com/gepheum/skir-cc-example',
    framework: 'cpp-httplib',
    notes: 'CMake + GoogleTest integration.',
  },
  {
    title: 'C#',
    href: 'https://github.com/gepheum/skir-csharp-example',
    framework: 'ASP.NET Core',
    notes: 'NET 10 project with skir_client NuGet runtime dependency.',
  },
  {
    title: 'Dart',
    href: 'https://github.com/gepheum/skir-dart-example',
    framework: 'Shelf',
    notes: 'Dart 3 project with pub dependencies.',
  },
  {
    title: 'Elixir',
    href: 'https://github.com/mishmish-dev/skir-elixir-example',
    framework: 'Plug + Bandit',
    notes: 'Mix project with Elixir and TypeScript RPC clients.',
  },
  {
    title: 'Gleam',
    href: 'https://github.com/gepheum/skir-gleam-example',
    framework: 'Wisp',
    notes: 'Gleam project with generated Skir types and RPC wiring.',
  },
  {
    title: 'Go',
    href: 'https://github.com/gepheum/skir-go-example',
    framework: 'net/http',
    notes: 'Standard library HTTP server, no external framework.',
  },
  {
    title: 'Java',
    href: 'https://github.com/gepheum/skir-java-example',
    framework: 'Spring Boot',
    notes: 'Gradle build and run workflow.',
  },
  {
    title: 'Kotlin',
    href: 'https://github.com/gepheum/skir-kotlin-example',
    framework: 'Ktor',
    notes: 'Gradle Kotlin DSL setup.',
  },
  {
    title: 'MoonBit',
    href: 'https://github.com/gepheum/skir-moonbit-example',
    framework: 'moonbit/http',
    notes: 'MoonBit package workflow with generated Skir RPC endpoints.',
  },
  {
    title: 'Python',
    href: 'https://github.com/gepheum/skir-python-example',
    framework: 'Flask / FastAPI / Litestar',
    notes: 'Multiple server frameworks included.',
  },
  {
    title: 'Rust',
    href: 'https://github.com/gepheum/skir-rust-example',
    framework: 'Axum',
    notes: 'Cargo workspace, async Axum server.',
  },
  {
    title: 'Swift',
    href: 'https://github.com/gepheum/skir-swift-example',
    framework: 'Vapor',
    notes: 'SwiftPM package with generated sources under Sources/skirout.',
  },
  {
    title: 'TypeScript',
    href: 'https://github.com/gepheum/skir-typescript-example',
    framework: 'Express',
    notes: 'Node server + browser client bundle.',
  },
  {
    title: 'Zig',
    href: 'https://github.com/gepheum/skir-zig-example',
    framework: 'std.http.Server',
    notes: 'Zig build workflow with Skir client dependency in build.zig.zon.',
  },
]

const projects = [
  {
    title: 'Multilingual Skir example',
    href: 'https://github.com/gepheum/skir-multilingual-example',
    description:
      'Minimal web app showing a Python backend and TypeScript frontend exchanging typed RPC messages.',
    type: 'End-to-end app',
    backend: 'Python (http.server)',
    frontend: 'TypeScript (Vite)',
  },
  {
    title: 'Intergalactic Lost & Found',
    href: 'https://github.com/gepheum/skir-lost-and-found-example',
    description:
      'Full-stack demo with a Kotlin backend and TypeScript frontend that share Skir RPC types end-to-end.',
    type: 'End-to-end app',
    backend: 'Kotlin (Ktor)',
    frontend: 'TypeScript (Vite)',
  },
  {
    title: 'Fantasy Game schema package',
    href: 'https://github.com/gepheum/skir-fantasy-game-example',
    description:
      'Standalone schema repository intended to be imported as a Skir dependency from other projects.',
    type: 'Schema-only project',
    backend: '—',
    frontend: '—',
  },
  {
    title: 'RPC Studio demo',
    href: 'https://github.com/gepheum/skir-studio-demo',
    description:
      'TypeScript geometry service that highlights RPC Studio with rich request and response types and interactive exploration. Run with npx skir-studio-demo.',
    type: 'Service demo',
    backend: 'TypeScript (Express)',
    frontend: 'RPC Studio',
  },
  {
    title: 'Hello Skir Flutter',
    href: 'https://github.com/gepheum/hello-skir-flutter',
    description:
      'Mobile application built with Flutter, communicating with a Bun backend via SkirRPC.',
    type: 'End-to-end mobile app',
    backend: 'TypeScript (Bun)',
    frontend: 'Flutter',
  },
]

export default function ExamplesPage() {
  return (
    <Prose>
      <h1>Project examples</h1>
      <p>
        Browse these repositories to see how Skir fits into different stacks and workflows. Each
        example is designed to spotlight a specific integration pattern or capability.
      </p>

      <h2>Language starter projects</h2>
      <p>
        Each starter focuses on the same core workflow, implemented in a different language. They
        all demonstrate how to:
      </p>
      <ul>
        <li>Set up Skir in a project and run code generation.</li>
        <li>Use generated data classes in application code.</li>
        <li>Start a SkirRPC service on the server side and call it from a client.</li>
        <li>Inspect types at runtime via reflection.</li>
        <li>Optional: write language-specific unit tests.</li>
      </ul>
      <div className="not-prose mt-6 overflow-hidden rounded-lg border border-border">
        <table className="w-full border-collapse text-sm">
          <thead className="bg-secondary/50 text-left">
            <tr>
              <th className="border-b border-border px-4 py-3">Language</th>
              <th className="border-b border-border px-4 py-3">Server framework</th>
              <th className="border-b border-border px-4 py-3">Notes</th>
              <th className="border-b border-border px-4 py-3 w-24 whitespace-nowrap">Source</th>
            </tr>
          </thead>
          <tbody>
            {languageStarters.map((example) => (
              <tr
                key={example.href}
                className="border-b border-border last:border-0 transition-colors hover:bg-secondary/30"
              >
                <td className="px-4 py-3 font-medium text-foreground">{example.title}</td>
                <td className="px-4 py-3 text-muted-foreground">{example.framework}</td>
                <td className="px-4 py-3 text-muted-foreground">{example.notes}</td>
                <td className="px-4 py-3 font-medium text-primary w-24 whitespace-nowrap">
                  <a
                    href={example.href}
                    target="_blank"
                    rel="noreferrer"
                    className="hover:underline"
                  >
                    GitHub
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2>Projects and demos</h2>
      <p>Complete applications and specialized projects showing Skir in real usage.</p>
      <div className="not-prose mt-6 overflow-hidden rounded-lg border border-border">
        <table className="w-full border-collapse text-sm">
          <thead className="bg-secondary/50 text-left">
            <tr>
              <th className="border-b border-border px-4 py-3">Project</th>
              <th className="border-b border-border px-4 py-3">Type</th>
              <th className="border-b border-border px-4 py-3">Backend</th>
              <th className="border-b border-border px-4 py-3">Frontend</th>
              <th className="border-b border-border px-4 py-3 w-24 whitespace-nowrap">Source</th>
            </tr>
          </thead>
          <tbody>
            {projects.map((example) => (
              <tr
                key={example.href}
                className="border-b border-border last:border-0 transition-colors hover:bg-secondary/30"
              >
                <td className="px-4 py-3 font-medium text-foreground">
                  {example.title}
                  <div className="mt-1 text-xs text-muted-foreground">{example.description}</div>
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-muted-foreground">
                  {example.type}
                </td>
                <td className="px-4 py-3 text-muted-foreground">{example.backend}</td>
                <td className="px-4 py-3 text-muted-foreground">{example.frontend}</td>
                <td className="px-4 py-3 font-medium text-primary w-24 whitespace-nowrap">
                  <a
                    href={example.href}
                    target="_blank"
                    rel="noreferrer"
                    className="hover:underline"
                  >
                    GitHub
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Prose>
  )
}
