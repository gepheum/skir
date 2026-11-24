'use client'

import { usePathname } from 'next/navigation'
import { useEffect } from 'react'

export function ScrollToTop() {
  const pathname = usePathname()

  useEffect(() => {
    // Preserve in-page anchor navigation.
    if (window.location.hash) {
      return
    }

    // Ensure route navigations land exactly at the top.
    const raf = requestAnimationFrame(() => {
      window.scrollTo({ top: 0, left: 0, behavior: 'auto' })
    })

    return () => cancelAnimationFrame(raf)
  }, [pathname])

  return null
}
