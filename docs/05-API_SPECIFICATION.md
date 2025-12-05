# API Specification VibeMon

## 1. Общая информация

### 1.1 Base URL
```
Production: https://api.vibemon.io/v1
Staging: https://api-staging.vibemon.io/v1
Development: http://localhost:8000/v1
```

### 1.2 Аутентификация
```
Authorization: Bearer <access_token>
```

### 1.3 Content Type
```
Content-Type: application/json
```

### 1.4 Rate Limiting
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1638360000
```

---

## 2. Authentication API

### 2.1 Register

```http
POST /auth/register
```

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "first_name": "Иван",
  "last_name": "Петров",
  "organization_name": "Агрохолдинг",
  "phone": "+7 999 123-45-67"
}
```

**Response: 201 Created**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "first_name": "Иван",
  "last_name": "Петров",
  "organization": {
    "id": "660e8400-e29b-41d4-a716-446655440000",
    "name": "Агрохолдинг",
    "slug": "agroholding"
  },
  "role": "admin",
  "created_at": "2024-12-04T10:00:00Z"
}
```

### 2.2 Login

```http
POST /auth/login
```

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "device_info": {
    "platform": "android",
    "device_name": "Samsung Galaxy S21",
    "app_version": "1.0.0"
  }
}
```

**Response: 200 OK**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "first_name": "Иван",
    "last_name": "Петров",
    "role": "admin",
    "organization": {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "name": "Агрохолдинг"
    }
  }
}
```

### 2.3 Refresh Token

```http
POST /auth/refresh
```

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response: 200 OK**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600
}
```

### 2.4 Logout

```http
POST /auth/logout
Authorization: Bearer <token>
```

**Response: 204 No Content**

### 2.5 Password Reset Request

```http
POST /auth/password-reset
```

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response: 200 OK**
```json
{
  "message": "Инструкции отправлены на email"
}
```

---

## 3. Devices API

### 3.1 List Devices

```http
GET /devices
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| status | string | Filter by status (online, offline, error) |
| search | string | Search by name or serial |
| page | int | Page number (default: 1) |
| per_page | int | Items per page (default: 20, max: 100) |
| sort | string | Sort field (name, created_at, last_seen) |
| order | string | Sort order (asc, desc) |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440000",
      "serial_number": "VM-2024-001234",
      "mac_address": "AA:BB:CC:DD:EE:FF",
      "name": "Комбайн #1 - Двигатель",
      "device_type": "vibration_sensor",
      "firmware_version": "1.2.0",
      "status": "online",
      "last_seen": "2024-12-04T10:30:00Z",
      "battery_level": 85,
      "location": {
        "name": "Поле А-15",
        "latitude": 55.7558,
        "longitude": 37.6173
      },
      "equipment": {
        "type": "Комбайн",
        "model": "John Deere S780",
        "serial": "JD-2022-5678"
      },
      "latest_telemetry": {
        "rms_total": 2.45,
        "temperature_1": 45.5,
        "time": "2024-12-04T10:30:00Z"
      }
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 45,
    "total_pages": 3
  }
}
```

### 3.2 Get Device

```http
GET /devices/{device_id}
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440000",
  "serial_number": "VM-2024-001234",
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "name": "Комбайн #1 - Двигатель",
  "description": "Датчик вибрации на главном двигателе",
  "device_type": "vibration_sensor",
  "firmware_version": "1.2.0",
  "hardware_version": "1.0",
  "status": "online",
  "last_seen": "2024-12-04T10:30:00Z",
  "battery_level": 85,
  "location": {
    "name": "Поле А-15",
    "latitude": 55.7558,
    "longitude": 37.6173
  },
  "equipment": {
    "type": "Комбайн",
    "model": "John Deere S780",
    "serial": "JD-2022-5678"
  },
  "settings": {
    "sample_rate": 100,
    "send_interval": 1000,
    "sleep_enabled": false,
    "sleep_interval": 300
  },
  "thresholds": [
    {
      "metric": "rms_total",
      "warning_high": 5.0,
      "critical_high": 10.0,
      "enabled": true
    },
    {
      "metric": "temperature_1",
      "warning_high": 60.0,
      "critical_high": 80.0,
      "warning_low": -20.0,
      "critical_low": -40.0,
      "enabled": true
    }
  ],
  "created_at": "2024-06-15T08:00:00Z",
  "updated_at": "2024-12-04T10:00:00Z"
}
```

