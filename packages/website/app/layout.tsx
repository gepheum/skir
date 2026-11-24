import { ScrollToTop } from '@/components/scroll-to-top'
import { ThemeProvider } from '@/components/theme-provider'
import type { Metadata } from 'next'
import { IBM_Plex_Sans, JetBrains_Mono } from 'next/font/google'
import React from 'react'
import './globals.css'

const ibmPlexSans = IBM_Plex_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  weight: ['400', '500', '600', '700'],
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'Skir - Types that travel',
  description:
    'A declarative language for representing data types and APIs. Define your schema once and generate idiomatic, type-safe code for TypeScript, Python, Java, C#, C++, Kotlin, Dart, Swift, Go, Rust, Zig, Gleam, MoonBit, and Elixir.',
  keywords: [
    'skir',
    'protocol buffer',
    'protobuf',
    'serialization',
    'rpc',
    'typescript',
    'python',
    'java',
    'c#',
    'csharp',
    'c++',
    'kotlin',
    'moonbit',
    'dart',
    'swift',
    'rust',
    'zig',
    'gleam',
    'elixir',
    'schema',
    'codegen',
  ],
  authors: [{ name: 'Gepheum' }],
  icons: {
    icon: [
      { url: '/octopus.svg', type: 'image/svg+xml' },
      { url: '/octopus-16x16.png', sizes: '16x16', type: 'image/png' },
      { url: '/octopus-32x32.png', sizes: '32x32', type: 'image/png' },
      { url: '/octopus-48x48.png', sizes: '48x48', type: 'image/png' },
      { url: '/octopus-64x64.png', sizes: '64x64', type: 'image/png' },
      { url: '/octopus-192x192.png', sizes: '192x192', type: 'image/png' },
      { url: '/octopus-256x256.png', sizes: '256x256', type: 'image/png' },
      { url: '/octopus-512x512.png', sizes: '512x512', type: 'image/png' },
    ],
    apple: [{ url: '/octopus-180x180.png', sizes: '180x180', type: 'image/png' }],
  },
  openGraph: {
    title: 'Skir - Types that travel',
    description: 'A descriptive language for representing data types and APIs.',
    type: 'website',
  },
  generator: 'v0.app',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${ibmPlexSans.variable} ${jetbrainsMono.variable} font-sans antialiased`}>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <ScrollToTop />
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}
