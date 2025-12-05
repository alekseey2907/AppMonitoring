'use client'

import { PlusIcon, PencilIcon, TrashIcon } from '@heroicons/react/24/outline'

const users = [
  { id: 1, name: 'Иван Петров', email: 'ivan@example.com', role: 'admin', org: 'АгроТех', lastActive: '5 мин назад' },
  { id: 2, name: 'Мария Сидорова', email: 'maria@example.com', role: 'operator', org: 'АгроТех', lastActive: '1 час назад' },
  { id: 3, name: 'Алексей Козлов', email: 'alexey@example.com', role: 'viewer', org: 'ПромСервис', lastActive: '2 дня назад' },
  { id: 4, name: 'Елена Новикова', email: 'elena@example.com', role: 'operator', org: 'ПромСервис', lastActive: '30 мин назад' },
  { id: 5, name: 'Дмитрий Волков', email: 'dmitry@example.com', role: 'admin', org: 'ТехноМаш', lastActive: 'Сейчас' },
]

const roleLabels: Record<string, string> = {
  admin: 'Администратор',
  operator: 'Оператор',
  viewer: 'Наблюдатель',
}

const roleColors: Record<string, string> = {
  admin: 'bg-purple-100 text-purple-800',
  operator: 'bg-blue-100 text-blue-800',
  viewer: 'bg-gray-100 text-gray-800',
}

export default function UsersPage() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-900">Пользователи</h1>
        <button className="flex items-center gap-2 bg-blue-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-blue-700">
          <PlusIcon className="h-4 w-4" />
          Добавить
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Пользователь</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Роль</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Организация</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Последняя активность</th>
              <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Действия</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {users.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50">
                <td className="px-4 py-3">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center">
                      <span className="text-sm font-medium text-gray-600">
                        {user.name.split(' ').map(n => n[0]).join('')}
                      </span>
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-900">{user.name}</p>
                      <p className="text-xs text-gray-500">{user.email}</p>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-3">
                  <span className={`inline-flex px-2 py-0.5 text-xs font-medium rounded-full ${roleColors[user.role]}`}>
                    {roleLabels[user.role]}
                  </span>
                </td>
                <td className="px-4 py-3 text-sm text-gray-900">{user.org}</td>
                <td className="px-4 py-3 text-sm text-gray-500">{user.lastActive}</td>
                <td className="px-4 py-3">
                  <div className="flex justify-end gap-1">
                    <button className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded">
                      <PencilIcon className="h-4 w-4" />
                    </button>
                    <button className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded">
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
