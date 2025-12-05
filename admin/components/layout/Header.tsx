'use client'

import { BellIcon, UserCircleIcon } from '@heroicons/react/24/outline'

export function Header() {
  return (
    <header className="bg-white border-b px-4 py-3">
      <div className="flex items-center justify-between">
        {/* Search - с отступом слева на мобильных для гамбургера */}
        <div className="flex-1 max-w-md ml-10 md:ml-0">
          <input
            type="search"
            placeholder="Поиск устройств, алертов..."
            className="w-full px-3 py-1.5 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        
        {/* Right side */}
        <div className="flex items-center space-x-3">
          {/* Notifications */}
          <button className="relative p-1.5 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100">
            <BellIcon className="h-5 w-5" />
            <span className="absolute top-0.5 right-0.5 h-2 w-2 bg-red-500 rounded-full"></span>
          </button>
          
          {/* User menu */}
          <div className="flex items-center">
            <UserCircleIcon className="h-7 w-7 text-gray-400" />
            <div className="ml-2 hidden sm:block">
              <p className="text-sm font-medium text-gray-900">Админ</p>
              <p className="text-xs text-gray-500">admin@vibemon.io</p>
            </div>
          </div>
        </div>
      </div>
    </header>
  )
}
