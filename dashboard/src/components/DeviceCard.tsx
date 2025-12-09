interface Device {
  id: string;
  name: string;
  location: string;
  status: 'online' | 'warning' | 'offline';
  health: number;
  temperature: number;
  rmsVelocity: number;
  lastUpdate: Date;
}

interface DeviceCardProps {
  device: Device;
}

const statusConfig = {
  online: { label: 'Онлайн', color: 'bg-green-500', textColor: 'text-green-400' },
  warning: { label: 'Внимание', color: 'bg-yellow-500', textColor: 'text-yellow-400' },
  offline: { label: 'Офлайн', color: 'bg-gray-500', textColor: 'text-gray-400' },
};

function getHealthColor(health: number): string {
  if (health >= 80) return 'bg-green-500';
  if (health >= 60) return 'bg-yellow-500';
  if (health >= 40) return 'bg-orange-500';
  return 'bg-red-500';
}

function formatRelativeTime(date: Date): string {
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);

  if (minutes < 1) return 'только что';
  if (minutes < 60) return `${minutes} мин. назад`;
  if (hours < 24) return `${hours} ч. назад`;
  return `${days} дн. назад`;
}

export function DeviceCard({ device }: DeviceCardProps) {
  const status = statusConfig[device.status];

  return (
    <div className="bg-gray-900 rounded-xl p-4 border border-gray-800 hover:border-gray-700 transition-colors">
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div>
          <h3 className="font-semibold">{device.name}</h3>
          <p className="text-sm text-gray-500">{device.location}</p>
        </div>
        <div className="flex items-center gap-2">
          <span className={`w-2 h-2 rounded-full ${status.color} animate-pulse`}></span>
          <span className={`text-sm ${status.textColor}`}>{status.label}</span>
        </div>
      </div>

      {/* Health Bar */}
      <div className="mb-4">
        <div className="flex justify-between text-sm mb-1">
          <span className="text-gray-400">Здоровье</span>
          <span className={device.health >= 60 ? 'text-green-400' : 'text-red-400'}>
            {device.health}%
          </span>
        </div>
        <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
          <div
            className={`h-full ${getHealthColor(device.health)} transition-all duration-500`}
            style={{ width: `${device.health}%` }}
          />
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 gap-3 text-sm">
        <div className="bg-gray-800/50 rounded-lg p-2">
          <p className="text-gray-500 text-xs">Температура</p>
          <p className={`font-mono ${device.temperature > 60 ? 'text-orange-400' : 'text-white'}`}>
            {device.temperature > 0 ? `${device.temperature.toFixed(1)}°C` : '—'}
          </p>
        </div>
        <div className="bg-gray-800/50 rounded-lg p-2">
          <p className="text-gray-500 text-xs">Вибрация</p>
          <p className={`font-mono ${device.rmsVelocity > 4.5 ? 'text-red-400' : 'text-white'}`}>
            {device.rmsVelocity > 0 ? `${device.rmsVelocity.toFixed(1)} мм/с` : '—'}
          </p>
        </div>
      </div>

      {/* Footer */}
      <div className="mt-3 pt-3 border-t border-gray-800 flex justify-between items-center">
        <span className="text-xs text-gray-500">
          Обновлено: {formatRelativeTime(device.lastUpdate)}
        </span>
        <button className="text-blue-400 text-sm hover:text-blue-300 transition-colors">
          Подробнее →
        </button>
      </div>
    </div>
  );
}