### 3.3 Register Device

```http
POST /devices
Authorization: Bearer <token>
```

**Request:**
```json
{
  "serial_number": "VM-2024-001234",
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "name": "Комбайн #1 - Двигатель",
  "description": "Датчик вибрации на главном двигателе",
  "location": {
    "name": "Поле А-15",
    "latitude": 55.7558,
    "longitude": 37.6173
  },
  "equipment": {
    "type": "Комбайн",
    "model": "John Deere S780",
    "serial": "JD-2022-5678"
  }
}
```

**Response: 201 Created**
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440000",
  "serial_number": "VM-2024-001234",
  "name": "Комбайн #1 - Двигатель",
  "status": "offline",
  "created_at": "2024-12-04T10:00:00Z"
}
```

### 3.4 Update Device

```http
PATCH /devices/{device_id}
Authorization: Bearer <token>
```

**Request:**
```json
{
  "name": "Комбайн #1 - Главный двигатель",
  "location": {
    "name": "Поле B-22"
  },
  "settings": {
    "sample_rate": 500
  }
}
```

**Response: 200 OK**

### 3.5 Delete Device

```http
DELETE /devices/{device_id}
Authorization: Bearer <token>
```

**Response: 204 No Content**

### 3.6 Update Device Thresholds

```http
PUT /devices/{device_id}/thresholds
Authorization: Bearer <token>
```

**Request:**
```json
{
  "thresholds": [
    {
      "metric": "rms_total",
      "warning_high": 6.0,
      "critical_high": 12.0,
      "enabled": true
    }
  ]
}
```

---

## 4. Telemetry API

### 4.1 Submit Telemetry (Batch)

```http
POST /telemetry
Authorization: Bearer <token>
```

**Request:**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "data": [
    {
      "time": "2024-12-04T10:30:00.000Z",
      "accel_x": 0.125,
      "accel_y": -0.045,
      "accel_z": 1.002,
      "rms_total": 2.45,
      "peak_to_peak": 5.12,
      "dominant_freq": 120,
      "temperature_1": 45.5,
      "temperature_2": 42.0,
      "battery_voltage": 3850,
      "packet_counter": 123456,
      "sample_rate": 100,
      "status_flags": 0
    },
    {
      "time": "2024-12-04T10:30:01.000Z",
      "accel_x": 0.130,
      "accel_y": -0.042,
      "accel_z": 1.005,
      "rms_total": 2.48,
      "peak_to_peak": 5.20,
      "dominant_freq": 120,
      "temperature_1": 45.6,
      "battery_voltage": 3848,
      "packet_counter": 123457
    }
  ]
}
```

**Response: 201 Created**
```json
{
  "received": 2,
  "stored": 2,
  "duplicates": 0
}
```

### 4.2 Get Telemetry

```http
GET /devices/{device_id}/telemetry
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| from | datetime | Start time (ISO 8601) |
| to | datetime | End time (ISO 8601) |
| metrics | string | Comma-separated metrics |
| resolution | string | Data resolution (raw, 1m, 5m, 1h, 1d) |
| limit | int | Max records (default: 1000) |

**Example:**
```http
GET /devices/{id}/telemetry?from=2024-12-04T00:00:00Z&to=2024-12-04T12:00:00Z&metrics=rms_total,temperature_1&resolution=1m
```

**Response: 200 OK**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "from": "2024-12-04T00:00:00Z",
  "to": "2024-12-04T12:00:00Z",
  "resolution": "1m",
  "data": [
    {
      "time": "2024-12-04T00:00:00Z",
      "rms_total": {
        "avg": 2.34,
        "min": 1.89,
        "max": 3.12
      },
      "temperature_1": {
        "avg": 42.5,
        "min": 41.0,
        "max": 44.0
      }
    },
    {
      "time": "2024-12-04T00:01:00Z",
      "rms_total": {
        "avg": 2.41,
        "min": 2.10,
        "max": 2.98
      },
      "temperature_1": {
        "avg": 42.8,
        "min": 41.5,
        "max": 44.2
      }
    }
  ],
  "meta": {
    "count": 720,
    "metrics": ["rms_total", "temperature_1"]
  }
}
```

