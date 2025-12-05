# ER-диаграмма базы данных VibeMon

## 1. Обзор структуры

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              DATABASE SCHEMA                                          │
│                              (TimescaleDB)                                            │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐            │
│   │  organizations  │       │     users       │       │    devices      │            │
│   ├─────────────────┤       ├─────────────────┤       ├─────────────────┤            │
│   │ PK id           │◄──┐   │ PK id           │   ┌──►│ PK id           │            │
│   │    name         │   │   │ FK org_id       │───┘   │ FK org_id       │────┐       │
│   │    slug         │   └───│    email        │       │    serial_num   │    │       │
│   │    settings     │       │    password     │       │    name         │    │       │
│   │    created_at   │       │    role         │       │    mac_address  │    │       │
│   │    updated_at   │       │    created_at   │       │    firmware_ver │    │       │
│   └─────────────────┘       └─────────────────┘       │    status       │    │       │
│                                                        │    last_seen    │    │       │
│                                                        │    created_at   │    │       │
│                                                        └─────────────────┘    │       │
│                                                               │               │       │
│                     ┌─────────────────────────────────────────┤               │       │
│                     │                                         │               │       │
│                     ▼                                         ▼               │       │
│   ┌─────────────────────────────┐       ┌─────────────────────────────┐      │       │
│   │   telemetry (hypertable)    │       │        alerts               │      │       │
│   ├─────────────────────────────┤       ├─────────────────────────────┤      │       │
│   │ PK time                     │       │ PK id                       │      │       │
│   │ FK device_id                │───────│ FK device_id                │◄─────┘       │
│   │    accel_x                  │       │    type                     │              │
│   │    accel_y                  │       │    severity                 │              │
│   │    accel_z                  │       │    message                  │              │
│   │    rms                      │       │    value                    │              │
│   │    temperature              │       │    threshold                │              │
│   │    battery_voltage          │       │    acknowledged             │              │
│   │    packet_counter           │       │    created_at               │              │
│   └─────────────────────────────┘       └─────────────────────────────┘              │
│                                                                                       │
│   ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐            │
│   │    firmwares    │       │   thresholds    │       │   audit_logs    │            │
│   ├─────────────────┤       ├─────────────────┤       ├─────────────────┤            │
│   │ PK id           │       │ PK id           │       │ PK id           │            │
│   │    version      │       │ FK device_id    │       │ FK user_id      │            │
│   │    filename     │       │    metric       │       │    action       │            │
│   │    file_path    │       │    warn_low     │       │    entity_type  │            │
│   │    checksum     │       │    warn_high    │       │    entity_id    │            │
│   │    size_bytes   │       │    crit_low     │       │    old_value    │            │
│   │    hw_compat    │       │    crit_high    │       │    new_value    │            │
│   │    release_notes│       │    enabled      │       │    ip_address   │            │
│   │    created_at   │       │    created_at   │       │    created_at   │            │
│   └─────────────────┘       └─────────────────┘       └─────────────────┘            │
│                                                                                       │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## 2. Детальная схема таблиц

### 2.1 organizations (Организации)

```sql
CREATE TABLE organizations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(100) UNIQUE NOT NULL,
    description     TEXT,
    logo_url        VARCHAR(500),
    settings        JSONB DEFAULT '{}',
    subscription    VARCHAR(50) DEFAULT 'free',
    max_devices     INTEGER DEFAULT 5,
    max_users       INTEGER DEFAULT 3,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_subscription ON organizations(subscription);
```

### 2.2 users (Пользователи)

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(20),
    role            VARCHAR(50) DEFAULT 'operator',
    permissions     JSONB DEFAULT '[]',
    avatar_url      VARCHAR(500),
    is_active       BOOLEAN DEFAULT TRUE,
    email_verified  BOOLEAN DEFAULT FALSE,
    last_login      TIMESTAMPTZ,
    telegram_id     BIGINT,
    notification_settings JSONB DEFAULT '{
        "email": true,
        "push": true,
        "telegram": false
    }',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_org_id ON users(org_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Роли: admin, manager, operator, viewer
