'use client'

import { useState } from 'react'
import { CheckIcon, XMarkIcon } from '@heroicons/react/24/outline'

const alerts = [
  { id: 1, device: 'Комбайн #12', type: 'vibration_critical', message: 'Критическая вибрация (4.5g)', time: '5 мин назад', severity: 'critical', acknowledged: false },
  { id: 2, device: 'Элеватор мотор #3', type: 'temp_warning', message: 'Высокая температура (65°C)', time: '15 мин назад', severity: 'warning', acknowledged: false },
  { id: 3, device: 'Насос датчик #7', type: 'battery_low', message: 'Низкий заряд батареи (15%)', time: '1 час назад', severity: 'info', acknowledged: true },
  { id: 4, device: 'Трактор МТЗ-82 #1', type: 'vibration_warning', message: 'Предупреждение вибрации (2.8g)', time: '2 часа назад', severity: 'warning', acknowledged: true },
  { id: 5, device: 'Генератор #5', type: 'offline', message: 'Устройство не отвечает', time: '2 часа назад', severity: 'warning', acknowledged: false },
  { id: 6, device: 'Комбайн #12', type: 'temp_critical', message: 'Критическая температура (78°C)', time: '3 часа назад', severity: 'critical', acknowledged: true },
]

const severityColors: Record<string, string> = {
  critical: 'border-l-red-500 bg-red-50',
  warning: 'border-l-yellow-500 bg-yellow-50',
  info: 'border-l-blue-500 bg-blue-50',
}

const severityBadge: Record<string, string> = {
  critical: 'bg-red-100 text-red-800',
  warning: 'bg-yellow-100 text-yellow-800',
  info: 'bg-blue-100 text-blue-800',
}

const severityLabels: Record<string, string> = {
  critical: 'Критично',
  warning: 'Внимание',
  info: 'Инфо',
}

export default function AlertsPage() {
  const [filter, setFilter] = useState<'all' | 'active' | 'acknowledged'>('all')

  const filtered = alerts.filter(a => {
    if (filter === 'active') return !a.acknowledged
    if (filter === 'acknowledged') return a.acknowledged
    return true
  })

  const activeCount = alerts.filter(a => !a.acknowledged).length

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Алерты</h1>
          <p className="text-sm text-gray-500">{activeCount} активных алертов</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-lg w-fit">
        {[
          { key: 'all', label: 'Все' },
          { key: 'active', label: 'Активные' },
          { key: 'acknowledged', label: 'Подтверждённые' },
        ].map((tab) => (
          <button
            key={tab.key}
            onClick={() => setFilter(tab.key as typeof filter)}
            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
              filter === tab.key
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Alerts List */}
      <div className="space-y-2">
        {filtered.map((alert) => (
          <div
            key={alert.id}
            className={`border-l-4 rounded-lg p-4 ${severityColors[alert.severity]} ${
              alert.acknowledged ? 'opacity-60' : ''
            }`}
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <span className={`px-2 py-0.5 text-xs font-medium rounded-full ${severityBadge[alert.severity]}`}>
                    {severityLabels[alert.severity]}
                  </span>
                  <span className="text-xs text-gray-500">{alert.time}</span>
                  {alert.acknowledged && (
                    <span className="flex items-center gap-1 text-xs text-green-600">
                      <CheckIcon className="h-3 w-3" />
                      Подтверждено
                    </span>
                  )}
                </div>
                <p className="text-sm font-medium text-gray-900">{alert.message}</p>
                <p className="text-xs text-gray-600 mt-0.5">{alert.device}</p>
              </div>
              {!alert.acknowledged && (
                <div className="flex gap-1">
                  <button className="p-1.5 text-green-600 hover:bg-green-100 rounded-lg" title="Подтвердить">
                    <CheckIcon className="h-4 w-4" />
                  </button>
                  <button className="p-1.5 text-gray-400 hover:bg-gray-100 rounded-lg" title="Закрыть">
                    <XMarkIcon className="h-4 w-4" />
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
