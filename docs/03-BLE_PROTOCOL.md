# BLE Протокол VibeMon

## 1. Общая информация

### 1.1 Параметры BLE

| Параметр | Значение |
|----------|----------|
| Версия BLE | 5.0 |
| Режим | Peripheral (Slave) |
| MTU | 247 байт (по умолчанию 23) |
| Connection Interval | 15-30 мс |
| Slave Latency | 0 |
| Supervision Timeout | 4000 мс |
| TX Power | 0 dBm (настраиваемый) |

### 1.2 Advertising

```
Advertising Interval: 100-500 мс (настраиваемый)
Advertising Data:
  - Flags: 0x06 (LE General Discoverable, BR/EDR Not Supported)
  - Complete Local Name: "VibeMon-XXXX" (где XXXX - последние 4 цифры MAC)
  - Manufacturer Data: 
    - Company ID: 0xFFFF (для разработки) или зарегистрированный
    - Device Type: 1 byte
    - Firmware Version: 2 bytes
    - Battery Level: 1 byte
    - Status Flags: 1 byte

Scan Response Data:
  - Complete List of 128-bit Service UUIDs
```

---

## 2. GATT Service Structure

### 2.1 Device Information Service (Standard)
**UUID:** `0x180A`

| Characteristic | UUID | Properties | Description |
|---------------|------|------------|-------------|
| Manufacturer Name | 0x2A29 | Read | "VibeMon" |
| Model Number | 0x2A24 | Read | "VM-ESP32-V1" |
| Serial Number | 0x2A25 | Read | Уникальный ID устройства |
| Hardware Revision | 0x2A27 | Read | "1.0" |
| Firmware Revision | 0x2A26 | Read | "1.0.0" |
| Software Revision | 0x2A28 | Read | "1.0.0" |

### 2.2 Battery Service (Standard)
**UUID:** `0x180F`

| Characteristic | UUID | Properties | Description |
|---------------|------|------------|-------------|
| Battery Level | 0x2A19 | Read, Notify | 0-100% |

### 2.3 VibeMon Telemetry Service (Custom)
**UUID:** `A0000001-0000-1000-8000-00805F9B34FB`

| Characteristic | UUID | Properties | Description |
|---------------|------|------------|-------------|
| Vibration Data | A0000002-... | Read, Notify | Данные вибрации |
| Temperature Data | A0000003-... | Read, Notify | Данные температуры |
| Combined Data | A0000004-... | Notify | Комбинированный пакет |
| Sampling Config | A0000005-... | Read, Write | Настройки семплирования |
| Alert Thresholds | A0000006-... | Read, Write | Пороги предупреждений |

### 2.4 VibeMon Control Service (Custom)
**UUID:** `B0000001-0000-1000-8000-00805F9B34FB`

| Characteristic | UUID | Properties | Description |
|---------------|------|------------|-------------|
| Device Status | B0000002-... | Read, Notify | Статус устройства |
| Command | B0000003-... | Write | Команды управления |
| Response | B0000004-... | Read, Notify | Ответы на команды |
| Time Sync | B0000005-... | Write | Синхронизация времени |
| Sleep Config | B0000006-... | Read, Write | Настройки сна |

### 2.5 VibeMon OTA Service (Custom)
**UUID:** `C0000001-0000-1000-8000-00805F9B34FB`

| Characteristic | UUID | Properties | Description |
|---------------|------|------------|-------------|
| OTA Control | C0000002-... | Write, Notify | Управление OTA |
| OTA Data | C0000003-... | Write Without Response | Передача прошивки |
| OTA Status | C0000004-... | Read, Notify | Статус обновления |

---

## 3. Структура пакетов данных

