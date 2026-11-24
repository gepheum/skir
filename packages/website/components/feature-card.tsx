import type { ReactNode } from 'react'

interface FeatureCardProps {
  icon: ReactNode
  title: string
  description: ReactNode
}

export function FeatureCard({ icon, title, description }: FeatureCardProps) {
  return (
    <div className="soft-surface rounded-xl p-6 transition-colors hover:border-primary/40">
      <div className="mb-4 inline-flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary">
        {icon}
      </div>
      <h3 className="mb-2 text-lg font-semibold">{title}</h3>
      <p className="text-sm text-muted-foreground">{description}</p>
    </div>
  )
}
