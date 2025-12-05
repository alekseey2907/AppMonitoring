import {
  DevicePhoneMobileIcon,
  BellAlertIcon,
  SignalIcon,
  ExclamationTriangleIcon,
} from '@heroicons/react/24/outline'

const stats = [
  { 
    name: 'Всего устройств', 
    value: '128', 
    icon: DevicePhoneMobileIcon, 
    change: '+12%', 
    bgColor: 'bg-blue-100',
    iconColor: 'text-blue-600'
  },
  { 
    name: 'Онлайн', 
    value: '115', 
    icon: SignalIcon, 
    change: '+3%', 
    bgColor: 'bg-green-100',
    iconColor: 'text-green-600'
  },
  { 
    name: 'Активных алертов', 
    value: '7', 
    icon: BellAlertIcon, 
    change: '-2', 
    bgColor: 'bg-yellow-100',
    iconColor: 'text-yellow-600'
  },
  { 
    name: 'Критических', 
    value: '2', 
    icon: ExclamationTriangleIcon, 
    change: '+1', 
    bgColor: 'bg-red-100',
    iconColor: 'text-red-600'
  },
]

export function DashboardStats() {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {stats.map((stat) => (
        <div key={stat.name} className="bg-white rounded-xl shadow-sm p-4 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="flex-1 min-w-0">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">{stat.name}</p>
              <p className="text-2xl font-bold text-gray-900 mt-1">{stat.value}</p>
              <p className={`text-xs mt-1 ${
                stat.change.startsWith('+') ? 'text-green-600' : 
                stat.change.startsWith('-') ? 'text-red-600' : 'text-gray-500'
              }`}>
                {stat.change} за неделю
              </p>
            </div>
            <div className={`p-2.5 rounded-lg ${stat.bgColor} flex-shrink-0`}>
              <stat.icon className={`h-5 w-5 ${stat.iconColor}`} />
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