### 3.1 Vibration Data Packet (20 bytes)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        VIBRATION DATA PACKET                                │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Packet Type (0x01 = Vibration)                         │
│  1-4    │  4      │  Timestamp (Unix time, seconds)                         │
│  5-6    │  2      │  Milliseconds (0-999)                                   │
│  7-8    │  2      │  Accel X (int16, scale: 0.001 g)                        │
│  9-10   │  2      │  Accel Y (int16, scale: 0.001 g)                        │
│  11-12  │  2      │  Accel Z (int16, scale: 0.001 g)                        │
│  13-14  │  2      │  RMS Total (uint16, scale: 0.001 g)                     │
│  15-16  │  2      │  Peak-to-Peak (uint16, scale: 0.001 g)                  │
│  17     │  1      │  Dominant Frequency (0-255 Hz)                          │
│  18     │  1      │  Sample Rate Code (0=100Hz, 1=500Hz, 2=1000Hz)          │
│  19     │  1      │  Status Flags                                           │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘

Status Flags (Byte 19):
  Bit 0: Buffer overflow warning
  Bit 1: Sensor error
  Bit 2: High vibration alert
  Bit 3: Reserved
  Bit 4-7: Sequence number (0-15)
```

### 3.2 Temperature Data Packet (12 bytes)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       TEMPERATURE DATA PACKET                               │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Packet Type (0x02 = Temperature)                       │
│  1-4    │  4      │  Timestamp (Unix time, seconds)                         │
│  5-6    │  2      │  Milliseconds (0-999)                                   │
│  7-8    │  2      │  Temperature (int16, scale: 0.0625 °C)                  │
│  9      │  1      │  Sensor ID (supports multiple sensors)                  │
│  10     │  1      │  Status Flags                                           │
│  11     │  1      │  Reserved                                               │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘

Status Flags (Byte 10):
  Bit 0: Sensor error
  Bit 1: High temperature alert
  Bit 2: Low temperature alert
  Bit 3-7: Reserved
```

### 3.3 Combined Data Packet (32 bytes)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMBINED DATA PACKET                                  │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Packet Type (0x03 = Combined)                          │
│  1-4    │  4      │  Timestamp (Unix time, seconds)                         │
│  5-6    │  2      │  Milliseconds (0-999)                                   │
│  7-8    │  2      │  Accel X (int16, scale: 0.001 g)                        │
│  9-10   │  2      │  Accel Y (int16, scale: 0.001 g)                        │
│  11-12  │  2      │  Accel Z (int16, scale: 0.001 g)                        │
│  13-14  │  2      │  RMS Total (uint16, scale: 0.001 g)                     │
│  15-16  │  2      │  Peak-to-Peak (uint16, scale: 0.001 g)                  │
│  17     │  1      │  Dominant Frequency (0-255 Hz)                          │
│  18-19  │  2      │  Temperature 1 (int16, scale: 0.0625 °C)                │
│  20-21  │  2      │  Temperature 2 (int16, optional)                        │
│  22-23  │  2      │  Battery Voltage (uint16, mV)                           │
│  24-27  │  4      │  Packet Counter (uint32)                                │
│  28-29  │  2      │  CRC16                                                  │
│  30-31  │  2      │  Reserved                                               │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

### 3.4 FFT Data Packet (Variable, up to 244 bytes with MTU=247)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          FFT DATA PACKET                                    │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Packet Type (0x04 = FFT)                               │
│  1-4    │  4      │  Timestamp (Unix time, seconds)                         │
│  5      │  1      │  Axis (0=X, 1=Y, 2=Z, 3=Combined)                       │
│  6      │  1      │  FFT Size (64, 128, 256, 512)                           │
│  7      │  1      │  Packet Number (for fragmentation)                      │
│  8      │  1      │  Total Packets                                          │
│  9      │  1      │  Bin Count in this packet                               │
│  10-11  │  2      │  Start Bin Index                                        │
│  12-N   │ 2*bins  │  Magnitude values (uint16, normalized)                  │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

---

## 4. Команды управления

