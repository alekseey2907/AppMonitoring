interface StatsCardProps {
  title: string;
  value: number | string;
  subtitle?: string;
  icon: string;
  color: 'blue' | 'green' | 'yellow' | 'red';
}

const colorClasses = {
  blue: 'from-blue-500/20 to-blue-600/10 border-blue-500/30',
  green: 'from-green-500/20 to-green-600/10 border-green-500/30',
  yellow: 'from-yellow-500/20 to-yellow-600/10 border-yellow-500/30',
  red: 'from-red-500/20 to-red-600/10 border-red-500/30',
};

const textColors = {
  blue: 'text-blue-400',
  green: 'text-green-400',
  yellow: 'text-yellow-400',
  red: 'text-red-400',
};

export function StatsCard({ title, value, subtitle, icon, color }: StatsCardProps) {
  return (
    <div className={`bg-gradient-to-br ${colorClasses[color]} rounded-xl p-4 border`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-gray-400 text-sm">{title}</p>
          <p className={`text-3xl font-bold mt-1 ${textColors[color]}`}>{value}</p>
          {subtitle && <p className="text-gray-500 text-sm">{subtitle}</p>}
        </div>
        <div className="text-3xl opacity-50">{icon}</div>
      </div>
    </div>
  );
}
