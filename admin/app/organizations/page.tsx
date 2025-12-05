'use client'

import { PlusIcon, BuildingOfficeIcon } from '@heroicons/react/24/outline'

const organizations = [
  { id: 1, name: 'АгроТех', devices: 45, users: 12, plan: 'enterprise', status: 'active' },
  { id: 2, name: 'ПромСервис', devices: 28, users: 8, plan: 'professional', status: 'active' },
  { id: 3, name: 'ТехноМаш', devices: 15, users: 4, plan: 'starter', status: 'active' },
  { id: 4, name: 'АгроХолдинг', devices: 120, users: 35, plan: 'enterprise', status: 'active' },
  { id: 5, name: 'ТестОрг', devices: 2, users: 1, plan: 'trial', status: 'trial' },
]

const planLabels: Record<string, string> = {
  enterprise: 'Enterprise',
  professional: 'Professional',
  starter: 'Starter',
  trial: 'Пробный',
}

const planColors: Record<string, string> = {
  enterprise: 'bg-purple-100 text-purple-800',
  professional: 'bg-blue-100 text-blue-800',
  starter: 'bg-green-100 text-green-800',
  trial: 'bg-gray-100 text-gray-800',
}

export default function OrganizationsPage() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-900">Организации</h1>
        <button className="flex items-center gap-2 bg-blue-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-blue-700">
          <PlusIcon className="h-4 w-4" />
          Добавить
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {organizations.map((org) => (
          <div key={org.id} className="bg-white rounded-xl shadow-sm p-4 hover:shadow-md transition-shadow cursor-pointer">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                  <BuildingOfficeIcon className="h-5 w-5 text-blue-600" />
                </div>
                <div>
                  <h3 className="font-medium text-gray-900">{org.name}</h3>
                  <span className={`inline-flex px-2 py-0.5 text-xs font-medium rounded-full ${planColors[org.plan]}`}>
                    {planLabels[org.plan]}
                  </span>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4 text-center border-t pt-3">
              <div>
                <p className="text-lg font-semibold text-gray-900">{org.devices}</p>
                <p className="text-xs text-gray-500">Устройств</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-gray-900">{org.users}</p>
                <p className="text-xs text-gray-500">Пользователей</p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