### 4.1 Command Packet Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMMAND PACKET                                      │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Command ID                                             │
│  1      │  1      │  Payload Length                                         │
│  2-N    │  Var    │  Payload Data                                           │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

### 4.2 Command List

| ID | Command | Payload | Description |
|----|---------|---------|-------------|
| 0x01 | START_STREAM | - | Начать передачу данных |
| 0x02 | STOP_STREAM | - | Остановить передачу |
| 0x03 | SET_SAMPLE_RATE | 1 byte (code) | Установить частоту |
| 0x04 | GET_DEVICE_INFO | - | Запросить информацию |
| 0x05 | SET_THRESHOLDS | 8 bytes | Установить пороги |
| 0x06 | GET_THRESHOLDS | - | Получить пороги |
| 0x07 | SYNC_TIME | 4 bytes (unix time) | Синхронизация времени |
| 0x08 | SET_SLEEP_MODE | 2 bytes | Настройка режима сна |
| 0x09 | FACTORY_RESET | 4 bytes (magic) | Сброс к заводским |
| 0x0A | ENTER_PAIRING | - | Режим сопряжения |
| 0x0B | GET_STORED_DATA | 4 bytes (from time) | Запрос буфера |
| 0x0C | CLEAR_BUFFER | - | Очистить буфер |
| 0x0D | START_FFT | 1 byte (axis) | Запустить FFT анализ |
| 0x0E | CALIBRATE | 1 byte (type) | Калибровка датчиков |
| 0x0F | REBOOT | - | Перезагрузка |

### 4.3 Response Packet Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        RESPONSE PACKET                                      │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Original Command ID                                    │
│  1      │  1      │  Status Code (0=OK, 1=Error, 2=Busy, etc.)              │
│  2      │  1      │  Payload Length                                         │
│  3-N    │  Var    │  Response Data                                          │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

---

## 5. OTA Protocol

### 5.1 OTA Control Commands

| Command | Value | Description |
|---------|-------|-------------|
| OTA_START | 0x01 | Начать обновление |
| OTA_DATA | 0x02 | Передача данных |
| OTA_END | 0x03 | Завершить передачу |
| OTA_ABORT | 0x04 | Отменить обновление |
| OTA_VERIFY | 0x05 | Проверить целостность |
| OTA_APPLY | 0x06 | Применить прошивку |

### 5.2 OTA Start Packet

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OTA START PACKET                                    │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Command (0x01 = OTA_START)                             │
│  1-4    │  4      │  Firmware Size (bytes)                                  │
│  5-8    │  4      │  CRC32 of firmware                                      │
│  9-12   │  4      │  Firmware Version (packed)                              │
│  13-16  │  4      │  Hardware Compatibility Flags                           │
│  17-18  │  2      │  Chunk Size (typically 240)                             │
│  19     │  1      │  Compression (0=None, 1=LZ4)                            │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

### 5.3 OTA Data Packet

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          OTA DATA PACKET                                    │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Command (0x02 = OTA_DATA)                              │
│  1-2    │  2      │  Chunk Index                                            │
│  3      │  1      │  Chunk Length                                           │
│  4-243  │  240    │  Firmware Data                                          │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

### 5.4 OTA Status Response

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OTA STATUS PACKET                                    │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Status Code                                            │
│  1      │  1      │  Progress (0-100%)                                      │
│  2-3    │  2      │  Last Received Chunk                                    │
│  4-7    │  4      │  Bytes Written                                          │
│  8      │  1      │  Error Code (if any)                                    │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘

Status Codes:
  0x00: Idle
  0x01: Receiving
  0x02: Verifying
  0x03: Writing
  0x04: Complete
  0x05: Error
  0x06: Rebooting
