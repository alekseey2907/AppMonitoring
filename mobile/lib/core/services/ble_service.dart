import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';

/// BLE Service UUIDs
class BleUuids {
  // Service UUIDs
  static const String telemetryService = 'A0000001-0000-1000-8000-00805F9B34FB';
  static const String controlService = 'B0000001-0000-1000-8000-00805F9B34FB';
  static const String otaService = 'C0000001-0000-1000-8000-00805F9B34FB';

  // Telemetry Characteristics
  static const String vibrationChar = 'A0000002-0000-1000-8000-00805F9B34FB';
  static const String temperatureChar = 'A0000003-0000-1000-8000-00805F9B34FB';
  static const String batteryChar = 'A0000004-0000-1000-8000-00805F9B34FB';
  static const String alertsChar = 'A0000005-0000-1000-8000-00805F9B34FB';

  // Control Characteristics
  static const String sampleRateChar = 'B0000002-0000-1000-8000-00805F9B34FB';
  static const String thresholdsChar = 'B0000003-0000-1000-8000-00805F9B34FB';
  static const String deviceInfoChar = 'B0000004-0000-1000-8000-00805F9B34FB';
  static const String commandChar = 'B0000005-0000-1000-8000-00805F9B34FB';

  // OTA Characteristics
  static const String otaControlChar = 'C0000002-0000-1000-8000-00805F9B34FB';
  static const String otaDataChar = 'C0000003-0000-1000-8000-00805F9B34FB';
  static const String otaStatusChar = 'C0000004-0000-1000-8000-00805F9B34FB';
}

/// Connection state enum
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Device data from BLE
class BleDeviceData {
  final double accelX;
  final double accelY;
  final double accelZ;
  final double temperature;
  final int batteryLevel;
  final int alertFlags;
  final DateTime timestamp;

  BleDeviceData({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.temperature,
    required this.batteryLevel,
    required this.alertFlags,
    required this.timestamp,
  });

  double get vibrationRms {
    return (accelX * accelX + accelY * accelY + accelZ * accelZ).abs();
  }

  bool get hasVibrationWarning => (alertFlags & 0x01) != 0;
  bool get hasVibrationCritical => (alertFlags & 0x02) != 0;
  bool get hasTempWarning => (alertFlags & 0x04) != 0;
  bool get hasTempCritical => (alertFlags & 0x08) != 0;
  bool get hasBatteryLow => (alertFlags & 0x10) != 0;
}

/// BLE Service for managing device connections
class BleService {
  final Logger _logger = Logger();
  
  BluetoothDevice? _connectedDevice;
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  
  final StreamController<BleConnectionState> _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<BleDeviceData> _dataController =
      StreamController<BleDeviceData>.broadcast();
  final StreamController<List<ScanResult>> _scanResultsController =
      StreamController<List<ScanResult>>.broadcast();

  Stream<BleConnectionState> get connectionState => _connectionStateController.stream;
  Stream<BleDeviceData> get dataStream => _dataController.stream;
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;
  
  BleConnectionState get currentConnectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    if (await FlutterBluePlus.isSupported == false) {
      _logger.e('Bluetooth not supported on this device');
      return false;
    }
    
    final adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  /// Start scanning for VibeMon devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    _logger.i('Starting BLE scan...');
    
    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      // Filter only VibeMon devices (by name prefix)
      final vibeMonDevices = results.where((r) => 
        r.device.platformName.startsWith('VibeMon_') ||
        r.advertisementData.serviceUuids.contains(
          Guid(BleUuids.telemetryService)
        )
      ).toList();
      
      _scanResultsController.add(vibeMonDevices);
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [Guid(BleUuids.telemetryService)],
    );
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _logger.i('BLE scan stopped');
  }

  /// Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _updateConnectionState(BleConnectionState.connecting);
      _logger.i('Connecting to ${device.platformName}...');

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _updateConnectionState(BleConnectionState.connected);
      _logger.i('Connected to ${device.platformName}');

      // Discover services and setup notifications
      await _setupServices(device);

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      return true;
    } catch (e) {
      _logger.e('Connection failed: $e');
      _updateConnectionState(BleConnectionState.disconnected);
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      _updateConnectionState(BleConnectionState.disconnecting);
      await _connectedDevice!.disconnect();
      _handleDisconnection();
    }
  }

  /// Setup services and enable notifications
  Future<void> _setupServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    
    for (final service in services) {
      if (service.uuid == Guid(BleUuids.telemetryService)) {
        for (final char in service.characteristics) {
          if (char.uuid == Guid(BleUuids.vibrationChar)) {
            // Enable notifications for telemetry data
            await char.setNotifyValue(true);
            char.onValueReceived.listen(_handleTelemetryData);
          }
        }
      }
    }
  }

  /// Handle incoming telemetry data
  void _handleTelemetryData(List<int> data) {
    if (data.length < 14) return;

    // Parse packet according to firmware format
    // [timestamp(4)] [accel_x(2)] [accel_y(2)] [accel_z(2)] [temp(2)] [battery(1)] [flags(1)]
    final timestamp = _bytesToInt32(data.sublist(0, 4));
    final accelX = _bytesToInt16(data.sublist(4, 6)) / 1000.0;
    final accelY = _bytesToInt16(data.sublist(6, 8)) / 1000.0;
    final accelZ = _bytesToInt16(data.sublist(8, 10)) / 1000.0;
    final temp = _bytesToInt16(data.sublist(10, 12)) / 100.0;
    final battery = data[12];
    final flags = data[13];

    final deviceData = BleDeviceData(
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
      temperature: temp,
      batteryLevel: battery,
      alertFlags: flags,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    );

    _dataController.add(deviceData);
  }

  /// Write command to device
  Future<void> writeCommand(int command, List<int> payload) async {
    if (_connectedDevice == null) return;

    final services = await _connectedDevice!.discoverServices();
    
    for (final service in services) {
      if (service.uuid == Guid(BleUuids.controlService)) {
        for (final char in service.characteristics) {
          if (char.uuid == Guid(BleUuids.commandChar)) {
            final data = [command, ...payload];
            await char.write(data);
            _logger.i('Command $command sent');
            return;
          }
        }
      }
    }
  }

  /// Set sample rate
  Future<void> setSampleRate(int intervalMs) async {
    final bytes = _int32ToBytes(intervalMs);
    await writeCommand(0x01, bytes);
  }

  /// Set vibration thresholds
  Future<void> setVibrationThresholds(double warning, double critical) async {
    final warningBytes = _floatToBytes(warning);
    final criticalBytes = _floatToBytes(critical);
    await writeCommand(0x02, [...warningBytes, ...criticalBytes]);
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _updateConnectionState(BleConnectionState.disconnected);
    _logger.i('Device disconnected');
  }

  void _updateConnectionState(BleConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  // Helper methods for byte conversion
  int _bytesToInt16(List<int> bytes) {
    return (bytes[1] << 8) | bytes[0];
  }

  int _bytesToInt32(List<int> bytes) {
    return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
  }

  List<int> _int32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  List<int> _floatToBytes(double value) {
    // Simple float encoding (multiply by 1000 and convert to int32)
    final intValue = (value * 1000).round();
    return _int32ToBytes(intValue);
  }

  /// Dispose resources
  void dispose() {
    _connectionStateController.close();
    _dataController.close();
    _scanResultsController.close();
  }
}