### 4.3 Get Latest Telemetry

```http
GET /devices/{device_id}/telemetry/latest
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "time": "2024-12-04T10:30:00Z",
  "accel_x": 0.125,
  "accel_y": -0.045,
  "accel_z": 1.002,
  "rms_total": 2.45,
  "peak_to_peak": 5.12,
  "dominant_freq": 120,
  "temperature_1": 45.5,
  "temperature_2": 42.0,
  "battery_voltage": 3850
}
```

### 4.4 Get Statistics

```http
GET /devices/{device_id}/telemetry/stats
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| from | datetime | Start time |
| to | datetime | End time |
| metrics | string | Comma-separated metrics |

**Response: 200 OK**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "period": {
    "from": "2024-12-03T10:30:00Z",
    "to": "2024-12-04T10:30:00Z"
  },
  "stats": {
    "rms_total": {
      "avg": 2.45,
      "min": 0.85,
      "max": 8.92,
      "stddev": 1.23,
      "p50": 2.10,
      "p95": 5.45,
      "p99": 7.80
    },
    "temperature_1": {
      "avg": 45.5,
      "min": 25.0,
      "max": 68.5,
      "stddev": 8.5
    }
  },
  "sample_count": 86400
}
```

---

## 5. Alerts API

### 5.1 List Alerts

```http
GET /alerts
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| status | string | active, acknowledged, resolved |
| severity | string | info, warning, critical, emergency |
| device_id | uuid | Filter by device |
| from | datetime | Start time |
| to | datetime | End time |
| page | int | Page number |
| per_page | int | Items per page |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440000",
      "device": {
        "id": "770e8400-e29b-41d4-a716-446655440000",
        "name": "Комбайн #1 - Двигатель",
        "serial_number": "VM-2024-001234"
      },
      "alert_type": "vibration_high",
      "severity": "warning",
      "title": "Высокий уровень вибрации",
      "message": "RMS вибрации превысил порог: 6.5 g (порог: 5.0 g)",
      "metric_name": "rms_total",
      "metric_value": 6.5,
      "threshold_value": 5.0,
      "status": "active",
      "acknowledged": false,
      "created_at": "2024-12-04T10:25:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 15,
    "counts": {
      "active": 5,
      "acknowledged": 3,
      "resolved": 7
    }
  }
}
```

### 5.2 Get Alert

```http
GET /alerts/{alert_id}
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "id": "880e8400-e29b-41d4-a716-446655440000",
  "device": {
    "id": "770e8400-e29b-41d4-a716-446655440000",
    "name": "Комбайн #1 - Двигатель"
  },
  "alert_type": "vibration_high",
  "severity": "warning",
  "title": "Высокий уровень вибрации",
  "message": "RMS вибрации превысил порог",
  "metric_name": "rms_total",
  "metric_value": 6.5,
  "threshold_value": 5.0,
  "status": "active",
  "acknowledged": false,
  "acknowledged_by": null,
  "acknowledged_at": null,
  "resolved_at": null,
  "metadata": {
    "context_data": {
      "before": [2.1, 2.3, 2.5, 3.8, 5.2, 6.5],
      "trend": "increasing"
    }
  },
  "created_at": "2024-12-04T10:25:00Z"
}
```

### 5.3 Acknowledge Alert

```http
POST /alerts/{alert_id}/acknowledge
Authorization: Bearer <token>
```

**Request:**
```json
{
  "comment": "Проверим на месте"
}
```

**Response: 200 OK**
```json
{
  "id": "880e8400-e29b-41d4-a716-446655440000",
  "status": "acknowledged",
  "acknowledged": true,
  "acknowledged_by": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Иван Петров"
  },
  "acknowledged_at": "2024-12-04T10:30:00Z"
}
```

### 5.4 Resolve Alert

```http
POST /alerts/{alert_id}/resolve
Authorization: Bearer <token>
```

