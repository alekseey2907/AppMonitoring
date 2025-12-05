import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
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
      title: 'VibeMon Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ========== МОДЕЛЬ ДАННЫХ ВИБРАЦИИ ==========
class VibrationData {
  final double rms;           // RMS в g
  final double rmsVelocity;   // RMS скорости в мм/с (ISO 10816)
  final double peak;          // Пиковое значение
  final double peakToPeak;    // Размах (Peak-to-Peak)
  final double crestFactor;   // Crest Factor (Peak/RMS)
  final double dominantFreq;  // Доминантная частота (Гц)
  final double dominantAmp;   // Амплитуда доминантной частоты
  final int status;           // 0=Good, 1=Acceptable, 2=Alarm, 3=Danger

  VibrationData({
    this.rms = 0,
    this.rmsVelocity = 0,
    this.peak = 0,
    this.peakToPeak = 0,
    this.crestFactor = 0,
    this.dominantFreq = 0,
    this.dominantAmp = 0,
    this.status = 0,
  });

  factory VibrationData.fromBytes(List<int> bytes) {
    if (bytes.length < 29) {
      return VibrationData();
    }
    ByteData byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    return VibrationData(
      rms: byteData.getFloat32(0, Endian.little),
      rmsVelocity: byteData.getFloat32(4, Endian.little),
      peak: byteData.getFloat32(8, Endian.little),
      peakToPeak: byteData.getFloat32(12, Endian.little),
      crestFactor: byteData.getFloat32(16, Endian.little),
      dominantFreq: byteData.getFloat32(20, Endian.little),
      dominantAmp: byteData.getFloat32(24, Endian.little),
      status: bytes[28],
    );
  }

  // Для совместимости с простой прошивкой (4 байта = только RMS)
  factory VibrationData.fromSimpleFloat(List<int> bytes) {
    if (bytes.length < 4) return VibrationData();
    ByteData byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    double rms = byteData.getFloat32(0, Endian.little);
    return VibrationData(
      rms: rms,
      rmsVelocity: (rms * 9.81 * 1000) / (2 * math.pi * 50), // Оценка
      peak: rms * 1.4,  // Оценка для синусоиды
      peakToPeak: rms * 2.8,
      crestFactor: 1.4,
      dominantFreq: 0,
      dominantAmp: 0,
      status: rms < 1.0 ? 0 : (rms < 2.0 ? 1 : (rms < 3.5 ? 2 : 3)),
    );
  }

  String get statusText {
    switch (status) {
      case 0: return 'НОРМА';
      case 1: return 'ДОПУСТИМО';
      case 2: return 'ТРЕВОГА';
      case 3: return 'ОПАСНО';
      default: return 'Н/Д';
    }
  }

  Color get statusColor {
    switch (status) {
      case 0: return Colors.green;
      case 1: return Colors.amber;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }
}

// ========== ДАННЫЕ СПЕКТРА ==========
class SpectrumData {
  final List<double> bands; // 8 частотных полос
  final List<String> labels = [
    '0-31', '31-62', '62-125', '125-187', 
    '187-250', '250-312', '312-375', '375-500'
  ];

  SpectrumData({List<double>? bands}) : bands = bands ?? List.filled(8, 0);

  factory SpectrumData.fromBytes(List<int> bytes) {
    if (bytes.length < 32) return SpectrumData();
    ByteData byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    List<double> bands = [];
    for (int i = 0; i < 8; i++) {
      bands.add(byteData.getFloat32(i * 4, Endian.little));
    }
    return SpectrumData(bands: bands);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // BLE UUIDs - должны совпадать с ESP32
  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String tempCharUuid = "12345678-1234-5678-1234-56789abcdef1";
  static const String vibrationCharUuid = "12345678-1234-5678-1234-56789abcdef2";
  static const String spectrumCharUuid = "12345678-1234-5678-1234-56789abcdef3";
  static const String statusCharUuid = "12345678-1234-5678-1234-56789abcdef4";

  // Состояние
  bool isScanning = false;
  bool isConnected = false;
  bool isAdvancedFirmware = false;
  BluetoothDevice? connectedDevice;
  List<ScanResult> scanResults = [];
  
  // Данные с датчиков
  double temperature = 0.0;
  VibrationData vibration = VibrationData();
  SpectrumData spectrum = SpectrumData();
  DateTime? lastUpdate;
  
  // История данных
  List<SensorData> history = [];
  
  // Подписки
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  // Tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _requestPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      if (await FlutterBluePlus.isSupported == false) {
        _showSnackBar('Bluetooth не поддерживается');
        return;
      }

      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        _showSnackBar('Пожалуйста, включите Bluetooth');
        setState(() => isScanning = false);
        return;
      }

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
      
      connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            isConnected = false;
            connectedDevice = null;
            isAdvancedFirmware = false;
          });
          _showSnackBar('Устройство отключено');
        }
      });

      setState(() {
        isConnected = true;
        connectedDevice = device;
      });

      _showSnackBar('Подключено к ${device.platformName}');
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
            
            // Температура
            if (charUuid == tempCharUuid.toLowerCase()) {
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
            
            // Вибрация (расширенные данные или простые)
            if (charUuid == vibrationCharUuid.toLowerCase()) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                setState(() {
                  if (value.length >= 29) {
                    // Расширенная прошивка
                    vibration = VibrationData.fromBytes(value);
                    isAdvancedFirmware = true;
                  } else if (value.length >= 4) {
                    // Простая прошивка
                    vibration = VibrationData.fromSimpleFloat(value);
                    isAdvancedFirmware = false;
                  }
                  lastUpdate = DateTime.now();
                });
              });
            }

            // Спектр FFT (только для расширенной прошивки)
            if (charUuid == spectrumCharUuid.toLowerCase()) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                if (value.length >= 32) {
                  setState(() {
                    spectrum = SpectrumData.fromBytes(value);
                    isAdvancedFirmware = true;
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
      rms: vibration.rms,
      rmsVelocity: vibration.rmsVelocity,
      status: vibration.status,
    ));
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
      vibration = VibrationData();
      spectrum = SpectrumData();
      isAdvancedFirmware = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdvancedFirmware ? 'VibeMon Pro' : 'VibeMon'),
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
        bottom: isConnected ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Обзор'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Спектр'),
            Tab(icon: Icon(Icons.history), text: 'История'),
          ],
        ) : null,
      ),
      body: isConnected 
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSpectrumTab(),
                _buildHistoryTab(),
              ],
            )
          : _buildScanView(),
    );
  }

  Widget _buildScanView() {
    return Column(
      children: [
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

  // ========== ВКЛАДКА ОБЗОР ==========
  Widget _buildOverviewTab() {
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

          const SizedBox(height: 16),

          // Главный статус вибрации
          _StatusCard(vibration: vibration),

          const SizedBox(height: 16),

          // Температура и основные показатели
          Row(
            children: [
              Expanded(
                child: _CompactDataCard(
                  title: 'Температура',
                  value: '${temperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat,
                  color: _getTempColor(temperature),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactDataCard(
                  title: 'RMS',
                  value: '${vibration.rms.toStringAsFixed(3)} g',
                  icon: Icons.show_chart,
                  color: vibration.statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _CompactDataCard(
                  title: 'Скорость RMS',
                  value: '${vibration.rmsVelocity.toStringAsFixed(2)} мм/с',
                  icon: Icons.speed,
                  color: vibration.statusColor,
                  subtitle: 'ISO 10816',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactDataCard(
                  title: 'Пик',
                  value: '${vibration.peak.toStringAsFixed(3)} g',
                  icon: Icons.trending_up,
                  color: vibration.statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _CompactDataCard(
                  title: 'Crest Factor',
                  value: vibration.crestFactor.toStringAsFixed(2),
                  icon: Icons.analytics,
                  color: vibration.crestFactor > 6 ? Colors.orange : Colors.green,
                  subtitle: vibration.crestFactor > 6 ? 'Удары!' : 'Норма',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactDataCard(
                  title: 'Дом. частота',
                  value: '${vibration.dominantFreq.toStringAsFixed(1)} Гц',
                  icon: Icons.waves,
                  color: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ISO 10816 справка
          _ISOReference(currentVelocity: vibration.rmsVelocity),
        ],
      ),
    );
  }

  // ========== ВКЛАДКА СПЕКТР ==========
  Widget _buildSpectrumTab() {
    if (!isAdvancedFirmware) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upgrade, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Спектральный анализ', style: TextStyle(fontSize: 20)),
            SizedBox(height: 8),
            Text('Требуется прошивка VibeMon Pro',
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 24),
            Text('Загрузите vibemon_esp32_advanced.ino\nна ваш ESP32',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    double maxValue = spectrum.bands.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FFT Спектр вибрации',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Доминантная частота: ${vibration.dominantFreq.toStringAsFixed(1)} Гц',
              style: const TextStyle(color: Colors.blue)),
          const SizedBox(height: 24),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(8, (index) {
                double normalized = spectrum.bands[index] / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          spectrum.bands[index].toStringAsFixed(2),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: normalized.clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getSpectrumColor(index),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spectrum.labels[index],
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                        const Text('Гц', style: TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Диагностика по частотам
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Диагностика по частотам:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _FrequencyDiagnostic(
                    freq: vibration.dominantFreq,
                    crestFactor: vibration.crestFactor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpectrumColor(int index) {
    const colors = [
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
    ];
    return colors[index];
  }

  // ========== ВКЛАДКА ИСТОРИЯ ==========
  Widget _buildHistoryTab() {
    if (history.isEmpty) {
      return const Center(
        child: Text('Нет данных', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final data = history[history.length - 1 - index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(data.status).withOpacity(0.2),
              child: Icon(
                _getStatusIcon(data.status),
                color: _getStatusColor(data.status),
              ),
            ),
            title: Row(
              children: [
                Icon(Icons.thermostat, size: 16, color: _getTempColor(data.temperature)),
                Text(' ${data.temperature.toStringAsFixed(1)}°C'),
                const SizedBox(width: 16),
                const Icon(Icons.show_chart, size: 16),
                Text(' ${data.rms.toStringAsFixed(3)} g'),
              ],
            ),
            subtitle: Text(
              '${data.rmsVelocity.toStringAsFixed(2)} мм/с • ${_formatTime(data.timestamp)}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(data.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(data.status),
                style: TextStyle(
                  color: _getStatusColor(data.status),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.green;
      case 1: return Colors.amber;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(int status) {
    switch (status) {
      case 0: return Icons.check_circle;
      case 1: return Icons.info;
      case 2: return Icons.warning;
      case 3: return Icons.error;
      default: return Icons.help;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: return 'НОРМА';
      case 1: return 'ДОПУСТ.';
      case 2: return 'ТРЕВОГА';
      case 3: return 'ОПАСНО';
      default: return 'Н/Д';
    }
  }
}

// ========== ВИДЖЕТЫ ==========

class _StatusCard extends StatelessWidget {
  final VibrationData vibration;

  const _StatusCard({required this.vibration});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: vibration.statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: vibration.statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(),
                size: 40,
                color: vibration.statusColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vibration.statusText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: vibration.statusColor,
                    ),
                  ),
                  Text(
                    '${vibration.rmsVelocity.toStringAsFixed(2)} мм/с RMS',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'ISO 10816 Класс I',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (vibration.status) {
      case 0: return Icons.check_circle;
      case 1: return Icons.info;
      case 2: return Icons.warning;
      case 3: return Icons.dangerous;
      default: return Icons.help;
    }
  }
}

class _CompactDataCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _CompactDataCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ISOReference extends StatelessWidget {
  final double currentVelocity;

  const _ISOReference({required this.currentVelocity});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ISO 10816-1 Класс I (малые машины)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildZone('A: Хорошо', '< 1.8 мм/с', Colors.green, currentVelocity < 1.8),
            _buildZone('B: Допустимо', '1.8 - 4.5 мм/с', Colors.amber, currentVelocity >= 1.8 && currentVelocity < 4.5),
            _buildZone('C: Тревога', '4.5 - 11.2 мм/с', Colors.orange, currentVelocity >= 4.5 && currentVelocity < 11.2),
            _buildZone('D: Опасно', '> 11.2 мм/с', Colors.red, currentVelocity >= 11.2),
          ],
        ),
      ),
    );
  }

  Widget _buildZone(String name, String range, Color color, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? color : Colors.grey,
          )),
          Text(range, style: TextStyle(color: isActive ? color : Colors.grey)),
          if (isActive) Icon(Icons.arrow_left, color: color),
        ],
      ),
    );
  }
}

class _FrequencyDiagnostic extends StatelessWidget {
  final double freq;
  final double crestFactor;

  const _FrequencyDiagnostic({required this.freq, required this.crestFactor});

  @override
  Widget build(BuildContext context) {
    String diagnosis = '';
    IconData icon = Icons.help;
    Color color = Colors.grey;

    if (freq < 10) {
      diagnosis = 'Низкочастотная вибрация - проверьте крепления';
      icon = Icons.foundation;
      color = Colors.brown;
    } else if (freq < 30) {
      diagnosis = 'Возможен дисбаланс ротора';
      icon = Icons.rotate_right;
      color = Colors.orange;
    } else if (freq < 60) {
      diagnosis = 'Вращающиеся компоненты - норма для двигателей';
      icon = Icons.settings;
      color = Colors.green;
    } else if (freq < 120) {
      diagnosis = 'Возможны проблемы с подшипниками';
      icon = Icons.warning;
      color = Colors.amber;
    } else {
      diagnosis = 'Высокочастотная вибрация - износ деталей';
      icon = Icons.build;
      color = Colors.red;
    }

    if (crestFactor > 6) {
      diagnosis += '\n⚠️ Высокий Crest Factor - возможны удары/дефекты подшипников';
      color = Colors.orange;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(diagnosis, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

class SensorData {
  final DateTime timestamp;
  final double temperature;
  final double rms;
  final double rmsVelocity;
  final int status;

  SensorData({
    required this.timestamp,
    required this.temperature,
    required this.rms,
    required this.rmsVelocity,
    required this.status,
  });
}
