'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

const data = [
  { time: '00:00', value: 42 },
  { time: '02:00', value: 38 },
  { time: '04:00', value: 40 },
  { time: '06:00', value: 45 },
  { time: '08:00', value: 55 },
  { time: '10:00', value: 60 },
  { time: '12:00', value: 62 },
  { time: '14:00', value: 64 },
  { time: '16:00', value: 58 },
  { time: '18:00', value: 52 },
  { time: '20:00', value: 48 },
  { time: '22:00', value: 45 },
  { time: '24:00', value: 44 },
]

export default function TemperatureLineChart() {
  return (
    <div className="h-48">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 10, left: -15, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="time" tick={{ fontSize: 10 }} stroke="#9ca3af" interval={2} />
          <YAxis tick={{ fontSize: 10 }} stroke="#9ca3af" domain={[30, 80]} />
          <Tooltip 
            contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
            formatter={(value: number) => [`${value}°C`, 'Температура']}
          />
          <Line 
            type="monotone" 
            dataKey="value" 
            stroke="#ef4444" 
            strokeWidth={2}
            dot={{ fill: '#ef4444', strokeWidth: 0, r: 3 }}
            activeDot={{ r: 5, fill: '#dc2626' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