**Request:**
```json
{
  "resolution": "Заменён подшипник, вибрация в норме",
  "action_taken": "maintenance_performed"
}
```

---

## 6. Firmware API

### 6.1 List Firmwares

```http
GET /firmwares
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "990e8400-e29b-41d4-a716-446655440000",
      "version": "1.2.0",
      "version_code": 120,
      "file_size": 1048576,
      "hw_compatibility": ["1.0", "1.1"],
      "is_stable": true,
      "is_latest": true,
      "release_notes": "- Исправлена ошибка BLE\n- Оптимизировано энергопотребление",
      "created_at": "2024-12-01T12:00:00Z"
    }
  ]
}
```

### 6.2 Upload Firmware

```http
POST /firmwares
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Form Data:**
| Field | Type | Description |
|-------|------|-------------|
| file | file | Firmware binary (.bin) |
| version | string | Version (e.g., "1.2.0") |
| hw_compatibility | string | JSON array of HW versions |
| release_notes | string | Release notes (markdown) |
| is_stable | boolean | Mark as stable |

### 6.3 Download Firmware

```http
GET /firmwares/{firmware_id}/download
Authorization: Bearer <token>
```

**Response: 200 OK**
```
Content-Type: application/octet-stream
Content-Disposition: attachment; filename="firmware_1.2.0.bin"
X-Firmware-Checksum: abc123...
```

### 6.4 Initiate OTA Update

```http
POST /devices/{device_id}/firmware/update
Authorization: Bearer <token>
```

**Request:**
```json
{
  "firmware_id": "990e8400-e29b-41d4-a716-446655440000"
}
```

**Response: 202 Accepted**
```json
{
  "update_id": "aa0e8400-e29b-41d4-a716-446655440000",
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "firmware_version": "1.2.0",
  "status": "pending",
  "created_at": "2024-12-04T11:00:00Z"
}
```

### 6.5 Get OTA Update Status

```http
GET /devices/{device_id}/firmware/status
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "update_id": "aa0e8400-e29b-41d4-a716-446655440000",
  "status": "installing",
  "progress": 45,
  "from_version": "1.1.0",
  "to_version": "1.2.0",
  "started_at": "2024-12-04T11:00:30Z"
}
```

---

## 7. Analytics API

### 7.1 Get Anomaly Score

```http
GET /devices/{device_id}/analytics/anomaly
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| from | datetime | Start time |
| to | datetime | End time |

**Response: 200 OK**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "period": {
    "from": "2024-12-03T10:00:00Z",
    "to": "2024-12-04T10:00:00Z"
  },
  "current_score": 0.25,
  "health_status": "normal",
  "scores": [
    {
      "time": "2024-12-04T10:00:00Z",
      "score": 0.25,
      "is_anomaly": false
    },
    {
      "time": "2024-12-04T09:00:00Z",
      "score": 0.18,
      "is_anomaly": false
    }
  ],
  "anomalies_detected": 2,
  "model_info": {
    "type": "isolation_forest",
    "last_trained": "2024-12-01T00:00:00Z"
  }
}
```

### 7.2 Get Prediction

```http
GET /devices/{device_id}/analytics/prediction
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "prediction": {
    "failure_probability": 0.15,
    "estimated_rul_days": 45,
    "confidence": 0.78,
    "risk_level": "low"
  },
  "recommendations": [
    {
      "priority": "medium",
      "action": "Запланировать осмотр подшипника",
      "reason": "Незначительный рост вибрации за последнюю неделю"
    }
  ],
  "trend": {
    "rms_total": {
      "direction": "increasing",
      "rate": 0.05,
      "unit": "g/day"
    }
  },
  "generated_at": "2024-12-04T10:00:00Z"
}
```

### 7.3 Get FFT Analysis

```http
GET /devices/{device_id}/analytics/fft
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| time | datetime | Analysis timestamp |
| axis | string | x, y, z, or combined |

