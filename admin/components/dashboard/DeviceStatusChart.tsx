'use client'

import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts'

const data = [
  { name: 'Онлайн', value: 115, color: '#22c55e' },
  { name: 'Оффлайн', value: 8, color: '#9ca3af' },
  { name: 'Предупреждение', value: 3, color: '#eab308' },
  { name: 'Критично', value: 2, color: '#ef4444' },
]

export function DeviceStatusChart() {
  return (
    <div className="bg-white rounded-xl shadow-sm p-4">
      <h3 className="text-base font-semibold text-gray-900 mb-3">Статус устройств</h3>
      <div className="h-52">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius={50}
              outerRadius={75}
              paddingAngle={3}
              dataKey="value"
              label={({ name, percent }) => `${(percent * 100).toFixed(0)}%`}
              labelLine={false}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip 
              formatter={(value: number) => [`${value} устр.`, '']}
              contentStyle={{ fontSize: 12, borderRadius: 8 }}
            />
            <Legend 
              wrapperStyle={{ fontSize: 11 }}
              formatter={(value) => <span className="text-gray-600">{value}</span>}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
