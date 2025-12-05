'use client'

import dynamic from 'next/dynamic'

const VibrationChart = dynamic(() => import('./charts/VibrationLineChart'), { 
  ssr: false,
  loading: () => <div className="h-48 flex items-center justify-center text-gray-400">Загрузка...</div>
})

const TemperatureChart = dynamic(() => import('./charts/TemperatureLineChart'), { 
  ssr: false,
  loading: () => <div className="h-48 flex items-center justify-center text-gray-400">Загрузка...</div>
})

export function VibrationTrendChart() {
  return (
    <div className="bg-white rounded-xl shadow-sm p-4">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-base font-semibold text-gray-900">🔊 Вибрация (24ч)</h3>
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">Макс:</span>
          <span className="text-sm font-bold text-blue-600">3.1 g</span>
        </div>
      </div>
      <VibrationChart />
    </div>
  )
}

export function TemperatureTrendChart() {
  return (
    <div className="bg-white rounded-xl shadow-sm p-4">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-base font-semibold text-gray-900">🌡️ Температура (24ч)</h3>
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">Макс:</span>
          <span className="text-sm font-bold text-red-600">64°C</span>
        </div>
      </div>
      <TemperatureChart />
    </div>
  )
}
