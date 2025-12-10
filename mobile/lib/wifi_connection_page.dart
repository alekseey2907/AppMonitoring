import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'wifi_provider.dart';

/// Экран подключения к VibeMon через WiFi
class WiFiConnectionPage extends StatefulWidget {
  const WiFiConnectionPage({Key? key}) : super(key: key);

  @override
  State<WiFiConnectionPage> createState() => _WiFiConnectionPageState();
}

class _WiFiConnectionPageState extends State<WiFiConnectionPage> {
  final TextEditingController _hostController = TextEditingController(
    text: WiFiProvider.defaultHost,
  );
  final TextEditingController _portController = TextEditingController(
    text: WiFiProvider.defaultPort.toString(),
  );
  
  bool _isConnecting = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _isConnecting = true);
    
    final wifiProvider = context.read<WiFiProvider>();
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? WiFiProvider.defaultPort;
    
    final success = await wifiProvider.connect(host: host, port: port);
    
    setState(() => _isConnecting = false);
    
    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка подключения: ${wifiProvider.lastError}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Подключение'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Инструкция
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Инструкция',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Убедитесь, что ESP32 в режиме WiFi AP\n'
                      '2. Подключитесь к сети "VibeMon_AP"\n'
                      '3. Пароль: vibemon123\n'
                      '4. IP адрес по умолчанию: 192.168.4.1\n'
                      '5. Порт: 8888',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // IP адрес
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'IP адрес',
                hintText: '192.168.4.1',
                prefixIcon: const Icon(Icons.computer),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),
            
            // Порт
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Порт',
                hintText: '8888',
                prefixIcon: const Icon(Icons.settings_ethernet),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 24),
            
            // Кнопка подключения
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.wifi),
              label: Text(
                _isConnecting ? 'Подключение...' : 'Подключиться',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Статус WiFi сети
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Статус WiFi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      'Сеть',
                      'VibeMon_AP',
                      Icons.wifi,
                    ),
                    const Divider(),
                    _buildStatusRow(
                      'Протокол',
                      'TCP/IP',
                      Icons.language,
                    ),
                    const Divider(),
                    _buildStatusRow(
                      'Скорость',
                      '~2 обновления/сек',
                      Icons.speed,
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Преимущества WiFi
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'WiFi режим работает быстрее и стабильнее BLE',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
