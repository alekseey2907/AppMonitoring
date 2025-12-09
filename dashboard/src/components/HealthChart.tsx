'use client';

interface DataPoint {
  time: string;
  health: number;
}

interface HealthChartProps {
  data: DataPoint[];
}

export function HealthChart({ data }: HealthChartProps) {
  const maxHealth = 100;
  const minHealth = Math.min(...data.map(d => d.health)) - 10;
  const range = maxHealth - minHealth;

  // SVG dimensions
  const width = 100;
  const height = 40;
  const padding = 2;

  // Create path
  const points = data.map((d, i) => {
    const x = padding + (i / (data.length - 1)) * (width - 2 * padding);
    const y = padding + ((maxHealth - d.health) / range) * (height - 2 * padding);
    return `${x},${y}`;
  });

  const linePath = `M ${points.join(' L ')}`;
  const areaPath = `${linePath} L ${width - padding},${height - padding} L ${padding},${height - padding} Z`;

  // Determine color based on trend
  const lastValue = data[data.length - 1].health;
  const firstValue = data[0].health;
  const isDecreasing = lastValue < firstValue;
  
  const strokeColor = isDecreasing ? '#f87171' : '#4ade80';
  const fillColor = isDecreasing ? 'rgba(248, 113, 113, 0.1)' : 'rgba(74, 222, 128, 0.1)';

  return (
    <div className="space-y-4">
      {/* Chart */}
      <div className="relative h-48 bg-gray-800/50 rounded-lg p-4">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-full"
          preserveAspectRatio="none"
        >
          {/* Grid lines */}
          {[100, 80, 60, 40].map(value => {
            const y = padding + ((maxHealth - value) / range) * (height - 2 * padding);
            return (
              <line
                key={value}
                x1={padding}
                y1={y}
                x2={width - padding}
                y2={y}
                stroke="#374151"
                strokeWidth="0.2"
                strokeDasharray="1,1"
              />
            );
          })}

          {/* Area */}
          <path d={areaPath} fill={fillColor} />

          {/* Line */}
          <path
            d={linePath}
            fill="none"
            stroke={strokeColor}
            strokeWidth="0.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Points */}
          {data.map((d, i) => {
            const x = padding + (i / (data.length - 1)) * (width - 2 * padding);
            const y = padding + ((maxHealth - d.health) / range) * (height - 2 * padding);
            return (
              <circle
                key={i}
                cx={x}
                cy={y}
                r="1"
                fill={strokeColor}
                className="hover:r-2 transition-all"
              />
            );
          })}
        </svg>

        {/* Y-axis labels */}
        <div className="absolute left-0 top-0 bottom-0 w-8 flex flex-col justify-between py-4 text-xs text-gray-500">
          <span>100%</span>
          <span>80%</span>
          <span>60%</span>
        </div>
      </div>

      {/* X-axis labels */}
      <div className="flex justify-between text-xs text-gray-500 px-8">
        {data.map((d, i) => (
          <span key={i}>{d.time}</span>
        ))}
      </div>

      {/* Legend */}
      <div className="flex items-center justify-center gap-4 text-sm">
        <div className="flex items-center gap-2">
          <div className={`w-3 h-3 rounded-full ${isDecreasing ? 'bg-red-400' : 'bg-green-400'}`}></div>
          <span className="text-gray-400">
            {isDecreasing ? 'Ухудшение' : 'Стабильно'}: {firstValue}% → {lastValue}%
          </span>
        </div>
        {isDecreasing && (
          <span className="text-yellow-400">
            ⚠️ -{(firstValue - lastValue).toFixed(0)}% за период
          </span>
        )}
      </div>
    </div>
  );
}
