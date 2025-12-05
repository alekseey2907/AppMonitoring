const alerts = [
  { id: 1, device: 'Трактор МТЗ-82 #1', type: 'vibration_critical', message: 'Критическая вибрация (4.5g)', time: '5 мин', severity: 'critical' },
  { id: 2, device: 'Элеватор мотор #3', type: 'temp_warning', message: 'Высокая температура (65°C)', time: '15 мин', severity: 'warning' },
  { id: 3, device: 'Насос датчик #7', type: 'battery_low', message: 'Низкий заряд батареи (15%)', time: '1 час', severity: 'info' },
  { id: 4, device: 'Комбайн #12', type: 'vibration_warning', message: 'Предупреждение вибрации (2.8g)', time: '2 часа', severity: 'warning' },
]

export function RecentAlerts() {
  return (
    <div className="bg-white rounded-xl shadow-sm">
      <div className="px-4 py-3 border-b flex justify-between items-center">
        <h3 className="text-base font-semibold text-gray-900">Последние алерты</h3>
        <a href="/alerts" className="text-blue-600 text-xs hover:underline">Все алерты →</a>
      </div>
      <div className="divide-y">
        {alerts.map((alert) => (
          <div key={alert.id} className="px-4 py-3 flex items-center hover:bg-gray-50 transition-colors">
            <div className={`w-1.5 h-8 rounded-full mr-3 flex-shrink-0 ${
              alert.severity === 'critical' ? 'bg-red-500' :
              alert.severity === 'warning' ? 'bg-yellow-500' : 'bg-blue-500'
            }`} />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">{alert.message}</p>
              <p className="text-xs text-gray-500">{alert.device}</p>
            </div>
            <span className="text-xs text-gray-400 ml-2 flex-shrink-0">{alert.time}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