```

### 5.5 OTA Process Flow

```
┌──────────┐                                           ┌──────────┐
│  Mobile  │                                           │  ESP32   │
│   App    │                                           │          │
└────┬─────┘                                           └────┬─────┘
     │                                                      │
     │  Write OTA Control: OTA_START                        │
     │  [size, crc32, version, chunk_size]                  │
     │─────────────────────────────────────────────────────►│
     │                                                      │
     │                    OTA Status: Receiving, 0%         │
     │◄─────────────────────────────────────────────────────│
     │                                                      │
     │  Write OTA Data: Chunk 0                             │
     │─────────────────────────────────────────────────────►│
     │  Write OTA Data: Chunk 1                             │
     │─────────────────────────────────────────────────────►│
     │  Write OTA Data: Chunk 2                             │
     │─────────────────────────────────────────────────────►│
     │  ...                                                 │
     │                                                      │
     │                    OTA Status: Receiving, 50%        │
     │◄─────────────────────────────────────────────────────│
     │                                                      │
     │  Write OTA Data: Chunk N-1                           │
     │─────────────────────────────────────────────────────►│
     │  Write OTA Data: Chunk N (last)                      │
     │─────────────────────────────────────────────────────►│
     │                                                      │
     │  Write OTA Control: OTA_END                          │
     │─────────────────────────────────────────────────────►│
     │                                                      │
     │                    OTA Status: Verifying             │
     │◄─────────────────────────────────────────────────────│
     │                                                      │
     │                    OTA Status: Complete              │
     │◄─────────────────────────────────────────────────────│
     │                                                      │
     │  Write OTA Control: OTA_APPLY                        │
     │─────────────────────────────────────────────────────►│
     │                                                      │
     │                    OTA Status: Rebooting             │
     │◄─────────────────────────────────────────────────────│
     │                                                      │
     │                    [Device Reboots]                  │
     │                                                      │
┌────┴─────┐                                           ┌────┴─────┐
│  Mobile  │                                           │  ESP32   │
│   App    │                                           │          │
└──────────┘                                           └──────────┘
```

---

## 6. Энергосбережение

### 6.1 Sleep Mode Configuration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SLEEP CONFIGURATION PACKET                             │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Sleep Mode (0=Off, 1=Light, 2=Deep)                    │
│  1-2    │  2      │  Sleep Interval (seconds)                               │
│  3-4    │  2      │  Wake Duration (seconds)                                │
│  5      │  1      │  Wake Triggers (bitmask)                                │
│  6-7    │  2      │  Vibration Wake Threshold                               │
│  8-9    │  2      │  Temperature Wake Threshold                             │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘

Wake Triggers (Byte 5):
  Bit 0: Timer
  Bit 1: Button press
  Bit 2: Vibration threshold exceeded
  Bit 3: Temperature threshold exceeded
  Bit 4: BLE connection request
  Bit 5-7: Reserved
```

### 6.2 Power Consumption Estimates

| Mode | Current | Duration | Notes |
|------|---------|----------|-------|
| Active + BLE TX | ~130 mA | Varies | Streaming mode |
| Active + BLE Idle | ~80 mA | Varies | Connected, no TX |
| Light Sleep | ~0.8 mA | Sleep interval | BLE off, ULP active |
| Deep Sleep | ~10 µA | Sleep interval | RTC + ULP only |
| Modem Sleep | ~20 mA | Between TX | CPU active |

### 6.3 Power State Machine

```
                    ┌────────────────────────────────────────┐
                    │                                        │
                    ▼                                        │
            ┌───────────────┐                               │
            │    ACTIVE     │                               │
            │               │                               │
            │ • Sensors ON  │                               │
            │ • BLE Active  │                               │
            │ • CPU Full    │                               │
            └───────┬───────┘                               │
                    │                                        │
         No connection for X sec                             │
         or command received                                 │
                    │                                        │
                    ▼                                        │
            ┌───────────────┐         BLE Connection         │
            │  LIGHT SLEEP  │─────────Request─────────────────
            │               │                               │
            │ • Sensors Poll│                               │
            │ • BLE Advert  │                               │
            │ • CPU Light   │                               │
            └───────┬───────┘                               │
                    │                                        │
         No activity for Y sec                               │
                    │                                        │
                    ▼                                        │
            ┌───────────────┐         Wake Trigger           │
            │   DEEP SLEEP  │────────(Timer/Button/──────────┘
            │               │         Threshold)
            │ • Sensors OFF │
            │ • BLE OFF     │
            │ • RTC Only    │
            └───────────────┘
```

