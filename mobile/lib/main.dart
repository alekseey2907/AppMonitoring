import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
  // BLE UUIDs - должны совпадать с ESP32
  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String tempCharUuid = "12345678-1234-5678-1234-56789abcdef1";
  static const String vibrationCharUuid = "12345678-1234-5678-1234-56789abcdef2";

  // Состояние
  bool isScanning = false;
  bool isConnected = false;
  BluetoothDevice? connectedDevice;
  List<ScanResult> scanResults = [];
  
  // Данные с датчиков
  double temperature = 0.0;
  double vibration = 0.0;
  DateTime? lastUpdate;
  
  // История данных для графика
  List<SensorData> history = [];
  
  // Подписки
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    _disconnect();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    try {
      // Проверяем включен ли Bluetooth
      if (await FlutterBluePlus.isSupported == false) {
        _showSnackBar('Bluetooth не поддерживается');
        return;
      }

      // Включаем Bluetooth если выключен
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        _showSnackBar('Пожалуйста, включите Bluetooth');
        setState(() => isScanning = false);
        return;
      }

      // Подписываемся на результаты сканирования
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          scanResults = results.where((r) => 
            r.device.platformName.contains('VibeMon') ||
            r.device.platformName.contains('ESP32') ||
            r.advertisementData.serviceUuids.any((uuid) => 
              uuid.toString().toLowerCase() == serviceUuid.toLowerCase()
            )
          ).toList();
        });
      });

      // Начинаем сканирование
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(serviceUuid)],
      );

    } catch (e) {
      _showSnackBar('Ошибка сканирования: $e');
    } finally {
      setState(() => isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() => isScanning = false);
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      _showSnackBar('Подключение к ${device.platformName}...');
      
      await device.connect(timeout: const Duration(seconds: 10));
      
      // Подписываемся на состояние подключения
      connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            isConnected = false;
            connectedDevice = null;
          });
          _showSnackBar('Устройство отключено');
        }
      });

      setState(() {
        isConnected = true;
        connectedDevice = device;
      });

      _showSnackBar('Подключено к ${device.platformName}');

      // Обнаруживаем сервисы
      await _discoverServices(device);

    } catch (e) {
      _showSnackBar('Ошибка подключения: $e');
      setState(() {
        isConnected = false;
        connectedDevice = null;
      });
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (BluetoothCharacteristic char in service.characteristics) {
            String charUuid = char.uuid.toString().toLowerCase();
            
            if (charUuid == tempCharUuid.toLowerCase()) {
              // Подписываемся на температуру
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                if (value.length >= 4) {
                  ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
                  double temp = byteData.getFloat32(0, Endian.little);
                  setState(() {
                    temperature = temp;
                    lastUpdate = DateTime.now();
                    _addToHistory();
                  });
                }
              });
            }
            
            if (charUuid == vibrationCharUuid.toLowerCase()) {
              // Подписываемся на вибрацию
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                if (value.length >= 4) {
                  ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
                  double vib = byteData.getFloat32(0, Endian.little);
                  setState(() {
                    vibration = vib;
                    lastUpdate = DateTime.now();
                  });
                }
              });
            }
          }
          break;
        }
      }
    } catch (e) {
      _showSnackBar('Ошибка обнаружения сервисов: $e');
    }
  }

  void _addToHistory() {
    history.add(SensorData(
      timestamp: DateTime.now(),
      temperature: temperature,
      vibration: vibration,
    ));
    // Храним последние 100 записей
    if (history.length > 100) {
      history.removeAt(0);
    }
  }

  Future<void> _disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
    }
    setState(() {
      isConnected = false;
      connectedDevice = null;
      temperature = 0.0;
      vibration = 0.0;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Color _getTempColor(double temp) {
    if (temp < 50) return Colors.green;
    if (temp < 70) return Colors.orange;
    return Colors.red;
  }

  Color _getVibColor(double vib) {
    if (vib < 2) return Colors.green;
    if (vib < 3.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeMon'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_connected, color: Colors.green),
              onPressed: _disconnect,
              tooltip: 'Отключить',
            )
          else
            IconButton(
              icon: Icon(isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
              onPressed: isScanning ? _stopScan : _startScan,
              tooltip: isScanning ? 'Остановить поиск' : 'Найти устройства',
            ),
        ],
      ),
      body: isConnected ? _buildConnectedView() : _buildScanView(),
    );
  }

  Widget _buildScanView() {
    return Column(
      children: [
        // Статус
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Icon(
                isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                size: 48,
                color: isScanning ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                isScanning ? 'Поиск устройств...' : 'Нажмите для поиска ESP32',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),

        // Кнопка поиска
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: isScanning ? _stopScan : _startScan,
            icon: Icon(isScanning ? Icons.stop : Icons.search),
            label: Text(isScanning ? 'Остановить' : 'Найти ESP32'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        // Список найденных устройств
        Expanded(
          child: scanResults.isEmpty
              ? Center(
                  child: Text(
                    isScanning ? 'Поиск...' : 'Устройства не найдены',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final result = scanResults[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.memory, color: Colors.white),
                      ),
                      title: Text(result.device.platformName.isNotEmpty
                          ? result.device.platformName
                          : 'ESP32 Device'),
                      subtitle: Text('RSSI: ${result.rssi} dBm'),
                      trailing: ElevatedButton(
                        onPressed: () => _connect(result.device),
                        child: const Text('Подключить'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConnectedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Статус подключения
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
              title: Text(connectedDevice?.platformName ?? 'ESP32'),
              subtitle: Text(lastUpdate != null
                  ? 'Обновлено: ${_formatTime(lastUpdate!)}'
                  : 'Ожидание данных...'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _disconnect,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Карточки с данными
          Row(
            children: [
              Expanded(
                child: _DataCard(
                  title: 'Температура',
                  value: '${temperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat,
                  color: _getTempColor(temperature),
                  subtitle: _getTempStatus(temperature),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DataCard(
                  title: 'Вибрация',
                  value: '${vibration.toStringAsFixed(2)}g',
                  icon: Icons.vibration,
                  color: _getVibColor(vibration),
                  subtitle: _getVibStatus(vibration),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Пороговые значения
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Пороговые значения',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _ThresholdRow(label: 'Температура', 
                      values: ['< 50°C', '50-70°C', '> 70°C'],
                      colors: [Colors.green, Colors.orange, Colors.red]),
                  const SizedBox(height: 8),
                  _ThresholdRow(label: 'Вибрация', 
                      values: ['< 2g', '2-3.5g', '> 3.5g'],
                      colors: [Colors.green, Colors.orange, Colors.red]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // История (последние записи)
          if (history.isNotEmpty) ...[
            const Text('История показаний',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: history.length > 10 ? 10 : history.length,
                  itemBuilder: (context, index) {
                    final data = history[history.length - 1 - index];
                    return ListTile(
                      dense: true,
                      leading: Text(_formatTime(data.timestamp),
                          style: const TextStyle(fontSize: 12)),
                      title: Row(
                        children: [
                          Icon(Icons.thermostat, size: 16, color: _getTempColor(data.temperature)),
                          Text(' ${data.temperature.toStringAsFixed(1)}°C'),
                          const SizedBox(width: 16),
                          Icon(Icons.vibration, size: 16, color: _getVibColor(data.vibration)),
                          Text(' ${data.vibration.toStringAsFixed(2)}g'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _getTempStatus(double temp) {
    if (temp < 50) return 'Норма';
    if (temp < 70) return 'Внимание';
    return 'Критично!';
  }

  String _getVibStatus(double vib) {
    if (vib < 2) return 'Норма';
    if (vib < 3.5) return 'Внимание';
    return 'Критично!';
  }
}

class _DataCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _DataCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            Text(value, style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final String label;
  final List<String> values;
  final List<Color> colors;

  const _ThresholdRow({
    required this.label,
    required this.values,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        ...List.generate(values.length, (i) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: colors[i].withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(values[i], 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors[i]),
            ),
          ),
        )),
      ],
    );
  }
}

class SensorData {
  final DateTime timestamp;
  final double temperature;
  final double vibration;

  SensorData({
    required this.timestamp,
    required this.temperature,
    required this.vibration,
  });
}
