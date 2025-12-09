interface Alert {
  id: string;
  deviceName: string;
  type: 'info' | 'warning' | 'error';
  message: string;
  timestamp: Date;
}

interface AlertsListProps {
  alerts: Alert[];
}

const alertConfig = {
  info: { icon: 'ℹ️', bg: 'bg-blue-900/30', border: 'border-blue-800/50' },
  warning: { icon: '⚠️', bg: 'bg-yellow-900/30', border: 'border-yellow-800/50' },
  error: { icon: '🚨', bg: 'bg-red-900/30', border: 'border-red-800/50' },
};

function formatTime(date: Date): string {
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);

  if (minutes < 60) return `${minutes} мин.`;
  if (hours < 24) return `${hours} ч.`;
  return date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
}

export function AlertsList({ alerts }: AlertsListProps) {
  return (
    <div className="space-y-3">
      {alerts.map(alert => {
        const config = alertConfig[alert.type];
        return (
          <div
            key={alert.id}
            className={`${config.bg} ${config.border} border rounded-lg p-3`}
          >
            <div className="flex items-start gap-3">
              <span className="text-lg">{config.icon}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-200 truncate">
                  {alert.deviceName}
                </p>
                <p className="text-sm text-gray-400 mt-1">{alert.message}</p>
                <p className="text-xs text-gray-500 mt-2">{formatTime(alert.timestamp)}</p>
              </div>
            </div>
          </div>
        );
      })}

      {alerts.length === 0 && (
        <div className="text-center py-8 text-gray-500">
          <p className="text-3xl mb-2">✅</p>
          <p>Нет активных уведомлений</p>
        </div>
      )}
    </div>
  );
}
