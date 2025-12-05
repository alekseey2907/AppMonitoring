import 'package:flutter/material.dart';

void main() {
  runApp(const VibemonApp());
}

class VibemonApp extends StatelessWidget {
  const VibemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeMon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeMon'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DevicesPage(),
          AlertsPage(),
          AnalyticsPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Устройства',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_outlined),
            selectedIcon: Icon(Icons.warning),
            label: 'Алерты',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Аналитика',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final devices = [
      {'name': 'Трактор МТЗ-82 #1', 'status': 'online', 'temp': 45.0, 'vib': 1.2},
      {'name': 'Элеватор мотор #3', 'status': 'warning', 'temp': 65.0, 'vib': 2.8},
      {'name': 'Насос датчик #7', 'status': 'online', 'temp': 38.0, 'vib': 0.8},
      {'name': 'Комбайн #12', 'status': 'critical', 'temp': 78.0, 'vib': 4.5},
      {'name': 'Генератор #5', 'status': 'offline', 'temp': 0.0, 'vib': 0.0},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return DeviceCard(device: device);
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  const DeviceCard({super.key, required this.device});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online': return Colors.green;
      case 'warning': return Colors.orange;
      case 'critical': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'online': return 'Онлайн';
      case 'warning': return 'Внимание';
      case 'critical': return 'Критично';
      default: return 'Оффлайн';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = device['status'] as String;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(device['name'] as String,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_getStatusText(status),
                    style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricTile(icon: Icons.thermostat, label: 'Температура', value: '${device['temp']}°C', color: Colors.red)),
                const SizedBox(width: 16),
                Expanded(child: _MetricTile(icon: Icons.vibration, label: 'Вибрация', value: '${device['vib']} g', color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = [
      {'device': 'Комбайн #12', 'message': 'Критическая температура: 78°C', 'time': '5 мин назад', 'level': 'critical'},
      {'device': 'Элеватор мотор #3', 'message': 'Повышенная вибрация: 2.8g', 'time': '15 мин назад', 'level': 'warning'},
      {'device': 'Трактор МТЗ-82 #1', 'message': 'Температура нормализована', 'time': '1 час назад', 'level': 'info'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final level = alert['level'] as String;
        final color = level == 'critical' ? Colors.red : level == 'warning' ? Colors.orange : Colors.blue;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(level == 'critical' ? Icons.error : level == 'warning' ? Icons.warning : Icons.info, color: color),
            ),
            title: Text(alert['device'] as String),
            subtitle: Text(alert['message'] as String),
            trailing: Text(alert['time'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Статистика за 24 часа', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _StatCard(title: 'Ср. температура', value: '52.4°C', icon: Icons.thermostat, color: Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Ср. вибрация', value: '1.8 g', icon: Icons.vibration, color: Colors.blue)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(title: 'Алертов', value: '12', icon: Icons.warning, color: Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Устройств онлайн', value: '8/10', icon: Icons.devices, color: Colors.green)),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          const Text('Администратор', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('admin@vibemon.io', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ListTile(leading: const Icon(Icons.business), title: const Text('Организация'), subtitle: const Text('АгроТех Холдинг'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Icons.notifications), title: const Text('Уведомления'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Icons.help), title: const Text('Помощь'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Spacer(),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.logout), label: const Text('Выйти'))),
        ],
      ),
    );
  }
}