```

### 2.3 devices (Устройства)

```sql
CREATE TABLE devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    serial_number   VARCHAR(50) UNIQUE NOT NULL,
    mac_address     VARCHAR(17) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    device_type     VARCHAR(50) DEFAULT 'vibration_sensor',
    firmware_version VARCHAR(20),
    hardware_version VARCHAR(20),
    
    -- Локация
    location_name   VARCHAR(255),
    latitude        DECIMAL(10, 8),
    longitude       DECIMAL(11, 8),
    
    -- Метаданные оборудования
    equipment_type  VARCHAR(100),
    equipment_model VARCHAR(100),
    equipment_serial VARCHAR(100),
    
    -- Статус
    status          VARCHAR(50) DEFAULT 'offline',
    last_seen       TIMESTAMPTZ,
    battery_level   INTEGER,
    
    -- Настройки
    settings        JSONB DEFAULT '{
        "sample_rate": 100,
        "send_interval": 1000,
        "sleep_enabled": false,
        "sleep_interval": 300
    }',
    
    -- Служебные
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_devices_org_id ON devices(org_id);
CREATE INDEX idx_devices_serial ON devices(serial_number);
CREATE INDEX idx_devices_mac ON devices(mac_address);
CREATE INDEX idx_devices_status ON devices(status);
CREATE INDEX idx_devices_location ON devices USING GIST (
    ST_MakePoint(longitude, latitude)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
```

### 2.4 telemetry (Телеметрия - Hypertable)

```sql
CREATE TABLE telemetry (
    time            TIMESTAMPTZ NOT NULL,
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    -- Вибрация
    accel_x         REAL,
    accel_y         REAL,
    accel_z         REAL,
    rms_total       REAL,
    peak_to_peak    REAL,
    dominant_freq   SMALLINT,
    
    -- Температура
    temperature_1   REAL,
    temperature_2   REAL,
    
    -- Питание
    battery_voltage SMALLINT,
    
    -- Метаданные
    packet_counter  BIGINT,
    sample_rate     SMALLINT,
    status_flags    SMALLINT,
    
    -- Для дедупликации
    UNIQUE (time, device_id, packet_counter)
);

-- Превращаем в hypertable (TimescaleDB)
SELECT create_hypertable('telemetry', 'time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Включаем сжатие для старых данных
ALTER TABLE telemetry SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Политика сжатия: сжимать данные старше 7 дней
SELECT add_compression_policy('telemetry', INTERVAL '7 days');

-- Политика удаления: удалять данные старше 1 года
SELECT add_retention_policy('telemetry', INTERVAL '1 year');

-- Индексы
CREATE INDEX idx_telemetry_device_time ON telemetry (device_id, time DESC);
CREATE INDEX idx_telemetry_rms ON telemetry (rms_total) WHERE rms_total > 0;
```

### 2.5 Continuous Aggregates (Агрегаты)

```sql
-- Почасовая статистика
CREATE MATERIALIZED VIEW telemetry_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    device_id,
    AVG(accel_x) AS avg_accel_x,
    AVG(accel_y) AS avg_accel_y,
    AVG(accel_z) AS avg_accel_z,
    AVG(rms_total) AS avg_rms,
    MAX(rms_total) AS max_rms,
    MIN(rms_total) AS min_rms,
    AVG(temperature_1) AS avg_temp,
    MAX(temperature_1) AS max_temp,
    MIN(temperature_1) AS min_temp,
    AVG(battery_voltage) AS avg_battery,
    COUNT(*) AS sample_count
FROM telemetry
GROUP BY bucket, device_id
WITH NO DATA;

-- Политика обновления агрегата
SELECT add_continuous_aggregate_policy('telemetry_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Дневная статистика
CREATE MATERIALIZED VIEW telemetry_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', time) AS bucket,
    device_id,
    AVG(rms_total) AS avg_rms,
    MAX(rms_total) AS max_rms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY rms_total) AS p95_rms,
    AVG(temperature_1) AS avg_temp,
    MAX(temperature_1) AS max_temp,
    MIN(temperature_1) AS min_temp,
    COUNT(*) AS sample_count
FROM telemetry
GROUP BY bucket, device_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('telemetry_daily',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);
```

### 2.6 alerts (Предупреждения)

```sql
CREATE TABLE alerts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    alert_type      VARCHAR(50) NOT NULL,
    severity        VARCHAR(20) NOT NULL,
    
    metric_name     VARCHAR(50),
    metric_value    REAL,
    threshold_value REAL,
    
    title           VARCHAR(255) NOT NULL,
    message         TEXT,
    
    -- Статус
    status          VARCHAR(20) DEFAULT 'active',
    acknowledged    BOOLEAN DEFAULT FALSE,
    acknowledged_by UUID REFERENCES users(id),
    acknowledged_at TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ,
    
    -- Метаданные
    metadata        JSONB DEFAULT '{}',
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_alerts_device ON alerts(device_id, created_at DESC);
CREATE INDEX idx_alerts_status ON alerts(status) WHERE status = 'active';
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_type ON alerts(alert_type);

-- Типы алертов: vibration_high, vibration_anomaly, temperature_high, 
--               temperature_low, battery_low, device_offline, sensor_error

-- Severity: info, warning, critical, emergency
```

### 2.7 thresholds (Пороговые значения)

```sql
CREATE TABLE thresholds (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    metric_name     VARCHAR(50) NOT NULL,
    
    warning_low     REAL,
    warning_high    REAL,
    critical_low    REAL,
    critical_high   REAL,
    
    enabled         BOOLEAN DEFAULT TRUE,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE (device_id, metric_name)
);

CREATE INDEX idx_thresholds_device ON thresholds(device_id);

-- Метрики: rms_total, temperature_1, temperature_2, battery_voltage, dominant_freq
```

### 2.8 firmwares (Прошивки)

```sql
CREATE TABLE firmwares (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    version         VARCHAR(20) NOT NULL,
    version_code    INTEGER NOT NULL,
    
    filename        VARCHAR(255) NOT NULL,
    file_path       VARCHAR(500) NOT NULL,
    checksum_md5    VARCHAR(32) NOT NULL,
    checksum_sha256 VARCHAR(64) NOT NULL,
    file_size       INTEGER NOT NULL,
    
    hw_compatibility JSONB DEFAULT '["1.0"]',
    
    release_notes   TEXT,
    is_stable       BOOLEAN DEFAULT FALSE,
    is_latest       BOOLEAN DEFAULT FALSE,
    
    download_count  INTEGER DEFAULT 0,
    
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_firmwares_version ON firmwares(version);
CREATE INDEX idx_firmwares_latest ON firmwares(is_latest) WHERE is_latest = TRUE;
```

### 2.9 device_firmware_updates (История обновлений)

```sql
CREATE TABLE device_firmware_updates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    firmware_id     UUID NOT NULL REFERENCES firmwares(id),
    
    from_version    VARCHAR(20),
    to_version      VARCHAR(20) NOT NULL,
    
    status          VARCHAR(20) DEFAULT 'pending',
    progress        INTEGER DEFAULT 0,
    
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    
    error_message   TEXT,
    
    initiated_by    UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fw_updates_device ON device_firmware_updates(device_id);
CREATE INDEX idx_fw_updates_status ON device_firmware_updates(status);

-- Status: pending, downloading, installing, completed, failed
```

### 2.10 audit_logs (Журнал аудита)

```sql
CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    user_id         UUID REFERENCES users(id),
    org_id          UUID REFERENCES organizations(id),
    
    action          VARCHAR(50) NOT NULL,
    entity_type     VARCHAR(50) NOT NULL,
    entity_id       UUID,
    
    old_value       JSONB,
    new_value       JSONB,
    
    ip_address      INET,
    user_agent      TEXT,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Превращаем в hypertable для эффективного хранения
SELECT create_hypertable('audit_logs', 'created_at',
    chunk_time_interval => INTERVAL '1 month'
);

CREATE INDEX idx_audit_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_org ON audit_logs(org_id, created_at DESC);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);

-- Actions: create, update, delete, login, logout, etc.
-- Entity types: device, user, alert, threshold, firmware, etc.
```

### 2.11 refresh_tokens (Токены обновления)

```sql
CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    token_hash      VARCHAR(64) NOT NULL UNIQUE,
    
    device_info     JSONB,
    ip_address      INET,
    
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked         BOOLEAN DEFAULT FALSE,
    revoked_at      TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at) 
    WHERE revoked = FALSE;
```

### 2.12 notifications (Уведомления)

```sql
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    alert_id        UUID REFERENCES alerts(id) ON DELETE SET NULL,
    
    channel         VARCHAR(20) NOT NULL,
    
    title           VARCHAR(255) NOT NULL,
    body            TEXT NOT NULL,
    
    status          VARCHAR(20) DEFAULT 'pending',
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    read_at         TIMESTAMPTZ,
    
    error_message   TEXT,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_status ON notifications(status) 
    WHERE status = 'pending';

-- Channels: email, push, telegram
-- Status: pending, sent, delivered, failed
```

### 2.13 ml_models (ML Модели)

```sql
CREATE TABLE ml_models (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID REFERENCES devices(id) ON DELETE SET NULL,
    
    model_type      VARCHAR(50) NOT NULL,
    model_name      VARCHAR(100) NOT NULL,
    
    model_path      VARCHAR(500) NOT NULL,
    model_params    JSONB DEFAULT '{}',
    
    training_data_from TIMESTAMPTZ,
    training_data_to   TIMESTAMPTZ,
    training_samples   INTEGER,
    
    metrics         JSONB DEFAULT '{}',
    
    is_active       BOOLEAN DEFAULT FALSE,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ml_models_device ON ml_models(device_id);
CREATE INDEX idx_ml_models_active ON ml_models(is_active, device_id) 
    WHERE is_active = TRUE;

-- Model types: anomaly_detection, predictive_maintenance, fault_classification
```

### 2.14 anomaly_scores (Оценки аномалий)

```sql
CREATE TABLE anomaly_scores (
    time            TIMESTAMPTZ NOT NULL,
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    model_id        UUID NOT NULL REFERENCES ml_models(id) ON DELETE CASCADE,
    
    score           REAL NOT NULL,
    is_anomaly      BOOLEAN DEFAULT FALSE,
    
    features        JSONB,
    explanation     TEXT
);

SELECT create_hypertable('anomaly_scores', 'time',
    chunk_time_interval => INTERVAL '1 day'
);

CREATE INDEX idx_anomaly_device_time ON anomaly_scores(device_id, time DESC);
CREATE INDEX idx_anomaly_detected ON anomaly_scores(device_id, time DESC) 
    WHERE is_anomaly = TRUE;
```

## 3. Связи между таблицами

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           ENTITY RELATIONSHIP DIAGRAM                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                              organizations                                           │
│                                    │                                                 │
│                    ┌───────────────┼───────────────┐                                │
│                    │               │               │                                │
│                    ▼               ▼               ▼                                │
│                 users          devices        audit_logs                            │
│                    │               │                                                 │
│         ┌──────────┤               ├──────────────┬──────────────┐                  │
│         │          │               │              │              │                  │
│         ▼          ▼               ▼              ▼              ▼                  │
│   refresh_tokens  notifications  telemetry    alerts       thresholds              │
│                    │                                             │                  │
│                    │               ┌─────────────────────────────┘                  │
│                    │               │                                                 │
│                    ▼               ▼                                                │
│              ┌──────────────────────────┐                                           │
│              │     ML Processing        │                                           │
│              │  ┌────────┐  ┌────────┐  │                                           │
│              │  │ml_models│  │anomaly_│  │                                           │
│              │  │        │  │scores  │  │                                           │
│              │  └────────┘  └────────┘  │                                           │
│              └──────────────────────────┘                                           │
│                                                                                      │
│                              firmwares                                               │
│                                  │                                                   │
│                                  ▼                                                   │
│                     device_firmware_updates                                          │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 4. Типичные запросы

### 4.1 Получение последних данных устройства

```sql
SELECT 
    time,
    accel_x, accel_y, accel_z,
    rms_total,
    temperature_1,
    battery_voltage
FROM telemetry
WHERE device_id = $1
ORDER BY time DESC
LIMIT 100;
```

### 4.2 Статистика за период

```sql
SELECT 
    bucket,
    avg_rms,
    max_rms,
    avg_temp,
    sample_count
FROM telemetry_hourly
WHERE device_id = $1
  AND bucket >= NOW() - INTERVAL '24 hours'
ORDER BY bucket;
```

### 4.3 Активные алерты организации

```sql
SELECT 
    a.id,
    a.alert_type,
    a.severity,
    a.title,
    a.created_at,
    d.name as device_name,
    d.location_name
FROM alerts a
JOIN devices d ON a.device_id = d.id
WHERE d.org_id = $1
  AND a.status = 'active'
ORDER BY 
    CASE a.severity 
        WHEN 'emergency' THEN 1
        WHEN 'critical' THEN 2
        WHEN 'warning' THEN 3
        ELSE 4
    END,
    a.created_at DESC;
```

### 4.4 Проверка порогов и создание алерта

```sql
WITH latest_data AS (
    SELECT 
        device_id,
        rms_total,
        temperature_1,
        battery_voltage
    FROM telemetry
    WHERE time > NOW() - INTERVAL '1 minute'
),
threshold_violations AS (
    SELECT 
        ld.device_id,
        t.metric_name,
        CASE 
            WHEN t.metric_name = 'rms_total' AND ld.rms_total > t.critical_high THEN 'critical'
            WHEN t.metric_name = 'rms_total' AND ld.rms_total > t.warning_high THEN 'warning'
            WHEN t.metric_name = 'temperature_1' AND ld.temperature_1 > t.critical_high THEN 'critical'
            WHEN t.metric_name = 'temperature_1' AND ld.temperature_1 > t.warning_high THEN 'warning'
        END as severity,
        CASE 
            WHEN t.metric_name = 'rms_total' THEN ld.rms_total
            WHEN t.metric_name = 'temperature_1' THEN ld.temperature_1
        END as value,
        COALESCE(t.critical_high, t.warning_high) as threshold
    FROM latest_data ld
    JOIN thresholds t ON ld.device_id = t.device_id
    WHERE t.enabled = TRUE
)
INSERT INTO alerts (device_id, alert_type, severity, metric_name, metric_value, threshold_value, title, message)
SELECT 
    device_id,
    metric_name || '_high',
    severity,
    metric_name,
    value,
    threshold,
    CASE metric_name
        WHEN 'rms_total' THEN 'Высокий уровень вибрации'
        WHEN 'temperature_1' THEN 'Высокая температура'
    END,
    'Значение ' || value || ' превысило порог ' || threshold
FROM threshold_violations
WHERE severity IS NOT NULL;
```

---

*Документ: ER-диаграмма базы данных VibeMon v1.0*
