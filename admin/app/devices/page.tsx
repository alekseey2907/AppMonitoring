'use client'

import { useState } from 'react'
import { MagnifyingGlassIcon, FunnelIcon, PlusIcon, BoltIcon, Battery50Icon, ClockIcon } from '@heroicons/react/24/outline'

const devices = [
  { id: 1, name: 'Трактор МТЗ-82 #1', serial: 'VBM-2024-001', status: 'online', vibration: 1.2, temp: 45, battery: 85, lastSeen: '2 мин назад' },
  { id: 2, name: 'Элеватор мотор #3', serial: 'VBM-2024-002', status: 'warning', vibration: 2.8, temp: 65, battery: 72, lastSeen: '1 мин назад' },
  { id: 3, name: 'Насос датчик #7', serial: 'VBM-2024-003', status: 'online', vibration: 0.8, temp: 38, battery: 15, lastSeen: '5 мин назад' },
  { id: 4, name: 'Комбайн #12', serial: 'VBM-2024-004', status: 'critical', vibration: 4.5, temp: 78, battery: 45, lastSeen: '30 сек назад' },
  { id: 5, name: 'Генератор #5', serial: 'VBM-2024-005', status: 'offline', vibration: 0, temp: 0, battery: 0, lastSeen: '2 часа назад' },
  { id: 6, name: 'Компрессор #8', serial: 'VBM-2024-006', status: 'online', vibration: 1.5, temp: 52, battery: 91, lastSeen: '1 мин назад' },
]

const statusColors: Record<string, string> = {
  online: 'bg-green-100 text-green-800',
  warning: 'bg-yellow-100 text-yellow-800',
  critical: 'bg-red-100 text-red-800',
  offline: 'bg-gray-100 text-gray-800',
}

const statusLabels: Record<string, string> = {
  online: 'Онлайн',
  warning: 'Внимание',
  critical: 'Критично',
  offline: 'Оффлайн',
}

export default function DevicesPage() {
  const [search, setSearch] = useState('')

  const filtered = devices.filter(d => 
    d.name.toLowerCase().includes(search.toLowerCase()) ||
    d.serial.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-900">Устройства</h1>
        <button className="flex items-center gap-2 bg-blue-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-blue-700">
          <PlusIcon className="h-4 w-4" />
          Добавить
        </button>
      </div>

      {/* Filters */}
      <div className="flex gap-3">
        <div className="flex-1 relative">
          <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Поиск по названию или се..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <button className="flex items-center gap-2 px-3 py-2 border rounded-lg text-sm text-gray-600 hover:bg-gray-50">
          <FunnelIcon className="h-4 w-4" />
          Фильтры
        </button>
      </div>

      {/* Mobile Cards View */}
      <div className="md:hidden space-y-3">
        {filtered.map((device) => (
          <div key={device.id} className="bg-white rounded-xl shadow-sm p-4 space-y-3">
            {/* Header */}
            <div className="flex items-start justify-between">
              <div>
                <p className="font-medium text-gray-900">{device.name}</p>
                <p className="text-xs text-gray-500">{device.serial}</p>
              </div>
              <span className={`inline-flex px-2 py-0.5 text-xs font-medium rounded-full ${statusColors[device.status]}`}>
                {statusLabels[device.status]}
              </span>
            </div>
            
            {/* Metrics Grid */}
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-blue-50 rounded-lg p-2">
                <div className="flex items-center gap-1 text-xs text-blue-600 mb-1">
                  <BoltIcon className="h-3 w-3" />
                  Вибрация
                </div>
                <p className="text-lg font-semibold text-blue-700">{device.vibration} g</p>
              </div>
              <div className="bg-red-50 rounded-lg p-2">
                <div className="flex items-center gap-1 text-xs text-red-600 mb-1">
                  🌡️ Температура
                </div>
                <p className="text-lg font-semibold text-red-700">{device.temp}°C</p>
              </div>
            </div>

            {/* Footer */}
            <div className="flex items-center justify-between pt-2 border-t">
              <div className="flex items-center gap-2">
                <Battery50Icon className={`h-4 w-4 ${device.battery > 20 ? 'text-green-500' : 'text-red-500'}`} />
                <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div 
                    className={`h-full rounded-full ${device.battery > 20 ? 'bg-green-500' : 'bg-red-500'}`}
                    style={{ width: `${device.battery}%` }}
                  />
                </div>
                <span className="text-xs text-gray-600">{device.battery}%</span>
              </div>
              <div className="flex items-center gap-1 text-xs text-gray-500">
                <ClockIcon className="h-3 w-3" />
                {device.lastSeen}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Desktop Table View */}
      <div className="hidden md:block bg-white rounded-xl shadow-sm overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Устройство</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Статус</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Вибрация</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Темп.</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Батарея</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Последняя связь</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filtered.map((device) => (
              <tr key={device.id} className="hover:bg-gray-50 cursor-pointer">
                <td className="px-4 py-3">
                  <div>
                    <p className="text-sm font-medium text-gray-900">{device.name}</p>
                    <p className="text-xs text-gray-500">{device.serial}</p>
                  </div>
                </td>
                <td className="px-4 py-3">
                  <span className={`inline-flex px-2 py-0.5 text-xs font-medium rounded-full ${statusColors[device.status]}`}>
                    {statusLabels[device.status]}
                  </span>
                </td>
                <td className="px-4 py-3 text-sm text-gray-900">{device.vibration} g</td>
                <td className="px-4 py-3 text-sm text-gray-900">{device.temp}°C</td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                      <div 
                        className={`h-full rounded-full ${device.battery > 20 ? 'bg-green-500' : 'bg-red-500'}`}
                        style={{ width: `${device.battery}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-500">{device.battery}%</span>
                  </div>
                </td>
                <td className="px-4 py-3 text-sm text-gray-500">{device.lastSeen}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
