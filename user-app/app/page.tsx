'use client'

import { useState, useEffect, useCallback } from 'react'
import { 
  Thermometer, Activity, AlertTriangle, 
  Bell, User, Clock, MapPin, Wifi, WifiOff,
  Bluetooth, BluetoothConnected, BluetoothOff, BluetoothSearching,
  RefreshCw, X
} from 'lucide-react'
import { LineChart, Line, XAxis, YAxis, ResponsiveContainer, Tooltip } from 'recharts'

// BLE UUIDs для ESP32 (стандартные для VibeMon)
const VIBEMON_SERVICE_UUID = '12345678-1234-5678-1234-56789abcdef0'
const TEMP_CHARACTERISTIC_UUID = '12345678-1234-5678-1234-56789abcdef1'
const VIBRATION_CHARACTERISTIC_UUID = '12345678-1234-5678-1234-56789abcdef2'

// Типы для Web Bluetooth
interface BluetoothDevice {
  id: string
  name: string | undefined
  gatt?: BluetoothRemoteGATTServer
}

interface BLEData {
  temperature: number
  vibration: number
  timestamp: Date
}

// Симуляция данных устройств
const generateDeviceData = () => [
  { 
    id: 1, 
    name: 'Трактор МТЗ-82 #1', 
    location: 'Поле №3',
    status: 'online',
    temp: 42 + Math.random() * 8,
    vibration: 1.0 + Math.random() * 0.5,
    lastUpdate: new Date()
  },
  { 
    id: 2, 
    name: 'Элеватор мотор #3', 
    location: 'Склад зерна',
    status: Math.random() > 0.3 ? 'warning' : 'online',
    temp: 58 + Math.random() * 15,
    vibration: 2.2 + Math.random() * 1.0,
    lastUpdate: new Date()
  },
  { 
    id: 3, 
    name: 'Насос датчик #7', 
    location: 'Насосная станция',
    status: 'online',
    temp: 35 + Math.random() * 5,
    vibration: 0.6 + Math.random() * 0.3,
    lastUpdate: new Date()
  },
  { 
    id: 4, 
    name: 'Комбайн John Deere #12', 
    location: 'Поле №7',
    status: Math.random() > 0.7 ? 'critical' : 'warning',
    temp: 70 + Math.random() * 15,
    vibration: 3.5 + Math.random() * 2.0,
    lastUpdate: new Date()
  },
  { 
    id: 5, 
    name: 'Генератор #5', 
    location: 'Ферма',
    status: 'offline',
    temp: 0,
    vibration: 0,
    lastUpdate: new Date(Date.now() - 3600000)
  },
]

const generateChartData = () => {
  const data = []
  const now = new Date()
  for (let i = 23; i >= 0; i--) {
    data.push({
      time: `${(now.getHours() - i + 24) % 24}:00`,
      temp: 45 + Math.random() * 20,
      vibration: 1.5 + Math.random() * 1.5
    })
  }
  return data
}

