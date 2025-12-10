import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// WiFi TCP/IP провайдер для подключения к VibeMon через WiFi
class WiFiProvider extends ChangeNotifier {
  Socket? _socket;
  bool _isConnected = false;
  String _lastError = '';
  
  // Параметры подключения
  static const String defaultHost = '192.168.4.1';
  static const int defaultPort = 8888;
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  // Данные от устройства
  double _temperature = 0.0;
  VibrationDataFull? _vibrationData;
  List<double> _spectrum = List.filled(8, 0.0);
  String _statusJson = '';
  
  // Геттеры
  bool get isConnected => _isConnected;
  String get lastError => _lastError;
  double get temperature => _temperature;
  VibrationDataFull? get vibrationData => _vibrationData;
  List<double> get spectrum => _spectrum;
  String get statusJson => _statusJson;
  
  // Стрим для данных
  final StreamController<VibrationDataFull> _dataStreamController = 
      StreamController<VibrationDataFull>.broadcast();
  Stream<VibrationDataFull> get dataStream => _dataStreamController.stream;
  
  /// Подключение к устройству
  Future<bool> connect({String? host, int? port}) async {
    try {
      final connectHost = host ?? defaultHost;
      final connectPort = port ?? defaultPort;
      
      _lastError = '';
      notifyListeners();
      
      print('🔌 Подключение к $connectHost:$connectPort...');
      
      _socket = await Socket.connect(
        connectHost,
        connectPort,
        timeout: connectionTimeout,
      );
      
      _isConnected = true;
      print('✓ WiFi подключение установлено');
      
      // Слушаем данные
      _socket!.listen(
        _handleData,
        onError: (error) {
          print('❌ Ошибка WiFi: $error');
          _lastError = error.toString();
          disconnect();
        },
        onDone: () {
          print('✗ WiFi соединение закрыто');
          disconnect();
        },
        cancelOnError: false,
      );
      
      notifyListeners();
      return true;
      
    } catch (e) {
      print('❌ Ошибка подключения WiFi: $e');
      _lastError = e.toString();
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Отключение от устройства
  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (e) {
      print('Ошибка при закрытии сокета: $e');
    }
    
    _socket = null;
    _isConnected = false;
    _lastError = '';
    notifyListeners();
  }
  
  /// Обработка входящих данных
  void _handleData(Uint8List data) {
    try {
      // Ищем заголовок пакета "VIBE" (0x56 0x49 0x42 0x45)
      int headerIndex = -1;
      for (int i = 0; i < data.length - 3; i++) {
        if (data[i] == 0x56 && data[i+1] == 0x49 && 
            data[i+2] == 0x42 && data[i+3] == 0x45) {
          headerIndex = i;
          break;
        }
      }
      
      if (headerIndex == -1) {
        // Может быть JSON строка
        String jsonStr = String.fromCharCodes(data);
        if (jsonStr.contains('{') && jsonStr.contains('}')) {
          _statusJson = jsonStr.trim();
          notifyListeners();
        }
        return;
      }
      
      // Парсим бинарные данные
      final bytes = ByteData.sublistView(data, headerIndex + 4);
      
      if (bytes.lengthInBytes < 68) {
        print('⚠ Недостаточно данных: ${bytes.lengthInBytes} байт');
        return;
      }
      
      int offset = 0;
      
      // Температура (4 байта)
      _temperature = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      
      // VibrationData (32 байта)
      final rms = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final rmsVelocity = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final peak = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final peakToPeak = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final crestFactor = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final dominantFreq = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final dominantAmp = bytes.getFloat32(offset, Endian.little);
      offset += 4;
      final status = bytes.getUint8(offset);
      offset += 1;
      
      // Выравнивание (3 байта padding для структуры)
      offset += 3;
      
      _vibrationData = VibrationDataFull(
        rms: rms,
        rmsVelocity: rmsVelocity,
        peak: peak,
        peakToPeak: peakToPeak,
        crestFactor: crestFactor,
        dominantFreq: dominantFreq,
        dominantAmp: dominantAmp,
        status: status,
      );
      
      // Спектр (32 байта = 8 float)
      if (bytes.lengthInBytes >= offset + 32) {
        for (int i = 0; i < 8; i++) {
          _spectrum[i] = bytes.getFloat32(offset, Endian.little);
          offset += 4;
        }
      }
      
      // Отправляем в стрим
      if (_vibrationData != null) {
        _dataStreamController.add(_vibrationData!);
      }
      
      notifyListeners();
      
    } catch (e) {
      print('❌ Ошибка парсинга данных: $e');
    }
  }
  
  /// Отправка команды устройству
  Future<bool> sendCommand(int command) async {
    if (!_isConnected || _socket == null) {
      print('❌ Нет подключения для отправки команды');
      return false;
    }
    
    try {
      _socket!.add([command]);
      await _socket!.flush();
      print('✓ Команда 0x${command.toRadixString(16)} отправлена');
      return true;
    } catch (e) {
      print('❌ Ошибка отправки команды: $e');
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  /// Перекалибровка датчика
  Future<bool> recalibrateDevice() => sendCommand(0x01);
  
  /// Сброс настроек
  Future<bool> resetSettings() => sendCommand(0x02);
  
  /// Перезагрузка устройства
  Future<bool> restartDevice() => sendCommand(0x03);
  
  @override
  void dispose() {
    disconnect();
    _dataStreamController.close();
    super.dispose();
  }
}

/// Полные данные вибрации
class VibrationDataFull {
  final double rms;
  final double rmsVelocity;
  final double peak;
  final double peakToPeak;
  final double crestFactor;
  final double dominantFreq;
  final double dominantAmp;
  final int status;
  
  VibrationDataFull({
    required this.rms,
    required this.rmsVelocity,
    required this.peak,
    required this.peakToPeak,
    required this.crestFactor,
    required this.dominantFreq,
    required this.dominantAmp,
    required this.status,
  });
  
  String get statusText {
    switch (status) {
      case 0: return 'Good';
      case 1: return 'Acceptable';
      case 2: return 'Alarm';
      case 3: return 'Danger';
      default: return 'Unknown';
    }
  }
}
