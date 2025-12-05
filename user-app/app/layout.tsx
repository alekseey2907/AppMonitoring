import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'VibeMon - Мониторинг оборудования',
  description: 'Система мониторинга вибрации и температуры',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ru">
      <body className="bg-gray-50 min-h-screen">{children}</body>
    </html>
  )
}
