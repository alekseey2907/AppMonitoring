'use client'

import { ArrowUpTrayIcon, ArrowDownTrayIcon, CheckCircleIcon, ClockIcon } from '@heroicons/react/24/outline'

const firmwareVersions = [
  { version: '2.1.0', date: '2024-12-01', status: 'current', devices: 98, changelog: 'Улучшена стабильность BLE, оптимизация энергопотребления' },
  { version: '2.0.5', date: '2024-11-15', status: 'available', devices: 20, changelog: 'Исправлены ошибки калибровки датчиков' },
  { version: '2.0.0', date: '2024-10-20', status: 'available', devices: 8, changelog: 'Добавлена поддержка OTA обновлений' },
  { version: '1.5.2', date: '2024-09-01', status: 'deprecated', devices: 2, changelog: 'Устаревшая версия' },
]

const statusLabels: Record<string, string> = {
  current: 'Текущая',
  available: 'Доступна',
  deprecated: 'Устарела',
}

const statusColors: Record<string, string> = {
  current: 'bg-green-100 text-green-800',
  available: 'bg-blue-100 text-blue-800',
  deprecated: 'bg-red-100 text-red-800',
}

const pendingUpdates = [
  { device: 'Трактор МТЗ-82 #1', from: '2.0.5', to: '2.1.0', status: 'pending' },
  { device: 'Элеватор мотор #3', from: '2.0.0', to: '2.1.0', status: 'in_progress' },
  { device: 'Комбайн #12', from: '2.0.5', to: '2.1.0', status: 'completed' },
]

export default function FirmwarePage() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-900">Прошивка</h1>
        <button className="flex items-center gap-2 bg-blue-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-blue-700">
          <ArrowUpTrayIcon className="h-4 w-4" />
          Загрузить версию
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Актуальная версия</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">v2.1.0</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Устройств на актуальной</p>
          <p className="text-2xl font-bold text-green-600 mt-1">76%</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Ожидают обновления</p>
          <p className="text-2xl font-bold text-yellow-600 mt-1">30</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Versions */}
        <div className="bg-white rounded-xl shadow-sm">
          <div className="px-4 py-3 border-b">
            <h3 className="font-semibold text-gray-900">Версии прошивки</h3>
          </div>
          <div className="divide-y">
            {firmwareVersions.map((fw) => (
              <div key={fw.version} className="px-4 py-3 flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-gray-900">v{fw.version}</span>
                    <span className={`px-2 py-0.5 text-xs font-medium rounded-full ${statusColors[fw.status]}`}>
                      {statusLabels[fw.status]}
                    </span>
                  </div>
                  <p className="text-xs text-gray-500 mt-0.5">{fw.changelog}</p>
                  <p className="text-xs text-gray-400 mt-0.5">{fw.date} • {fw.devices} устройств</p>
                </div>
                <button className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded">
                  <ArrowDownTrayIcon className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Pending Updates */}
        <div className="bg-white rounded-xl shadow-sm">
          <div className="px-4 py-3 border-b">
            <h3 className="font-semibold text-gray-900">Обновления в процессе</h3>
          </div>
          <div className="divide-y">
            {pendingUpdates.map((update, i) => (
              <div key={i} className="px-4 py-3 flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-900">{update.device}</p>
                  <p className="text-xs text-gray-500">v{update.from} → v{update.to}</p>
                </div>
                {update.status === 'completed' ? (
                  <CheckCircleIcon className="h-5 w-5 text-green-500" />
                ) : update.status === 'in_progress' ? (
                  <div className="flex items-center gap-1 text-blue-600">
                    <div className="w-4 h-4 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
                    <span className="text-xs">45%</span>
                  </div>
                ) : (
                  <ClockIcon className="h-5 w-5 text-gray-400" />
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
