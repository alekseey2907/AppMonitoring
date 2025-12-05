import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class ApiClient {
  late final Dio _dio;
  final Logger _logger = Logger();
  String? _authToken;

  ApiClient({String baseUrl = 'https://api.vibemon.io/v1'}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        _logger.d('REQUEST[${options.method}] => PATH: ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        _logger.e('ERROR[${error.response?.statusCode}] => PATH: ${error.requestOptions.path}');
        return handler.next(error);
      },
    ));
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  // ===============================
  // Auth Endpoints
  // ===============================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? organizationName,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
      'organization_name': organizationName,
    });
    return response.data;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    clearAuthToken();
  }

  // ===============================
  // Device Endpoints
  // ===============================

  Future<List<dynamic>> getDevices() async {
    final response = await _dio.get('/devices');
    return response.data['devices'];
  }

  Future<Map<String, dynamic>> getDevice(String deviceId) async {
    final response = await _dio.get('/devices/$deviceId');
    return response.data;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String macAddress,
    required String name,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.post('/devices', data: {
      'mac_address': macAddress,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
    });
    return response.data;
  }

  Future<void> updateDevice(String deviceId, Map<String, dynamic> data) async {
    await _dio.put('/devices/$deviceId', data: data);
  }

  Future<void> deleteDevice(String deviceId) async {
    await _dio.delete('/devices/$deviceId');
  }

  // ===============================
  // Telemetry Endpoints
  // ===============================

  Future<void> sendTelemetry(String deviceId, Map<String, dynamic> data) async {
    await _dio.post('/telemetry/$deviceId', data: data);
  }

  Future<void> sendTelemetryBatch(String deviceId, List<Map<String, dynamic>> batch) async {
    await _dio.post('/telemetry/$deviceId/batch', data: {'readings': batch});
  }

  Future<Map<String, dynamic>> getTelemetry(
    String deviceId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    final response = await _dio.get('/telemetry/$deviceId', queryParameters: {
      if (startTime != null) 'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime.toIso8601String(),
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTelemetryStats(
    String deviceId, {
    required String period,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final response = await _dio.get('/telemetry/$deviceId/stats', queryParameters: {
      'period': period,
      if (startTime != null) 'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime.toIso8601String(),
    });
    return response.data;
  }

  // ===============================
  // Alert Endpoints
  // ===============================

  Future<List<dynamic>> getAlerts({
    String? deviceId,
    String? status,
    String? severity,
    int limit = 50,
  }) async {
    final response = await _dio.get('/alerts', queryParameters: {
      if (deviceId != null) 'device_id': deviceId,
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      'limit': limit,
    });
    return response.data['alerts'];
  }

  Future<void> acknowledgeAlert(String alertId, {String? note}) async {
    await _dio.post('/alerts/$alertId/acknowledge', data: {
      if (note != null) 'note': note,
    });
  }

  Future<void> resolveAlert(String alertId, {String? resolution}) async {
    await _dio.post('/alerts/$alertId/resolve', data: {
      if (resolution != null) 'resolution': resolution,
    });
  }

  // ===============================
  // Analytics Endpoints
  // ===============================

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('/analytics/dashboard');
    return response.data;
  }

  Future<Map<String, dynamic>> getAnomalyDetection(String deviceId) async {
    final response = await _dio.get('/analytics/anomaly/$deviceId');
    return response.data;
  }

  Future<Map<String, dynamic>> getPrediction(String deviceId) async {
    final response = await _dio.get('/analytics/prediction/$deviceId');
    return response.data;
  }

  // ===============================
  // Firmware/OTA Endpoints
  // ===============================

  Future<Map<String, dynamic>> checkFirmwareUpdate(String deviceId, String currentVersion) async {
    final response = await _dio.get('/firmwares/check', queryParameters: {
      'device_id': deviceId,
      'current_version': currentVersion,
    });
    return response.data;
  }

  Future<List<int>> downloadFirmware(String firmwareId) async {
    final response = await _dio.get(
      '/firmwares/$firmwareId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }
}