---

## 7. Безопасность BLE

### 7.1 Pairing Process

1. **Just Works** для начального сопряжения (низкий уровень безопасности)
2. После сопряжения — **Bonding** с сохранением ключей
3. **AES-128 CCM** шифрование всех данных
4. **Whitelist** для известных устройств

### 7.2 Security Levels

| Level | Mode | Description |
|-------|------|-------------|
| 1 | Pairing Mode | Открытое сопряжение (60 сек) |
| 2 | Bonded | Только привязанные устройства |
| 3 | Encrypted | + Шифрование данных |

### 7.3 Authentication Token (Custom)

После сопряжения мобильное приложение может отправить токен аутентификации:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AUTH TOKEN PACKET                                    │
├─────────┬─────────┬─────────────────────────────────────────────────────────┤
│  Byte   │  Size   │  Description                                            │
├─────────┼─────────┼─────────────────────────────────────────────────────────┤
│  0      │  1      │  Command (0x10 = AUTH)                                  │
│  1-16   │  16     │  Auth Token (SHA-256 first 128 bits)                    │
│  17-20  │  4      │  Timestamp                                              │
│  21-24  │  4      │  User ID (from server)                                  │
└─────────┴─────────┴─────────────────────────────────────────────────────────┘
```

---

## 8. Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0x00 | SUCCESS | Операция успешна |
| 0x01 | UNKNOWN_COMMAND | Неизвестная команда |
| 0x02 | INVALID_PARAM | Неверный параметр |
| 0x03 | BUSY | Устройство занято |
| 0x04 | NOT_SUPPORTED | Не поддерживается |
| 0x05 | SENSOR_ERROR | Ошибка датчика |
| 0x06 | STORAGE_FULL | Буфер переполнен |
| 0x07 | LOW_BATTERY | Низкий заряд |
| 0x08 | NOT_AUTHORIZED | Не авторизовано |
| 0x09 | OTA_ERROR | Ошибка OTA |
| 0x0A | CRC_ERROR | Ошибка CRC |
| 0x0B | TIMEOUT | Таймаут операции |
| 0xFF | GENERIC_ERROR | Общая ошибка |

---

## 9. Пример взаимодействия

### 9.1 Получение данных телеметрии

```
1. Mobile -> ESP32: Connect
2. Mobile -> ESP32: Discover Services
3. Mobile -> ESP32: Enable Notifications on Combined Data characteristic
4. Mobile -> ESP32: Write Command: START_STREAM (0x01)
5. ESP32 -> Mobile: Response: OK (0x00)
6. ESP32 -> Mobile: Notify: Combined Data Packet #1
7. ESP32 -> Mobile: Notify: Combined Data Packet #2
...
N. Mobile -> ESP32: Write Command: STOP_STREAM (0x02)
```

### 9.2 Синхронизация времени

```
1. Mobile -> ESP32: Write Command: SYNC_TIME (0x07) + Unix timestamp
2. ESP32 -> Mobile: Response: OK (0x00)
```

### 9.3 Установка порогов

```
1. Mobile -> ESP32: Write Command: SET_THRESHOLDS (0x05)
   Payload: [vib_warn_hi, vib_crit_hi, temp_warn_hi, temp_crit_hi,
             vib_warn_lo, vib_crit_lo, temp_warn_lo, temp_crit_lo]
2. ESP32 -> Mobile: Response: OK (0x00)
```

---

*Документ: BLE Protocol Specification v1.0*
