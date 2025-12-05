'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Legend } from 'recharts'

const vibrationData = [
  { date: '25 Ноя', avg: 1.4, max: 2.8, alerts: 2 },
  { date: '26 Ноя', avg: 1.6, max: 3.1, alerts: 3 },
  { date: '27 Ноя', avg: 1.3, max: 2.5, alerts: 1 },
  { date: '28 Ноя', avg: 1.8, max: 3.8, alerts: 5 },
  { date: '29 Ноя', avg: 1.5, max: 2.9, alerts: 2 },
  { date: '30 Ноя', avg: 2.1, max: 4.2, alerts: 7 },
  { date: '1 Дек', avg: 1.7, max: 3.2, alerts: 3 },
]

const alertsByType = [
  { type: 'Вибрация', critical: 12, warning: 28 },
  { type: 'Температура', critical: 5, warning: 15 },
  { type: 'Батарея', critical: 2, warning: 8 },
  { type: 'Связь', critical: 3, warning: 12 },
]

export default function AnalyticsPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-gray-900">Аналитика</h1>

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Среднее время работы</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">98.5%</p>
          <p className="text-xs text-green-600 mt-1">+2.1% за месяц</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Всего алертов (7 дн)</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">23</p>
          <p className="text-xs text-red-600 mt-1">+5 к прошлой неделе</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Ср. вибрация</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">1.6 g</p>
          <p className="text-xs text-gray-500 mt-1">норма до 2.0 g</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4">
          <p className="text-xs text-gray-500 uppercase">Ср. температура</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">48°C</p>
          <p className="text-xs text-gray-500 mt-1">норма до 60°C</p>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white rounded-xl shadow-sm p-4">
          <h3 className="text-base font-semibold text-gray-900 mb-3">Тренд вибрации (7 дней)</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={vibrationData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip contentStyle={{ fontSize: 12 }} />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <Line type="monotone" dataKey="avg" name="Средняя" stroke="#3b82f6" strokeWidth={2} />
                <Line type="monotone" dataKey="max" name="Максимум" stroke="#ef4444" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-4">
          <h3 className="text-base font-semibold text-gray-900 mb-3">Алерты по типам</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={alertsByType}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="type" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip contentStyle={{ fontSize: 12 }} />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <Bar dataKey="critical" name="Критические" fill="#ef4444" />
                <Bar dataKey="warning" name="Предупреждения" fill="#eab308" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}