export default function UserDashboard() {
  const [devices, setDevices] = useState(generateDeviceData())
  const [chartData, setChartData] = useState(generateChartData())
  const [selectedDevice, setSelectedDevice] = useState<number | null>(null)
  const [showAlerts, setShowAlerts] = useState(false)
  const [alerts] = useState([
    { id: 1, device: 'Комбайн John Deere #12', message: 'Критическая температура: 82°C', time: '2 мин назад', level: 'critical' },
    { id: 2, device: 'Элеватор мотор #3', message: 'Повышенная вибрация: 3.1g', time: '15 мин назад', level: 'warning' },
    { id: 3, device: 'Трактор МТЗ-82 #1', message: 'Температура нормализована', time: '1 час назад', level: 'info' },
  ])

  // BLE State
  const [bleSupported, setBleSupported] = useState(false)
  const [bleDevice, setBleDevice] = useState<BluetoothDevice | null>(null)
  const [bleConnecting, setBleConnecting] = useState(false)
  const [bleConnected, setBleConnected] = useState(false)
  const [bleData, setBleData] = useState<BLEData | null>(null)
  const [bleHistory, setBleHistory] = useState<BLEData[]>([])
  const [bleError, setBleError] = useState<string | null>(null)
  const [showBleModal, setShowBleModal] = useState(false)

  // Check BLE support
  useEffect(() => {
    if (typeof navigator !== 'undefined' && 'bluetooth' in navigator) {
      setBleSupported(true)
    }
  }, [])

  // Connect to BLE device
  const connectBLE = useCallback(async () => {
    if (!bleSupported) {
      setBleError('Web Bluetooth не поддерживается в этом браузере. Используйте Chrome.')
      return
    }

    setBleConnecting(true)
    setBleError(null)

    try {
      // Request device
      const device = await (navigator as any).bluetooth.requestDevice({
        filters: [
          { namePrefix: 'VibeMon' },
          { namePrefix: 'ESP32' },
          { services: [VIBEMON_SERVICE_UUID] }
        ],
        optionalServices: [VIBEMON_SERVICE_UUID]
      })

      console.log('Device found:', device.name)
      setBleDevice(device)

      // Connect to GATT server
      const server = await device.gatt?.connect()
      if (!server) throw new Error('Не удалось подключиться к устройству')

      console.log('Connected to GATT server')
      setBleConnected(true)

      // Get service
      const service = await server.getPrimaryService(VIBEMON_SERVICE_UUID)
      console.log('Service found')

      // Get characteristics
      const tempChar = await service.getCharacteristic(TEMP_CHARACTERISTIC_UUID)
      const vibChar = await service.getCharacteristic(VIBRATION_CHARACTERISTIC_UUID)

      // Start notifications
      await tempChar.startNotifications()
      await vibChar.startNotifications()

      // Listen for temperature changes
      tempChar.addEventListener('characteristicvaluechanged', (event: any) => {
        const value = event.target.value
        const temp = value.getFloat32(0, true)
        setBleData(prev => ({
          temperature: temp,
          vibration: prev?.vibration || 0,
          timestamp: new Date()
        }))
      })

      // Listen for vibration changes
      vibChar.addEventListener('characteristicvaluechanged', (event: any) => {
        const value = event.target.value
        const vib = value.getFloat32(0, true)
        setBleData(prev => ({
          temperature: prev?.temperature || 0,
          vibration: vib,
          timestamp: new Date()
        }))
      })

      // Handle disconnection
      device.addEventListener('gattserverdisconnected', () => {
        console.log('Device disconnected')
        setBleConnected(false)
        setBleDevice(null)
      })

    } catch (error: any) {
      console.error('BLE Error:', error)
      if (error.name === 'NotFoundError') {
        setBleError('Устройство не найдено. Убедитесь, что ESP32 включена и рядом.')
      } else if (error.name === 'SecurityError') {
        setBleError('Доступ к Bluetooth заблокирован. Разрешите доступ в настройках браузера.')
      } else {
        setBleError(error.message || 'Ошибка подключения к устройству')
      }
      setBleConnected(false)
    } finally {
      setBleConnecting(false)
    }
  }, [bleSupported])

  // Disconnect BLE
  const disconnectBLE = useCallback(() => {
    if (bleDevice?.gatt?.connected) {
      bleDevice.gatt.disconnect()
    }
    setBleDevice(null)
    setBleConnected(false)
    setBleData(null)
  }, [bleDevice])

  // Update BLE history
  useEffect(() => {
    if (bleData) {
      setBleHistory(prev => {
        const newHistory = [...prev, bleData].slice(-100)
        return newHistory
      })
    }
  }, [bleData])

  // Update simulated devices
  useEffect(() => {
    const interval = setInterval(() => {
      setDevices(generateDeviceData())
    }, 5000)
    return () => clearInterval(interval)
  }, [])

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online': return 'bg-green-500'
      case 'warning': return 'bg-yellow-500'
      case 'critical': return 'bg-red-500'
      default: return 'bg-gray-400'
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'online': return 'Норма'
      case 'warning': return 'Внимание'
      case 'critical': return 'Критично'
      default: return 'Оффлайн'
    }
  }

  const getTempStatus = (temp: number) => {
    if (temp === 0) return 'gray'
    if (temp < 50) return 'green'
    if (temp < 70) return 'yellow'
    return 'red'
  }

  const getVibrationStatus = (vib: number) => {
    if (vib === 0) return 'gray'
    if (vib < 2) return 'green'
    if (vib < 3.5) return 'yellow'
    return 'red'
  }

  const onlineCount = devices.filter(d => d.status !== 'offline').length
  const warningCount = devices.filter(d => d.status === 'warning').length
  const criticalCount = devices.filter(d => d.status === 'critical').length

  // BLE chart data
  const bleChartData = bleHistory.slice(-24).map((d, i) => ({
    time: d.timestamp.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
    temp: d.temperature,
    vibration: d.vibration
  }))

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-blue-600 text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-white rounded-full flex items-center justify-center">
                <Activity className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <h1 className="text-xl font-bold">VibeMon</h1>
                <p className="text-blue-200 text-sm">Мониторинг оборудования</p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              {/* BLE Button */}
              <button 
                onClick={() => setShowBleModal(true)}
                className={`p-2 rounded-full transition flex items-center gap-2 ${
                  bleConnected ? 'bg-green-500 hover:bg-green-600' : 'hover:bg-blue-700'
                }`}
                title="Подключить ESP32 по Bluetooth"
              >
                {bleConnecting ? (
                  <BluetoothSearching className="w-6 h-6 animate-pulse" />
                ) : bleConnected ? (
                  <BluetoothConnected className="w-6 h-6" />
                ) : (
                  <Bluetooth className="w-6 h-6" />
                )}
                {bleConnected && <span className="text-sm hidden md:inline">ESP32</span>}
              </button>

              <button 
                onClick={() => setShowAlerts(!showAlerts)}
                className="relative p-2 hover:bg-blue-700 rounded-full transition"
              >
                <Bell className="w-6 h-6" />
                {criticalCount > 0 && (
                  <span className="absolute -top-1 -right-1 bg-red-500 text-xs w-5 h-5 rounded-full flex items-center justify-center">
                    {criticalCount}
                  </span>
                )}
              </button>
              <div className="flex items-center gap-2 bg-blue-700 px-3 py-2 rounded-lg">
                <User className="w-5 h-5" />
                <span className="text-sm">Оператор</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* BLE Modal */}
      {showBleModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold flex items-center gap-2">
                <Bluetooth className="w-6 h-6 text-blue-600" />
                Подключение ESP32
              </h2>
              <button onClick={() => setShowBleModal(false)} className="p-1 hover:bg-gray-100 rounded-full">
                <X className="w-6 h-6" />
              </button>
            </div>

            {!bleSupported ? (
              <div className="text-center py-8">
                <BluetoothOff className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-600 mb-2">Web Bluetooth не поддерживается</p>
                <p className="text-sm text-gray-500">Используйте Google Chrome или Microsoft Edge</p>
              </div>
            ) : bleConnected ? (
              <div className="space-y-4">
                <div className="bg-green-50 border border-green-200 rounded-xl p-4">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                      <BluetoothConnected className="w-6 h-6 text-green-600" />
                    </div>
                    <div>
                      <p className="font-semibold text-green-800">Подключено</p>
                      <p className="text-sm text-green-600">{bleDevice?.name || 'ESP32 Device'}</p>
                    </div>
                  </div>
                </div>

                {bleData && (
                  <div className="grid grid-cols-2 gap-4">
                    <div className="bg-red-50 rounded-xl p-4 text-center">
                      <Thermometer className="w-8 h-8 text-red-500 mx-auto mb-2" />
                      <p className="text-2xl font-bold text-red-600">{bleData.temperature.toFixed(1)}°C</p>
                      <p className="text-sm text-gray-500">Температура</p>
                    </div>
                    <div className="bg-blue-50 rounded-xl p-4 text-center">
                      <Activity className="w-8 h-8 text-blue-500 mx-auto mb-2" />
                      <p className="text-2xl font-bold text-blue-600">{bleData.vibration.toFixed(2)}g</p>
                      <p className="text-sm text-gray-500">Вибрация</p>
                    </div>
                  </div>
                )}

                <button
                  onClick={disconnectBLE}
                  className="w-full py-3 bg-red-100 text-red-600 rounded-xl font-medium hover:bg-red-200 transition"
                >
                  Отключить
                </button>
              </div>
            ) : (
              <div className="space-y-4">
                <div className="bg-blue-50 rounded-xl p-4">
                  <p className="text-sm text-gray-600 mb-3">
                    Нажмите кнопку ниже, чтобы найти и подключить ESP32 датчик поблизости.
                  </p>
                  <ul className="text-sm text-gray-500 space-y-1">
                    <li>• Убедитесь, что ESP32 включена</li>
                    <li>• Bluetooth на компьютере включён</li>
                    <li>• Датчик находится рядом (до 10м)</li>
                  </ul>
                </div>

                {bleError && (
                  <div className="bg-red-50 border border-red-200 rounded-xl p-3">
                    <p className="text-sm text-red-600">{bleError}</p>
                  </div>
                )}

                <button
                  onClick={connectBLE}
                  disabled={bleConnecting}
                  className="w-full py-3 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700 transition disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {bleConnecting ? (
                    <>
                      <RefreshCw className="w-5 h-5 animate-spin" />
                      Поиск устройства...
                    </>
                  ) : (
                    <>
                      <BluetoothSearching className="w-5 h-5" />
                      Найти ESP32
                    </>
                  )}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Alerts Panel */}
      {showAlerts && (
        <div className="bg-white border-b shadow-lg">
          <div className="max-w-7xl mx-auto px-4 py-4">
            <h3 className="font-semibold mb-3 flex items-center gap-2">
              <AlertTriangle className="w-5 h-5 text-yellow-500" />
              Последние уведомления
            </h3>
            <div className="space-y-2">
              {alerts.map(alert => (
                <div 
                  key={alert.id}
                  className={`p-3 rounded-lg flex items-center justify-between ${
                    alert.level === 'critical' ? 'bg-red-50 border-l-4 border-red-500' :
                    alert.level === 'warning' ? 'bg-yellow-50 border-l-4 border-yellow-500' :
                    'bg-blue-50 border-l-4 border-blue-500'
                  }`}
                >
                  <div>
                    <p className="font-medium">{alert.device}</p>
                    <p className="text-sm text-gray-600">{alert.message}</p>
                  </div>
                  <span className="text-xs text-gray-500">{alert.time}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <main className="max-w-7xl mx-auto px-4 py-6">
        {/* BLE Live Data Card */}
        {bleConnected && bleData && (
          <div className="bg-gradient-to-r from-blue-600 to-purple-600 rounded-xl p-4 mb-6 text-white shadow-lg">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <BluetoothConnected className="w-5 h-5" />
                <span className="font-semibold">Данные с ESP32 в реальном времени</span>
              </div>
              <span className="text-sm opacity-75">
                {bleData.timestamp.toLocaleTimeString('ru-RU')}
              </span>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-white/20 rounded-lg p-4 text-center">
                <Thermometer className="w-8 h-8 mx-auto mb-2" />
                <p className="text-3xl font-bold">{bleData.temperature.toFixed(1)}°C</p>
                <p className="text-sm opacity-75">Температура</p>
              </div>
              <div className="bg-white/20 rounded-lg p-4 text-center">
                <Activity className="w-8 h-8 mx-auto mb-2" />
                <p className="text-3xl font-bold">{bleData.vibration.toFixed(2)}g</p>
                <p className="text-sm opacity-75">Вибрация</p>
              </div>
            </div>

            {/* BLE History Chart */}
            {bleChartData.length > 1 && (
              <div className="mt-4 bg-white/10 rounded-lg p-3">
                <p className="text-sm mb-2">История показаний</p>
                <div className="h-32">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={bleChartData}>
                      <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'white' }} />
                      <YAxis tick={{ fontSize: 10, fill: 'white' }} />
                      <Tooltip 
                        contentStyle={{ backgroundColor: '#1e40af', border: 'none', borderRadius: 8 }}
                        labelStyle={{ color: 'white' }}
                      />
                      <Line type="monotone" dataKey="temp" stroke="#fca5a5" strokeWidth={2} dot={false} />
                      <Line type="monotone" dataKey="vibration" stroke="#93c5fd" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div className="bg-white rounded-xl p-4 shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Всего устройств</p>
                <p className="text-2xl font-bold">{devices.length}</p>
              </div>
              <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                <Activity className="w-6 h-6 text-blue-600" />
              </div>
            </div>
          </div>
          <div className="bg-white rounded-xl p-4 shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Онлайн</p>
                <p className="text-2xl font-bold text-green-600">{onlineCount}</p>
              </div>
              <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                <Wifi className="w-6 h-6 text-green-600" />
              </div>
            </div>
          </div>
          <div className="bg-white rounded-xl p-4 shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Внимание</p>
                <p className="text-2xl font-bold text-yellow-600">{warningCount}</p>
              </div>
              <div className="w-12 h-12 bg-yellow-100 rounded-full flex items-center justify-center">
                <AlertTriangle className="w-6 h-6 text-yellow-600" />
              </div>
            </div>
          </div>
          <div className="bg-white rounded-xl p-4 shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Критично</p>
                <p className="text-2xl font-bold text-red-600">{criticalCount}</p>
              </div>
              <div className="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
                <AlertTriangle className="w-6 h-6 text-red-600" />
              </div>
            </div>
          </div>
        </div>

        {/* Charts */}
        <div className="grid md:grid-cols-2 gap-4 mb-6">
          <div className="bg-white rounded-xl p-4 shadow">
            <h3 className="font-semibold mb-4 flex items-center gap-2">
              <Thermometer className="w-5 h-5 text-red-500" />
              Температура за 24 часа
            </h3>
            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <XAxis dataKey="time" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} domain={['auto', 'auto']} />
                  <Tooltip formatter={(value: number) => [`${value.toFixed(1)}°C`, 'Температура']} />
                  <Line 
                    type="monotone" 
                    dataKey="temp" 
                    stroke="#ef4444" 
                    strokeWidth={2}
                    dot={false}
                    name="Температура"
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
            <div className="flex justify-between mt-2 text-sm text-gray-500">
              <span>Мин: {Math.min(...chartData.map(d => d.temp)).toFixed(1)}°C</span>
              <span>Макс: {Math.max(...chartData.map(d => d.temp)).toFixed(1)}°C</span>
            </div>
          </div>

          <div className="bg-white rounded-xl p-4 shadow">
            <h3 className="font-semibold mb-4 flex items-center gap-2">
              <Activity className="w-5 h-5 text-blue-500" />
              Вибрация за 24 часа
            </h3>
            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <XAxis dataKey="time" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} domain={['auto', 'auto']} />
                  <Tooltip formatter={(value: number) => [`${value.toFixed(2)}g`, 'Вибрация']} />
                  <Line 
                    type="monotone" 
                    dataKey="vibration" 
                    stroke="#3b82f6" 
                    strokeWidth={2}
                    dot={false}
                    name="Вибрация"
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
            <div className="flex justify-between mt-2 text-sm text-gray-500">
              <span>Мин: {Math.min(...chartData.map(d => d.vibration)).toFixed(2)}g</span>
              <span>Макс: {Math.max(...chartData.map(d => d.vibration)).toFixed(2)}g</span>
            </div>
          </div>
        </div>

        {/* Devices List */}
        <div className="bg-white rounded-xl shadow">
          <div className="p-4 border-b">
            <h3 className="font-semibold">Мои устройства</h3>
          </div>
          <div className="divide-y">
            {devices.map(device => (
              <div 
                key={device.id}
                className={`p-4 hover:bg-gray-50 cursor-pointer transition ${
                  selectedDevice === device.id ? 'bg-blue-50' : ''
                }`}
                onClick={() => setSelectedDevice(selectedDevice === device.id ? null : device.id)}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className={`w-3 h-3 rounded-full ${getStatusColor(device.status)}`}></div>
                    <div>
                      <p className="font-medium">{device.name}</p>
                      <div className="flex items-center gap-2 text-sm text-gray-500">
                        <MapPin className="w-3 h-3" />
                        {device.location}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    {device.status !== 'offline' ? (
                      <>
                        <div className={`flex items-center gap-1 px-2 py-1 rounded ${
                          getTempStatus(device.temp) === 'green' ? 'bg-green-100 text-green-700' :
                          getTempStatus(device.temp) === 'yellow' ? 'bg-yellow-100 text-yellow-700' :
                          'bg-red-100 text-red-700'
                        }`}>
                          <Thermometer className="w-4 h-4" />
                          <span className="text-sm font-medium">{device.temp.toFixed(1)}°C</span>
                        </div>
                        <div className={`flex items-center gap-1 px-2 py-1 rounded ${
                          getVibrationStatus(device.vibration) === 'green' ? 'bg-green-100 text-green-700' :
                          getVibrationStatus(device.vibration) === 'yellow' ? 'bg-yellow-100 text-yellow-700' :
                          'bg-red-100 text-red-700'
                        }`}>
                          <Activity className="w-4 h-4" />
                          <span className="text-sm font-medium">{device.vibration.toFixed(2)}g</span>
                        </div>
                      </>
                    ) : (
                      <div className="flex items-center gap-1 px-2 py-1 rounded bg-gray-100 text-gray-500">
                        <WifiOff className="w-4 h-4" />
                        <span className="text-sm">Нет связи</span>
                      </div>
                    )}
                    <span className={`px-2 py-1 rounded text-xs font-medium ${
                      device.status === 'online' ? 'bg-green-100 text-green-700' :
                      device.status === 'warning' ? 'bg-yellow-100 text-yellow-700' :
                      device.status === 'critical' ? 'bg-red-100 text-red-700' :
                      'bg-gray-100 text-gray-500'
                    }`}>
                      {getStatusText(device.status)}
                    </span>
                  </div>
                </div>

                {/* Expanded Details */}
                {selectedDevice === device.id && device.status !== 'offline' && (
                  <div className="mt-4 pt-4 border-t grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div className="text-center p-3 bg-gray-50 rounded-lg">
                      <p className="text-xs text-gray-500">Мин. температура</p>
                      <p className="text-lg font-semibold text-blue-600">{(device.temp - 10).toFixed(1)}°C</p>
                    </div>
                    <div className="text-center p-3 bg-gray-50 rounded-lg">
                      <p className="text-xs text-gray-500">Макс. температура</p>
                      <p className="text-lg font-semibold text-red-600">{(device.temp + 5).toFixed(1)}°C</p>
                    </div>
                    <div className="text-center p-3 bg-gray-50 rounded-lg">
                      <p className="text-xs text-gray-500">Ср. вибрация</p>
                      <p className="text-lg font-semibold text-purple-600">{device.vibration.toFixed(2)}g</p>
                    </div>
                    <div className="text-center p-3 bg-gray-50 rounded-lg">
                      <p className="text-xs text-gray-500">Обновлено</p>
                      <p className="text-lg font-semibold text-gray-600">
                        {device.lastUpdate.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}
                      </p>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <div className="mt-6 text-center text-gray-500 text-sm">
          <p>VibeMon v1.0 • Данные обновляются каждые 5 секунд</p>
          <p className="flex items-center justify-center gap-1 mt-1">
            <Clock className="w-4 h-4" />
            {new Date().toLocaleString('ru-RU')}
          </p>
        </div>
      </main>
    </div>
  )
}
