'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

const data = [
  { time: '00:00', value: 1.2 },
  { time: '02:00', value: 1.0 },
  { time: '04:00', value: 1.1 },
  { time: '06:00', value: 1.4 },
  { time: '08:00', value: 2.3 },
  { time: '10:00', value: 2.8 },
  { time: '12:00', value: 3.1 },
  { time: '14:00', value: 2.9 },
  { time: '16:00', value: 2.8 },
  { time: '18:00', value: 2.2 },
  { time: '20:00', value: 1.8 },
  { time: '22:00', value: 1.5 },
  { time: '24:00', value: 1.4 },
]

export default function VibrationLineChart() {
  return (
    <div className="h-48">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 10, left: -15, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="time" tick={{ fontSize: 10 }} stroke="#9ca3af" interval={2} />
          <YAxis tick={{ fontSize: 10 }} stroke="#9ca3af" domain={[0, 4]} />
          <Tooltip 
            contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
            formatter={(value: number) => [`${value} g`, 'Вибрация']}
          />
          <Line 
            type="monotone" 
            dataKey="value" 
            stroke="#3b82f6" 
            strokeWidth={2}
            dot={{ fill: '#3b82f6', strokeWidth: 0, r: 3 }}
            activeDot={{ r: 5, fill: '#2563eb' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
