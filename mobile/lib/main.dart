import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

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
  bool isRecording = false;
  BluetoothDevice? connectedDevice;
  List<ScanResult> scanResults = [];
  
  // Запись данных
  String? currentSessionName;
  List<SensorDataFull> recordedData = [];
  DateTime? recordingStartTime;
  
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
    _tabController = TabController(length: 4, vsync: this);
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
    final now = DateTime.now();
    history.add(SensorData(
      timestamp: now,
      temperature: temperature,
      rms: vibration.rms,
      rmsVelocity: vibration.rmsVelocity,
      status: vibration.status,
    ));
    if (history.length > 100) {
      history.removeAt(0);
    }
    
    // Если идёт запись - добавляем полные данные
    if (isRecording) {
      recordedData.add(SensorDataFull(
        timestamp: now,
        temperature: temperature,
        rms: vibration.rms,
        rmsVelocity: vibration.rmsVelocity,
        peak: vibration.peak,
        peakToPeak: vibration.peakToPeak,
        crestFactor: vibration.crestFactor,
        dominantFreq: vibration.dominantFreq,
        dominantAmp: vibration.dominantAmp,
        status: vibration.status,
        spectrumBands: List.from(spectrum.bands),
      ));
    }
  }

  // ========== ЗАПИСЬ И ЭКСПОРТ ==========
  void _startRecording() {
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    setState(() {
      isRecording = true;
      recordingStartTime = DateTime.now();
      currentSessionName = 'session_${formatter.format(recordingStartTime!)}';
      recordedData.clear();
    });
    _showSnackBar('🔴 Запись начата');
  }

  void _stopRecording() {
    setState(() {
      isRecording = false;
    });
    _showSnackBar('⏹️ Запись остановлена (${recordedData.length} записей)');
  }

  Future<void> _exportToCSV() async {
    if (recordedData.isEmpty) {
      _showSnackBar('Нет данных для экспорта');
      return;
    }

    try {
      // Заголовок CSV
      StringBuffer csv = StringBuffer();
      csv.writeln('timestamp,temperature_c,rms_g,rms_velocity_mm_s,peak_g,peak_to_peak_g,crest_factor,dominant_freq_hz,dominant_amp,status,band_0_31hz,band_31_62hz,band_62_125hz,band_125_187hz,band_187_250hz,band_250_312hz,band_312_375hz,band_375_500hz');

      // Данные
      for (var data in recordedData) {
        csv.writeln(
          '${data.timestamp.toIso8601String()},'
          '${data.temperature.toStringAsFixed(2)},'
          '${data.rms.toStringAsFixed(6)},'
          '${data.rmsVelocity.toStringAsFixed(4)},'
          '${data.peak.toStringAsFixed(6)},'
          '${data.peakToPeak.toStringAsFixed(6)},'
          '${data.crestFactor.toStringAsFixed(4)},'
          '${data.dominantFreq.toStringAsFixed(2)},'
          '${data.dominantAmp.toStringAsFixed(6)},'
          '${data.status},'
          '${data.spectrumBands.map((b) => b.toStringAsFixed(6)).join(',')}'
        );
      }

      // Сохраняем файл
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${currentSessionName ?? 'export'}.csv');
      await file.writeAsString(csv.toString());

      // Делимся файлом
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VibeMon Data Export',
        text: 'Данные вибрации: ${recordedData.length} записей',
      );

      _showSnackBar('✅ CSV экспортирован');
    } catch (e) {
      _showSnackBar('Ошибка экспорта: $e');
    }
  }

  Future<void> _exportToJSON() async {
    if (recordedData.isEmpty) {
      _showSnackBar('Нет данных для экспорта');
      return;
    }

    try {
      Map<String, dynamic> jsonData = {
        'session': currentSessionName,
        'device': connectedDevice?.platformName ?? 'Unknown',
        'start_time': recordingStartTime?.toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'total_records': recordedData.length,
        'firmware': isAdvancedFirmware ? 'advanced' : 'basic',
        'data': recordedData.map((d) {
          return {
            'timestamp': d.timestamp.toIso8601String(),
            'temperature': d.temperature,
            'vibration': {
              'rms_g': d.rms,
              'rms_velocity_mm_s': d.rmsVelocity,
              'peak_g': d.peak,
              'peak_to_peak_g': d.peakToPeak,
              'crest_factor': d.crestFactor,
              'dominant_freq_hz': d.dominantFreq,
              'dominant_amp': d.dominantAmp,
              'status': d.status,
            },
            'spectrum_bands': d.spectrumBands,
          };
        }).toList(),
      };

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${currentSessionName ?? 'export'}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonData));

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VibeMon Data Export (JSON)',
        text: 'Данные вибрации: ${recordedData.length} записей',
      );

      _showSnackBar('✅ JSON экспортирован');
    } catch (e) {
      _showSnackBar('Ошибка экспорта: $e');
    }
  }

  Future<void> _saveSession() async {
    if (recordedData.isEmpty) {
      _showSnackBar('Нет данных для сохранения');
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final sessionsDir = Directory('${directory.path}/sessions');
      if (!await sessionsDir.exists()) {
        await sessionsDir.create(recursive: true);
      }

      Map<String, dynamic> sessionData = {
        'session': currentSessionName,
        'device': connectedDevice?.platformName ?? 'Unknown',
        'start_time': recordingStartTime?.toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'total_records': recordedData.length,
        'data': recordedData.map((d) => d.toJson()).toList(),
      };

      final file = File('${sessionsDir.path}/${currentSessionName}.json');
      await file.writeAsString(jsonEncode(sessionData));

      _showSnackBar('💾 Сессия сохранена');
    } catch (e) {
      _showSnackBar('Ошибка сохранения: $e');
    }
  }

  Future<List<String>> _getSavedSessions() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sessionsDir = Directory('${directory.path}/sessions');
      if (!await sessionsDir.exists()) {
        return [];
      }
      
      final files = await sessionsDir.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .map((f) => f.path.split('/').last.replaceAll('.json', ''))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Новые сверху
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadSession(String sessionName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sessions/$sessionName.json');
      
      if (!await file.exists()) {
        _showSnackBar('Сессия не найдена');
        return;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);

      setState(() {
        currentSessionName = json['session'];
        recordingStartTime = DateTime.tryParse(json['start_time'] ?? '');
        recordedData = (json['data'] as List)
            .map((d) => SensorDataFull.fromJson(d))
            .toList();
      });

      _showSnackBar('📂 Загружена сессия: ${recordedData.length} записей');
    } catch (e) {
      _showSnackBar('Ошибка загрузки: $e');
    }
  }

  Future<void> _deleteSession(String sessionName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sessions/$sessionName.json');
      if (await file.exists()) {
        await file.delete();
        _showSnackBar('🗑️ Сессия удалена');
      }
    } catch (e) {
      _showSnackBar('Ошибка удаления: $e');
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAdvancedFirmware ? 'VibeMon Pro' : 'VibeMon'),
            if (isRecording) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text('REC ${recordedData.length}', 
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Обзор'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Спектр'),
            Tab(icon: Icon(Icons.save), text: 'Запись'),
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
                _buildRecordingTab(),
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

  // ========== ВКЛАДКА ЗАПИСЬ ==========
  Widget _buildRecordingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Панель управления записью
          Card(
            color: isRecording ? Colors.red.shade50 : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                    size: 64,
                    color: isRecording ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRecording ? 'Запись идёт' : 'Запись остановлена',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isRecording ? Colors.red : Colors.green,
                    ),
                  ),
                  if (isRecording && recordingStartTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Начало: ${DateFormat('HH:mm:ss').format(recordingStartTime!)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      'Записей: ${recordedData.length}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isRecording ? _stopRecording : _startRecording,
                        icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
                        label: Text(isRecording ? 'Остановить' : 'Начать запись'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRecording ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Экспорт данных
          if (recordedData.isNotEmpty) ...[
            const Text('Экспорт записанных данных',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сессия: ${currentSessionName ?? "Без имени"}'),
                    Text('Записей: ${recordedData.length}'),
                    if (recordingStartTime != null)
                      Text('Длительность: ${_getDuration()}'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportToCSV,
                            icon: const Icon(Icons.table_chart),
                            label: const Text('CSV'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportToJSON,
                            icon: const Icon(Icons.code),
                            label: const Text('JSON'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveSession,
                            icon: const Icon(Icons.save),
                            label: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Сохранённые сессии
          const Text('Сохранённые сессии',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<List<String>>(
            future: _getSavedSessions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Нет сохранённых сессий',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sessionName = snapshot.data![index];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(sessionName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.upload),
                            onPressed: () => _loadSession(sessionName),
                            tooltip: 'Загрузить',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Удалить сессию?'),
                                  content: Text('Удалить "$sessionName"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Удалить', 
                                        style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _deleteSession(sessionName);
                                setState(() {});
                              }
                            },
                            tooltip: 'Удалить',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Справка по форматам
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📊 Форматы экспорта:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• CSV - для Excel, Python (pandas), MATLAB'),
                  Text('• JSON - для программного анализа'),
                  SizedBox(height: 8),
                  Text('Данные включают: температуру, RMS, скорость,\nпик, crest factor, частоты, спектр FFT',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDuration() {
    if (recordingStartTime == null) return '';
    final duration = DateTime.now().difference(recordingStartTime!);
    return '${duration.inMinutes}м ${duration.inSeconds % 60}с';
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
    // Диагностика основана на реальной вибродиагностике
    // Предполагаем типичный двигатель ~3000 об/мин (50 Гц основная частота)
    // 1x = дисбаланс, 2x = несоосность, дробные = ослабление
    
    List<String> diagnoses = [];
    IconData icon = Icons.help;
    Color color = Colors.grey;

    // Анализ по характерным частотам
    if (freq > 0 && freq < 5) {
      diagnoses.add('Очень низкая частота - возможны внешние воздействия или люфт');
      icon = Icons.foundation;
      color = Colors.brown;
    } else if (freq >= 5 && freq < 15) {
      // Субгармоники - ослабление, люфт
      diagnoses.add('Субгармоника (0.5x) - ослабление крепления или масляный вихрь');
      icon = Icons.build_circle;
      color = Colors.orange;
    } else if (freq >= 15 && freq < 35) {
      // ~25 Гц = 1500 об/мин или 0.5x от 3000
      diagnoses.add('Область 1x (1500-2100 об/мин) - проверьте балансировку');
      icon = Icons.rotate_right;
      color = Colors.amber;
    } else if (freq >= 35 && freq < 70) {
      // ~50 Гц = 3000 об/мин (1x) или сетевая частота
      if (freq >= 48 && freq <= 52) {
        diagnoses.add('50 Гц - частота сети или 1x при 3000 об/мин');
        diagnoses.add('Если 1x: дисбаланс ротора');
      } else {
        diagnoses.add('Область 1x (2100-4200 об/мин) - дисбаланс');
      }
      icon = Icons.electric_bolt;
      color = Colors.blue;
    } else if (freq >= 70 && freq < 110) {
      // ~100 Гц = 2x от 3000 или 2x сети
      diagnoses.add('Область 2x - несоосность валов или электромагнитные силы');
      icon = Icons.settings;
      color = Colors.orange;
    } else if (freq >= 110 && freq < 200) {
      // Высшие гармоники
      diagnoses.add('Высшие гармоники (3x-4x) - возможен износ муфты или резонанс');
      icon = Icons.waves;
      color = Colors.amber;
    } else if (freq >= 200) {
      // Высокочастотная область - подшипники, шестерни
      diagnoses.add('Высокочастотная область - дефекты подшипников или зубчатых передач');
      icon = Icons.precision_manufacturing;
      color = Colors.red;
    }

    // Анализ Crest Factor (пик-фактор)
    if (crestFactor > 6) {
      diagnoses.add('⚠️ CF > 6: импульсные удары - ранняя стадия дефекта подшипника');
      color = Colors.red;
      icon = Icons.warning;
    } else if (crestFactor > 4) {
      diagnoses.add('CF 4-6: повышенные пики - контролируйте состояние');
      if (color != Colors.red) color = Colors.orange;
    } else if (crestFactor >= 1.4 && crestFactor <= 1.5) {
      diagnoses.add('CF ~1.41: чистая синусоида - вероятен дисбаланс');
    }

    String fullDiagnosis = diagnoses.join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(fullDiagnosis, style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '💡 Точная диагностика требует знания RPM оборудования:\n'
            '• 1x RPM/60 = дисбаланс\n'
            '• 2x RPM/60 = несоосность\n'
            '• Дробные гармоники = ослабление',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
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

// Полные данные для записи и экспорта
class SensorDataFull {
  final DateTime timestamp;
  final double temperature;
  final double rms;
  final double rmsVelocity;
  final double peak;
  final double peakToPeak;
  final double crestFactor;
  final double dominantFreq;
  final double dominantAmp;
  final int status;
  final List<double> spectrumBands;

  SensorDataFull({
    required this.timestamp,
    required this.temperature,
    required this.rms,
    required this.rmsVelocity,
    required this.peak,
    required this.peakToPeak,
    required this.crestFactor,
    required this.dominantFreq,
    required this.dominantAmp,
    required this.status,
    required this.spectrumBands,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'temperature': temperature,
    'rms': rms,
    'rms_velocity': rmsVelocity,
    'peak': peak,
    'peak_to_peak': peakToPeak,
    'crest_factor': crestFactor,
    'dominant_freq': dominantFreq,
    'dominant_amp': dominantAmp,
    'status': status,
    'spectrum_bands': spectrumBands,
  };

  factory SensorDataFull.fromJson(Map<String, dynamic> json) {
    return SensorDataFull(
      timestamp: DateTime.parse(json['timestamp']),
      temperature: (json['temperature'] ?? 0).toDouble(),
      rms: (json['rms'] ?? 0).toDouble(),
      rmsVelocity: (json['rms_velocity'] ?? 0).toDouble(),
      peak: (json['peak'] ?? 0).toDouble(),
      peakToPeak: (json['peak_to_peak'] ?? 0).toDouble(),
      crestFactor: (json['crest_factor'] ?? 0).toDouble(),
      dominantFreq: (json['dominant_freq'] ?? 0).toDouble(),
      dominantAmp: (json['dominant_amp'] ?? 0).toDouble(),
      status: json['status'] ?? 0,
      spectrumBands: (json['spectrum_bands'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? List.filled(8, 0.0),
    );
  }
}
