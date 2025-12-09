'use client';

import { useState, useEffect } from 'react';
import { DeviceCard } from '@/components/DeviceCard';
import { StatsCard } from '@/components/StatsCard';
import { HealthChart } from '@/components/HealthChart';
import { AlertsList } from '@/components/AlertsList';

// Демо-данные (в реальности будут с API)
const demoDevices = [
  {
    id: '1',
    name: 'Комбайн КЗС-1218',
    location: 'Поле №3',
    status: 'online' as const,
    health: 87,
    temperature: 45.2,
    rmsVelocity: 2.1,
    lastUpdate: new Date(),
  },
  {
    id: '2',
    name: 'Трактор МТЗ-82',
    location: 'Ангар',
    status: 'warning' as const,
    health: 62,
    temperature: 68.5,
    rmsVelocity: 5.8,
    lastUpdate: new Date(Date.now() - 300000),
  },
  {
    id: '3',
    name: 'Насосная станция',
    location: 'Склад ГСМ',
    status: 'offline' as const,
    health: 45,
    temperature: 0,
    rmsVelocity: 0,
    lastUpdate: new Date(Date.now() - 86400000),
  },
];

const demoAlerts = [
  {
    id: '1',
    deviceName: 'Трактор МТЗ-82',
    type: 'warning' as const,
    message: 'Повышенная вибрация: 5.8 мм/с (порог 4.5)',
    timestamp: new Date(Date.now() - 1800000),
  },
  {
    id: '2',
    deviceName: 'Трактор МТЗ-82',
    type: 'info' as const,
    message: 'Температура приближается к пороговой: 68.5°C',
    timestamp: new Date(Date.now() - 3600000),
  },
  {
    id: '3',
    deviceName: 'Насосная станция',
    type: 'error' as const,
    message: 'Устройство не отвечает более 24 часов',
    timestamp: new Date(Date.now() - 86400000),
  },
];

const demoHealthHistory = [
  { time: '00:00', health: 92 },
  { time: '04:00', health: 90 },
  { time: '08:00', health: 88 },
  { time: '12:00', health: 85 },
  { time: '16:00', health: 82 },
  { time: '20:00', health: 78 },
  { time: 'Сейчас', health: 75 },
];

export default function Dashboard() {
  const [devices] = useState(demoDevices);
  const [alerts] = useState(demoAlerts);
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const onlineCount = devices.filter(d => d.status === 'online').length;
  const warningCount = devices.filter(d => d.status === 'warning').length;
  const avgHealth = Math.round(devices.reduce((sum, d) => sum + d.health, 0) / devices.length);

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      {/* Header */}
      <header className="border-b border-gray-800 bg-gray-900/50 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
              <span className="text-xl">📊</span>
            </div>
            <div>
              <h1 className="text-xl font-bold">VibeMon Dashboard</h1>
              <p className="text-sm text-gray-400">Предиктивный мониторинг</p>
            </div>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-400">
              {currentTime.toLocaleDateString('ru-RU', { 
                weekday: 'long', 
                day: 'numeric', 
                month: 'long' 
              })}
            </p>
            <p className="text-2xl font-mono">
              {currentTime.toLocaleTimeString('ru-RU')}
            </p>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6 space-y-6">
        {/* Stats Row */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <StatsCard
            title="Всего устройств"
            value={devices.length}
            icon="📡"
            color="blue"
          />
          <StatsCard
            title="Онлайн"
            value={onlineCount}
            subtitle={`${Math.round(onlineCount / devices.length * 100)}%`}
            icon="✅"
            color="green"
          />
          <StatsCard
            title="Предупреждения"
            value={warningCount}
            icon="⚠️"
            color="yellow"
          />
          <StatsCard
            title="Среднее здоровье"
            value={`${avgHealth}%`}
            icon="💚"
            color={avgHealth > 70 ? 'green' : avgHealth > 50 ? 'yellow' : 'red'}
          />
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Devices List */}
          <div className="lg:col-span-2 space-y-4">
            <h2 className="text-lg font-semibold flex items-center gap-2">
              <span>🔧</span> Устройства
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {devices.map(device => (
                <DeviceCard key={device.id} device={device} />
              ))}
            </div>
          </div>

          {/* Alerts */}
          <div className="space-y-4">
            <h2 className="text-lg font-semibold flex items-center gap-2">
              <span>🔔</span> Уведомления
            </h2>
            <AlertsList alerts={alerts} />
          </div>
        </div>

        {/* Health Chart */}
        <div className="bg-gray-900 rounded-xl p-6 border border-gray-800">
          <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <span>📈</span> Тренд здоровья (Трактор МТЗ-82)
          </h2>
          <HealthChart data={demoHealthHistory} />
        </div>

        {/* Info Banner */}
        <div className="bg-gradient-to-r from-blue-900/50 to-purple-900/50 rounded-xl p-6 border border-blue-800/50">
          <div className="flex items-start gap-4">
            <div className="text-4xl">🤖</div>
            <div>
              <h3 className="text-lg font-semibold mb-2">Предиктивная аналитика</h3>
              <p className="text-gray-300 text-sm">
                Система обнаружила ухудшение состояния <strong>Трактора МТЗ-82</strong>. 
                При текущей скорости деградации прогнозируемое время до критического состояния: 
                <span className="text-yellow-400 font-bold"> ~48 часов</span>.
              </p>
              <p className="text-gray-400 text-sm mt-2">
                Рекомендация: Проверьте центровку валов и состояние муфты.
              </p>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-800 mt-12 py-6 text-center text-gray-500 text-sm">
        VibeMon © 2024 · Предиктивный мониторинг для сельхозтехники
      </footer>
    </div>
  );
}
