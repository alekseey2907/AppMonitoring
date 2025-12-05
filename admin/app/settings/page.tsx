'use client'

import { useState } from 'react'

export default function SettingsPage() {
  const [settings, setSettings] = useState({
    vibrationWarning: 2.0,
    vibrationCritical: 3.5,
    tempWarning: 60,
    tempCritical: 75,
    batteryLow: 20,
    emailNotifications: true,
    pushNotifications: true,
    smsNotifications: false,
  })

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-gray-900">Настройки</h1>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Thresholds */}
        <div className="bg-white rounded-xl shadow-sm p-4">
          <h3 className="font-semibold text-gray-900 mb-4">Пороговые значения</h3>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-600 mb-1">Вибрация — предупреждение (g)</label>
              <input
                type="number"
                step="0.1"
                value={settings.vibrationWarning}
                onChange={(e) => setSettings({ ...settings, vibrationWarning: parseFloat(e.target.value) })}
                className="w-full px-3 py-2 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-600 mb-1">Вибрация — критично (g)</label>
              <input
                type="number"
                step="0.1"
                value={settings.vibrationCritical}
                onChange={(e) => setSettings({ ...settings, vibrationCritical: parseFloat(e.target.value) })}
                className="w-full px-3 py-2 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-600 mb-1">Температура — предупреждение (°C)</label>
              <input
                type="number"
                value={settings.tempWarning}
                onChange={(e) => setSettings({ ...settings, tempWarning: parseInt(e.target.value) })}
                className="w-full px-3 py-2 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-600 mb-1">Температура — критично (°C)</label>
              <input
                type="number"
                value={settings.tempCritical}
                onChange={(e) => setSettings({ ...settings, tempCritical: parseInt(e.target.value) })}
                className="w-full px-3 py-2 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-600 mb-1">Низкий заряд батареи (%)</label>
              <input
                type="number"
                value={settings.batteryLow}
                onChange={(e) => setSettings({ ...settings, batteryLow: parseInt(e.target.value) })}
                className="w-full px-3 py-2 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        {/* Notifications */}
        <div className="bg-white rounded-xl shadow-sm p-4">
          <h3 className="font-semibold text-gray-900 mb-4">Уведомления</h3>
          
          <div className="space-y-3">
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm text-gray-700">Email уведомления</span>
              <input
                type="checkbox"
                checked={settings.emailNotifications}
                onChange={(e) => setSettings({ ...settings, emailNotifications: e.target.checked })}
                className="w-5 h-5 text-blue-600 rounded focus:ring-blue-500"
              />
            </label>
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm text-gray-700">Push уведомления</span>
              <input
                type="checkbox"
                checked={settings.pushNotifications}
                onChange={(e) => setSettings({ ...settings, pushNotifications: e.target.checked })}
                className="w-5 h-5 text-blue-600 rounded focus:ring-blue-500"
              />
            </label>
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm text-gray-700">SMS уведомления</span>
              <input
                type="checkbox"
                checked={settings.smsNotifications}
                onChange={(e) => setSettings({ ...settings, smsNotifications: e.target.checked })}
                className="w-5 h-5 text-blue-600 rounded focus:ring-blue-500"
              />
            </label>
          </div>

          <div className="mt-6 pt-4 border-t">
            <h4 className="font-medium text-gray-900 mb-2">Системная информация</h4>
            <div className="space-y-1 text-sm text-gray-600">
              <p>Версия API: <span className="text-gray-900">1.0.0</span></p>
              <p>База данных: <span className="text-gray-900">TimescaleDB 15</span></p>
              <p>Устройств подключено: <span className="text-gray-900">128</span></p>
            </div>
          </div>
        </div>
      </div>

      <div className="flex justify-end">
        <button className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700">
          Сохранить настройки
        </button>
      </div>
    </div>
  )
}
