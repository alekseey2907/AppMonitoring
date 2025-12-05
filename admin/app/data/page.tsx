'use client'

import { useState, useRef } from 'react'
import { 
  ArrowDownTrayIcon, 
  ArrowUpTrayIcon, 
  DocumentTextIcon,
  TrashIcon,
  EyeIcon,
  ChartBarIcon,
  TableCellsIcon,
  CalendarIcon,
  ClockIcon
} from '@heroicons/react/24/outline'
import dynamic from 'next/dynamic'

const DataChart = dynamic(() => import('@/components/data/DataChart'), {
  ssr: false,
  loading: () => <div className="h-64 flex items-center justify-center text-gray-400">Загрузка графика...</div>
})

// Типы данных
interface TemperatureRecord {
  timestamp: string
  deviceId: string
  deviceName: string
  temperature: number
  vibration: number
}

interface ExportHistory {
  id: string
  filename: string
  format: 'csv' | 'json'
  recordCount: number
  exportedAt: string
  size: string
}

// Статические демо-данные температуры (фиксированные для избежания hydration mismatch)
const demoData: TemperatureRecord[] = [
  { timestamp: '2025-12-05T13:00:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 50.7, vibration: 4.18 },
  { timestamp: '2025-12-05T12:45:00Z', deviceId: 'VBM-2024-002', deviceName: 'Элеватор мотор #3', temperature: 46, vibration: 2.48 },
  { timestamp: '2025-12-05T12:30:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 60, vibration: 2.32 },
  { timestamp: '2025-12-05T12:15:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 48.1, vibration: 3.16 },
  { timestamp: '2025-12-05T12:00:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 59.3, vibration: 1.13 },
  { timestamp: '2025-12-05T11:45:00Z', deviceId: 'VBM-2024-002', deviceName: 'Элеватор мотор #3', temperature: 47.9, vibration: 0.79 },
  { timestamp: '2025-12-05T11:30:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 68.9, vibration: 0.76 },
  { timestamp: '2025-12-05T11:15:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 76.1, vibration: 3.12 },
  { timestamp: '2025-12-05T11:00:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 67.9, vibration: 1.43 },
  { timestamp: '2025-12-05T10:45:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 54, vibration: 4.01 },
  { timestamp: '2025-12-05T10:30:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 44.5, vibration: 3.07 },
  { timestamp: '2025-12-05T10:15:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 56.3, vibration: 4.14 },
  { timestamp: '2025-12-05T10:00:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 45.7, vibration: 2.87 },
  { timestamp: '2025-12-05T09:45:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 79.3, vibration: 2.47 },
  { timestamp: '2025-12-05T09:30:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 74.2, vibration: 3.19 },
  { timestamp: '2025-12-05T09:15:00Z', deviceId: 'VBM-2024-002', deviceName: 'Элеватор мотор #3', temperature: 52.1, vibration: 1.55 },
  { timestamp: '2025-12-05T09:00:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 63.8, vibration: 2.91 },
  { timestamp: '2025-12-05T08:45:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 41.2, vibration: 1.82 },
  { timestamp: '2025-12-05T08:30:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 58.4, vibration: 3.45 },
  { timestamp: '2025-12-05T08:15:00Z', deviceId: 'VBM-2024-002', deviceName: 'Элеватор мотор #3', temperature: 49.6, vibration: 2.18 },
  { timestamp: '2025-12-05T08:00:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 71.5, vibration: 3.67 },
  { timestamp: '2025-12-05T07:45:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 38.9, vibration: 0.92 },
  { timestamp: '2025-12-05T07:30:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 55.2, vibration: 2.74 },
  { timestamp: '2025-12-05T07:15:00Z', deviceId: 'VBM-2024-002', deviceName: 'Элеватор мотор #3', temperature: 43.7, vibration: 1.39 },
  { timestamp: '2025-12-05T07:00:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 66.4, vibration: 4.21 },
  { timestamp: '2025-12-05T06:45:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 47.8, vibration: 1.67 },
  { timestamp: '2025-12-05T06:30:00Z', deviceId: 'VBM-2024-003', deviceName: 'Насос датчик #7', temperature: 62.1, vibration: 2.53 },
  { timestamp: '2025-12-05T06:15:00Z', deviceId: 'VBM-2024-002', deviceName: 'Элеватор мотор #3', temperature: 51.9, vibration: 3.88 },
  { timestamp: '2025-12-05T06:00:00Z', deviceId: 'VBM-2024-004', deviceName: 'Комбайн #12', temperature: 39.4, vibration: 0.68 },
  { timestamp: '2025-12-05T05:45:00Z', deviceId: 'VBM-2024-001', deviceName: 'Трактор МТЗ-82 #1', temperature: 73.6, vibration: 2.95 },
]

// История экспортов (localStorage)
const getExportHistory = (): ExportHistory[] => {
  if (typeof window === 'undefined') return []
  const saved = localStorage.getItem('vibemon_export_history')
  return saved ? JSON.parse(saved) : []
}

const saveExportHistory = (history: ExportHistory[]) => {
  localStorage.setItem('vibemon_export_history', JSON.stringify(history))
}

export default function DataPage() {
  const [data] = useState<TemperatureRecord[]>(demoData)
  const [importedData, setImportedData] = useState<TemperatureRecord[]>([])
  const [exportHistory, setExportHistory] = useState<ExportHistory[]>([])
  const [viewMode, setViewMode] = useState<'table' | 'chart'>('table')
  const [activeTab, setActiveTab] = useState<'current' | 'imported' | 'history'>('current')
  const [selectedRecords, setSelectedRecords] = useState<Set<number>>(new Set())
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Загрузка истории при монтировании
  useState(() => {
    setExportHistory(getExportHistory())
  })

  const displayData = activeTab === 'imported' ? importedData : data

  // Экспорт в CSV
  const exportToCSV = () => {
    const headers = ['Дата и время', 'ID устройства', 'Устройство', 'Температура (°C)', 'Вибрация (g)']
    const rows = displayData.map(r => [
      new Date(r.timestamp).toLocaleString('ru-RU'),
      r.deviceId,
      r.deviceName,
      r.temperature,
      r.vibration
    ])
    
    const csvContent = [
      headers.join(';'),
      ...rows.map(row => row.join(';'))
    ].join('\n')
    
    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' })
    const filename = `vibemon_data_${new Date().toISOString().split('T')[0]}.csv`
    downloadFile(blob, filename)
    
    addToHistory(filename, 'csv', displayData.length, blob.size)
  }

  // Экспорт в JSON
  const exportToJSON = () => {
    const exportData = {
      exportedAt: new Date().toISOString(),
      recordCount: displayData.length,
      data: displayData
    }
    
    const jsonContent = JSON.stringify(exportData, null, 2)
    const blob = new Blob([jsonContent], { type: 'application/json' })
    const filename = `vibemon_data_${new Date().toISOString().split('T')[0]}.json`
    downloadFile(blob, filename)
    
    addToHistory(filename, 'json', displayData.length, blob.size)
  }

  const downloadFile = (blob: Blob, filename: string) => {
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  const addToHistory = (filename: string, format: 'csv' | 'json', recordCount: number, size: number) => {
    const newEntry: ExportHistory = {
      id: Date.now().toString(),
      filename,
      format,
      recordCount,
      exportedAt: new Date().toISOString(),
      size: formatFileSize(size)
    }
    const newHistory = [newEntry, ...exportHistory].slice(0, 20) // Храним последние 20
    setExportHistory(newHistory)
    saveExportHistory(newHistory)
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
  }

  // Импорт файла
  const handleImport = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      const content = e.target?.result as string
      
      try {
        if (file.name.endsWith('.json')) {
          const parsed = JSON.parse(content)
          const records = parsed.data || parsed
          if (Array.isArray(records)) {
            setImportedData(records)
            setActiveTab('imported')
          }
        } else if (file.name.endsWith('.csv')) {
          const lines = content.split('\n').filter(l => l.trim())
          const records: TemperatureRecord[] = []
          
          for (let i = 1; i < lines.length; i++) {
            const cols = lines[i].split(';')
            if (cols.length >= 5) {
              // Парсим дату формата "05.12.2025, 16:00:00"
              const dateTimeStr = cols[0].trim()
              let timestamp: string
              
              try {
                // Формат: DD.MM.YYYY, HH:MM:SS
                const [datePart, timePart] = dateTimeStr.split(', ')
                if (datePart && timePart) {
                  const [day, month, year] = datePart.split('.')
                  const [hours, minutes, seconds] = timePart.split(':')
                  timestamp = new Date(
                    parseInt(year), 
                    parseInt(month) - 1, 
                    parseInt(day),
                    parseInt(hours),
                    parseInt(minutes),
                    parseInt(seconds || '0')
                  ).toISOString()
                } else {
                  // Попробуем прямой парсинг
                  timestamp = new Date(dateTimeStr).toISOString()
                }
              } catch {
                timestamp = new Date().toISOString()
              }
              
              records.push({
                timestamp,
                deviceId: cols[1]?.trim() || '',
                deviceName: cols[2]?.trim() || '',
                temperature: parseFloat(cols[3]) || 0,
                vibration: parseFloat(cols[4]) || 0
              })
            }
          }
          
          if (records.length > 0) {
            setImportedData(records)
            setActiveTab('imported')
          } else {
            alert('Не удалось найти данные в файле. Проверьте формат CSV.')
          }
        }
      } catch (err) {
        alert('Ошибка при чтении файла. Проверьте формат.')
        console.error(err)
      }
    }
    
    reader.readAsText(file)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const clearHistory = () => {
    setExportHistory([])
    saveExportHistory([])
  }

  const deleteHistoryItem = (id: string) => {
    const newHistory = exportHistory.filter(h => h.id !== id)
    setExportHistory(newHistory)
    saveExportHistory(newHistory)
  }

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold text-gray-900">📊 Данные мониторинга</h1>
          <p className="text-sm text-gray-500">Температура и вибрация — экспорт и импорт данных</p>
        </div>
        
        <div className="flex flex-wrap gap-2">
          {/* Импорт */}
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv,.json"
            onChange={handleImport}
            className="hidden"
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            className="flex items-center gap-2 px-3 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition"
          >
            <ArrowUpTrayIcon className="h-4 w-4" />
            Импорт
          </button>
          
          {/* Экспорт */}
          <button
            onClick={exportToCSV}
            className="flex items-center gap-2 px-3 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 transition"
          >
            <ArrowDownTrayIcon className="h-4 w-4" />
            CSV
          </button>
          <button
            onClick={exportToJSON}
            className="flex items-center gap-2 px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 transition"
          >
            <ArrowDownTrayIcon className="h-4 w-4" />
            JSON
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-lg w-fit">
        <button
          onClick={() => setActiveTab('current')}
          className={`px-4 py-2 text-sm rounded-md transition ${
            activeTab === 'current' ? 'bg-white shadow text-gray-900' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          Текущие данные ({data.length})
        </button>
        <button
          onClick={() => setActiveTab('imported')}
          className={`px-4 py-2 text-sm rounded-md transition ${
            activeTab === 'imported' ? 'bg-white shadow text-gray-900' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          Импортированные ({importedData.length})
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={`px-4 py-2 text-sm rounded-md transition ${
            activeTab === 'history' ? 'bg-white shadow text-gray-900' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          История экспорта
        </button>
      </div>

      {activeTab !== 'history' ? (
        <>
          {/* View Mode Toggle */}
          <div className="flex items-center justify-between">
            <p className="text-sm text-gray-500">
              Показано записей: {displayData.length}
            </p>
            <div className="flex gap-1 bg-gray-100 p-1 rounded-lg">
              <button
                onClick={() => setViewMode('table')}
                className={`p-2 rounded-md transition ${
                  viewMode === 'table' ? 'bg-white shadow' : 'hover:bg-gray-200'
                }`}
                title="Таблица"
              >
                <TableCellsIcon className="h-4 w-4" />
              </button>
              <button
                onClick={() => setViewMode('chart')}
                className={`p-2 rounded-md transition ${
                  viewMode === 'chart' ? 'bg-white shadow' : 'hover:bg-gray-200'
                }`}
                title="График"
              >
                <ChartBarIcon className="h-4 w-4" />
              </button>
            </div>
          </div>

          {/* Content */}
          {viewMode === 'table' ? (
            <div className="bg-white rounded-xl shadow-sm overflow-hidden">
              {/* Mobile Cards */}
              <div className="md:hidden divide-y">
                {displayData.slice(0, 20).map((record, idx) => (
                  <div key={idx} className="p-4 space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="font-medium text-gray-900">{record.deviceName}</span>
                      <span className="text-xs text-gray-500">{record.deviceId}</span>
                    </div>
                    <div className="flex items-center gap-4 text-sm">
                      <div className="flex items-center gap-1">
                        <CalendarIcon className="h-4 w-4 text-gray-400" />
                        {new Date(record.timestamp).toLocaleDateString('ru-RU')}
                      </div>
                      <div className="flex items-center gap-1">
                        <ClockIcon className="h-4 w-4 text-gray-400" />
                        {new Date(record.timestamp).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      <div className="bg-red-50 rounded-lg p-2 text-center">
                        <p className="text-xs text-red-600">Температура</p>
                        <p className="text-lg font-bold text-red-700">{record.temperature}°C</p>
                      </div>
                      <div className="bg-blue-50 rounded-lg p-2 text-center">
                        <p className="text-xs text-blue-600">Вибрация</p>
                        <p className="text-lg font-bold text-blue-700">{record.vibration} g</p>
                      </div>
                    </div>
                  </div>
                ))}
                {displayData.length > 20 && (
                  <div className="p-4 text-center text-sm text-gray-500">
                    Показаны первые 20 записей из {displayData.length}. Экспортируйте для полного списка.
                  </div>
                )}
              </div>

              {/* Desktop Table */}
              <table className="hidden md:table w-full">
                <thead className="bg-gray-50 border-b">
                  <tr>
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Дата/Время</th>
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Устройство</th>
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">ID</th>
                    <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Температура</th>
                    <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Вибрация</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {displayData.slice(0, 50).map((record, idx) => (
                    <tr key={idx} className="hover:bg-gray-50">
                      <td className="px-4 py-3 text-sm text-gray-900">
                        {new Date(record.timestamp).toLocaleString('ru-RU')}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-900">{record.deviceName}</td>
                      <td className="px-4 py-3 text-sm text-gray-500">{record.deviceId}</td>
                      <td className="px-4 py-3 text-sm text-right">
                        <span className={`font-medium ${record.temperature > 60 ? 'text-red-600' : 'text-gray-900'}`}>
                          {record.temperature}°C
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-right">
                        <span className={`font-medium ${record.vibration > 3 ? 'text-orange-600' : 'text-gray-900'}`}>
                          {record.vibration} g
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {displayData.length > 50 && (
                <div className="hidden md:block p-4 text-center text-sm text-gray-500 border-t">
                  Показаны первые 50 записей из {displayData.length}. Экспортируйте для полного списка.
                </div>
              )}
            </div>
          ) : (
            <div className="bg-white rounded-xl shadow-sm p-4">
              <DataChart data={displayData} />
            </div>
          )}
        </>
      ) : (
        /* Export History */
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b">
            <h3 className="font-medium text-gray-900">История экспорта</h3>
            {exportHistory.length > 0 && (
              <button
                onClick={clearHistory}
                className="text-sm text-red-600 hover:text-red-700"
              >
                Очистить историю
              </button>
            )}
          </div>
          
          {exportHistory.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <DocumentTextIcon className="h-12 w-12 mx-auto mb-3 text-gray-300" />
              <p>История экспорта пуста</p>
              <p className="text-sm">Экспортируйте данные, и они появятся здесь</p>
            </div>
          ) : (
            <div className="divide-y">
              {exportHistory.map((item) => (
                <div key={item.id} className="flex items-center justify-between p-4 hover:bg-gray-50">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${item.format === 'csv' ? 'bg-green-100' : 'bg-blue-100'}`}>
                      <DocumentTextIcon className={`h-5 w-5 ${item.format === 'csv' ? 'text-green-600' : 'text-blue-600'}`} />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{item.filename}</p>
                      <p className="text-sm text-gray-500">
                        {item.recordCount} записей • {item.size} • {new Date(item.exportedAt).toLocaleString('ru-RU')}
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => deleteHistoryItem(item.id)}
                    className="p-2 text-gray-400 hover:text-red-600 transition"
                  >
                    <TrashIcon className="h-4 w-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Info Card */}
      <div className="bg-blue-50 rounded-xl p-4">
        <h4 className="font-medium text-blue-900 mb-2">💡 Подсказка</h4>
        <ul className="text-sm text-blue-800 space-y-1">
          <li>• <strong>CSV</strong> — откройте в Excel или Google Sheets для анализа</li>
          <li>• <strong>JSON</strong> — используйте для резервного копирования или импорта обратно</li>
          <li>• Импортируйте ранее экспортированные файлы для сравнения данных</li>
        </ul>
      </div>
    </div>
  )
}