**Response: 200 OK**
```json
{
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "time": "2024-12-04T10:00:00Z",
  "axis": "combined",
  "sample_rate": 1000,
  "fft_size": 512,
  "frequency_resolution": 1.95,
  "spectrum": [
    {"frequency": 0, "magnitude": 0.02},
    {"frequency": 1.95, "magnitude": 0.05},
    {"frequency": 3.91, "magnitude": 0.12},
    {"frequency": 50.0, "magnitude": 0.85},
    {"frequency": 100.0, "magnitude": 1.45},
    {"frequency": 150.0, "magnitude": 0.32}
  ],
  "peaks": [
    {"frequency": 100.0, "magnitude": 1.45, "label": "2x RPM"},
    {"frequency": 50.0, "magnitude": 0.85, "label": "1x RPM"}
  ],
  "diagnosis": {
    "condition": "normal",
    "notes": "Характерный спектр для работающего двигателя"
  }
}
```

---

## 8. Reports API

### 8.1 Generate Report

```http
POST /reports
Authorization: Bearer <token>
```

**Request:**
```json
{
  "type": "device_summary",
  "format": "pdf",
  "device_ids": ["770e8400-e29b-41d4-a716-446655440000"],
  "period": {
    "from": "2024-11-01T00:00:00Z",
    "to": "2024-12-01T00:00:00Z"
  },
  "include_sections": ["overview", "alerts", "trends", "recommendations"]
}
```

**Response: 202 Accepted**
```json
{
  "report_id": "bb0e8400-e29b-41d4-a716-446655440000",
  "status": "generating",
  "estimated_time_seconds": 30
}
```

### 8.2 Get Report Status

```http
GET /reports/{report_id}
Authorization: Bearer <token>
```

**Response: 200 OK**
```json
{
  "report_id": "bb0e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "download_url": "https://api.vibemon.io/v1/reports/bb0e8400.../download",
  "expires_at": "2024-12-05T10:00:00Z"
}
```

---

## 9. WebSocket API

### 9.1 Connection

```
wss://api.vibemon.io/ws?token=<access_token>
```

### 9.2 Subscribe to Device

**Client -> Server:**
```json
{
  "type": "subscribe",
  "channel": "device",
  "device_id": "770e8400-e29b-41d4-a716-446655440000"
}
```

**Server -> Client:**
```json
{
  "type": "subscribed",
  "channel": "device",
  "device_id": "770e8400-e29b-41d4-a716-446655440000"
}
```

### 9.3 Telemetry Update

**Server -> Client:**
```json
{
  "type": "telemetry",
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "data": {
    "time": "2024-12-04T10:30:00Z",
    "rms_total": 2.45,
    "temperature_1": 45.5,
    "battery_voltage": 3850
  }
}
```

### 9.4 Alert Notification

**Server -> Client:**
```json
{
  "type": "alert",
  "alert": {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "device_id": "770e8400-e29b-41d4-a716-446655440000",
    "device_name": "Комбайн #1 - Двигатель",
    "severity": "warning",
    "title": "Высокий уровень вибрации",
    "created_at": "2024-12-04T10:25:00Z"
  }
}
```

### 9.5 Device Status Change

**Server -> Client:**
```json
{
  "type": "device_status",
  "device_id": "770e8400-e29b-41d4-a716-446655440000",
  "status": "online",
  "last_seen": "2024-12-04T10:30:00Z"
}
```

---

## 10. Error Responses

### 10.1 Error Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Ошибка валидации данных",
    "details": [
      {
        "field": "email",
        "message": "Неверный формат email"
      }
    ]
  }
}
```

### 10.2 Error Codes

| HTTP | Code | Description |
|------|------|-------------|
| 400 | VALIDATION_ERROR | Ошибка валидации |
| 400 | INVALID_REQUEST | Неверный запрос |
| 401 | UNAUTHORIZED | Не авторизован |
| 401 | TOKEN_EXPIRED | Токен истёк |
| 403 | FORBIDDEN | Доступ запрещён |
| 404 | NOT_FOUND | Ресурс не найден |
| 409 | CONFLICT | Конфликт (дубликат) |
| 422 | UNPROCESSABLE | Невозможно обработать |
| 429 | RATE_LIMITED | Превышен лимит запросов |
| 500 | INTERNAL_ERROR | Внутренняя ошибка |
| 503 | SERVICE_UNAVAILABLE | Сервис недоступен |

---

*Документ: API Specification VibeMon v1.0*
