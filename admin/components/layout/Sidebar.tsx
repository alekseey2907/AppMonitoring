'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import clsx from 'clsx'
import {
  HomeIcon,
  DevicePhoneMobileIcon,
  BellAlertIcon,
  ChartBarIcon,
  UsersIcon,
  BuildingOfficeIcon,
  Cog6ToothIcon,
  ArrowUpTrayIcon,
  Bars3Icon,
  XMarkIcon,
  CircleStackIcon,
} from '@heroicons/react/24/outline'

const navigation = [
  { name: 'Панель', href: '/', icon: HomeIcon },
  { name: 'Устройства', href: '/devices', icon: DevicePhoneMobileIcon },
  { name: 'Данные', href: '/data', icon: CircleStackIcon },
  { name: 'Алерты', href: '/alerts', icon: BellAlertIcon },
  { name: 'Аналитика', href: '/analytics', icon: ChartBarIcon },
  { name: 'Пользователи', href: '/users', icon: UsersIcon },
  { name: 'Организации', href: '/organizations', icon: BuildingOfficeIcon },
  { name: 'Прошивка', href: '/firmware', icon: ArrowUpTrayIcon },
  { name: 'Настройки', href: '/settings', icon: Cog6ToothIcon },
]

export function Sidebar() {
  const pathname = usePathname()
  const [mobileOpen, setMobileOpen] = useState(false)

  const NavContent = () => (
    <>
      {/* Logo */}
      <div className="flex items-center flex-shrink-0 px-3 py-4">
        <div className="flex items-center">
          <div className="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-sm">V</span>
          </div>
          <span className="ml-2 text-lg font-bold text-gray-900">VibeMon</span>
        </div>
      </div>
      
      {/* Navigation */}
      <nav className="flex-1 px-2 space-y-1">
        {navigation.map((item) => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.name}
              href={item.href}
              onClick={() => setMobileOpen(false)}
              className={clsx(
                'group flex items-center px-2 py-2 text-sm font-medium rounded-lg transition-colors',
                isActive
                  ? 'bg-blue-50 text-blue-600'
                  : 'text-gray-700 hover:bg-gray-100'
              )}
            >
              <item.icon
                className={clsx(
                  'mr-2 h-5 w-5 flex-shrink-0',
                  isActive ? 'text-blue-600' : 'text-gray-400 group-hover:text-gray-500'
                )}
              />
              {item.name}
            </Link>
          )
        })}
      </nav>
      
      {/* Version */}
      <div className="flex-shrink-0 p-3 border-t">
        <p className="text-xs text-gray-500">VibeMon v1.0.0</p>
      </div>
    </>
  )

  return (
    <>
      {/* Mobile menu button */}
      <button
        onClick={() => setMobileOpen(true)}
        className="md:hidden fixed top-3 left-3 z-50 p-2 bg-white rounded-lg shadow-md"
      >
        <Bars3Icon className="h-6 w-6 text-gray-600" />
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div 
          className="md:hidden fixed inset-0 z-40 bg-black/50"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Mobile drawer */}
      <div className={clsx(
        'md:hidden fixed inset-y-0 left-0 z-50 w-64 bg-white transform transition-transform duration-300 ease-in-out flex flex-col',
        mobileOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        <button
          onClick={() => setMobileOpen(false)}
          className="absolute top-3 right-3 p-1"
        >
          <XMarkIcon className="h-6 w-6 text-gray-500" />
        </button>
        <NavContent />
      </div>

      {/* Desktop sidebar */}
      <div className="hidden md:flex md:w-56 md:flex-col">
        <div className="flex flex-col flex-grow bg-white border-r overflow-y-auto">
          <NavContent />
        </div>
      </div>
    </>
  )
}
