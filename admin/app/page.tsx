import { DashboardStats } from '@/components/dashboard/DashboardStats'
import { DeviceStatusChart } from '@/components/dashboard/DeviceStatusChart'
import { RecentAlerts } from '@/components/dashboard/RecentAlerts'
import { VibrationTrendChart, TemperatureTrendChart } from '@/components/dashboard/VibrationTrendChart'

export default function DashboardPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-gray-900">Панель мониторинга</h1>
      
      {/* Stats Cards */}
      <DashboardStats />
      
      {/* Charts Row - Vibration & Temperature */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <VibrationTrendChart />
        <TemperatureTrendChart />
      </div>
      
      {/* Device Status & Alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <DeviceStatusChart />
        <RecentAlerts />
      </div>
    </div>
  )
}
