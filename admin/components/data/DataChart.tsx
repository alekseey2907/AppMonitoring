'use client'

import { useMemo } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart } from 'recharts'

interface TemperatureRecord {
  timestamp: string
  deviceId: string
  deviceName: string
  temperature: number
  vibration: number
}

interface DataChartProps {
  data: TemperatureRecord[]
}

export default function DataChart({ data }: DataChartProps) {
  const chartData = useMemo(() => {
    // Группируем по времени (округляем до часа)
    const grouped = new Map<string, { temp: number[], vib: number[] }>()
    
    data.forEach(record => {
      const date = new Date(record.timestamp)
      date.setMinutes(0, 0, 0)
      const key = date.toISOString()
      
      if (!grouped.has(key)) {
        grouped.set(key, { temp: [], vib: [] })
      }
      grouped.get(key)!.temp.push(record.temperature)
      grouped.get(key)!.vib.push(record.vibration)
    })
    
    // Усредняем значения
    const result = Array.from(grouped.entries()).map(([timestamp, values]) => ({
      time: new Date(timestamp).toLocaleString('ru-RU', { 
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
      }),
      timestamp: new Date(timestamp).getTime(),
      temperature: Math.round(values.temp.reduce((a, b) => a + b, 0) / values.temp.length * 10) / 10,
      vibration: Math.round(values.vib.reduce((a, b) => a + b, 0) / values.vib.length * 100) / 100,
    }))
    
    return result.sort((a, b) => a.timestamp - b.timestamp)
  }, [data])

  // Статистика
  const stats = useMemo(() => {
    if (data.length === 0) return null
    
    const temps = data.map(d => d.temperature)
    const vibs = data.map(d => d.vibration)
    
    return {
      tempMin: Math.min(...temps),
      tempMax: Math.max(...temps),
      tempAvg: Math.round(temps.reduce((a, b) => a + b, 0) / temps.length * 10) / 10,
      vibMin: Math.min(...vibs),
      vibMax: Math.max(...vibs),
      vibAvg: Math.round(vibs.reduce((a, b) => a + b, 0) / vibs.length * 100) / 100,
    }
  }, [data])

  if (data.length === 0) {
    return (
      <div className="h-64 flex items-center justify-center text-gray-500">
        Нет данных для отображения
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="bg-red-50 rounded-lg p-3 text-center">
            <p className="text-xs text-red-600">Мин. темп.</p>
            <p className="text-lg font-bold text-red-700">{stats.tempMin}°C</p>
          </div>
          <div className="bg-red-50 rounded-lg p-3 text-center">
            <p className="text-xs text-red-600">Макс. темп.</p>
            <p className="text-lg font-bold text-red-700">{stats.tempMax}°C</p>
          </div>
          <div className="bg-red-50 rounded-lg p-3 text-center">
            <p className="text-xs text-red-600">Ср. темп.</p>
            <p className="text-lg font-bold text-red-700">{stats.tempAvg}°C</p>
          </div>
          <div className="bg-blue-50 rounded-lg p-3 text-center">
            <p className="text-xs text-blue-600">Мин. вибр.</p>
            <p className="text-lg font-bold text-blue-700">{stats.vibMin} g</p>
          </div>
          <div className="bg-blue-50 rounded-lg p-3 text-center">
            <p className="text-xs text-blue-600">Макс. вибр.</p>
            <p className="text-lg font-bold text-blue-700">{stats.vibMax} g</p>
          </div>
          <div className="bg-blue-50 rounded-lg p-3 text-center">
            <p className="text-xs text-blue-600">Ср. вибр.</p>
            <p className="text-lg font-bold text-blue-700">{stats.vibAvg} g</p>
          </div>
        </div>
      )}

      {/* Two Separate Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Temperature Chart */}
        <div className="bg-red-50/30 rounded-xl p-4 border border-red-100">
          <div className="flex items-center justify-between mb-3">
            <h4 className="font-semibold text-gray-900 flex items-center gap-2">
              🌡️ Температура
            </h4>
            <span className="text-sm text-red-600 font-medium">
              Макс: {stats?.tempMax}°C
            </span>
          </div>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
                <defs>
                  <linearGradient id="tempGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#fecaca" />
                <XAxis 
                  dataKey="time" 
                  tick={{ fontSize: 10, fill: '#6b7280' }}
                  tickLine={{ stroke: '#fecaca' }}
                />
                <YAxis 
                  tick={{ fontSize: 10, fill: '#6b7280' }}
                  tickLine={{ stroke: '#fecaca' }}
                  domain={['auto', 'auto']}
                  unit="°C"
                />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: 'white', 
                    border: '1px solid #fecaca',
                    borderRadius: '8px',
                    boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)'
                  }}
                  formatter={(value: number) => [`${value}°C`, 'Температура']}
                />
                <Area 
                  type="monotone" 
                  dataKey="temperature" 
                  stroke="#ef4444" 
                  strokeWidth={2}
                  fill="url(#tempGradient)"
                />
                <Line 
                  type="monotone" 
                  dataKey="temperature" 
                  stroke="#ef4444" 
                  strokeWidth={2}
                  dot={{ fill: '#ef4444', r: 3 }}
                  activeDot={{ r: 5, fill: '#dc2626' }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Vibration Chart */}
        <div className="bg-blue-50/30 rounded-xl p-4 border border-blue-100">
          <div className="flex items-center justify-between mb-3">
            <h4 className="font-semibold text-gray-900 flex items-center gap-2">
              🔊 Вибрация
            </h4>
            <span className="text-sm text-blue-600 font-medium">
              Макс: {stats?.vibMax} g
            </span>
          </div>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
                <defs>
                  <linearGradient id="vibGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#bfdbfe" />
                <XAxis 
                  dataKey="time" 
                  tick={{ fontSize: 10, fill: '#6b7280' }}
                  tickLine={{ stroke: '#bfdbfe' }}
                />
                <YAxis 
                  tick={{ fontSize: 10, fill: '#6b7280' }}
                  tickLine={{ stroke: '#bfdbfe' }}
                  domain={[0, 'auto']}
                  unit=" g"
                />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: 'white', 
                    border: '1px solid #bfdbfe',
                    borderRadius: '8px',
                    boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)'
                  }}
                  formatter={(value: number) => [`${value} g`, 'Вибрация']}
                />
                <Area 
                  type="monotone" 
                  dataKey="vibration" 
                  stroke="#3b82f6" 
                  strokeWidth={2}
                  fill="url(#vibGradient)"
                />
                <Line 
                  type="monotone" 
                  dataKey="vibration" 
                  stroke="#3b82f6" 
                  strokeWidth={2}
                  dot={{ fill: '#3b82f6', r: 3 }}
                  activeDot={{ r: 5, fill: '#2563eb' }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}
