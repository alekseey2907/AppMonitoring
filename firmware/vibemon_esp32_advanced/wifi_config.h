/*
 * WiFi Configuration для VibeMon
 * 
 * Настройки WiFi точки доступа и TCP сервера
 */

#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

// ========== РЕЖИМ РАБОТЫ ==========
// true = WiFi TCP/IP режим
// false = BLE режим
#define WIFI_MODE_ENABLED true

// ========== WiFi ACCESS POINT ==========
// Имя точки доступа ESP32
#define WIFI_AP_SSID "VibeMon_AP"

// Пароль (минимум 8 символов)
#define WIFI_AP_PASSWORD "vibemon123"

// Канал WiFi (1-13)
#define WIFI_AP_CHANNEL 6

// Максимальное количество клиентов
#define WIFI_AP_MAX_CONNECTIONS 4

// Скрывать SSID (false = видимая сеть)
#define WIFI_AP_HIDDEN false

// ========== TCP SERVER ==========
// Порт TCP сервера
#define WIFI_TCP_PORT 8888

// Таймаут отключения клиента (мс)
#define WIFI_CLIENT_TIMEOUT 30000

// ========== IP КОНФИГУРАЦИЯ ==========
// IP адрес ESP32 (192.168.4.1 по умолчанию)
#define WIFI_AP_IP_ADDR    IPAddress(192, 168, 4, 1)
#define WIFI_AP_GATEWAY    IPAddress(192, 168, 4, 1)
#define WIFI_AP_SUBNET     IPAddress(255, 255, 255, 0)

// ========== ПРОТОКОЛ ==========
// Формат пакета данных:
// 
// Заголовок (4 байта): 0x56 0x49 0x42 0x45 ("VIBE")
// Температура (4 байта): float
// VibrationData (32 байта): структура
//   - rms (float)
//   - rmsVelocity (float)
//   - peak (float)
//   - peakToPeak (float)
//   - crestFactor (float)
//   - dominantFreq (float)
//   - dominantAmp (float)
//   - status (uint8_t)
// Спектр (32 байта): 8 x float
// JSON статус (переменная длина): строка с \n
//
// Итого: 72 байта + JSON строка

// ========== КОМАНДЫ ==========
// Клиент может отправлять байт-команды:
// 0x01 - Перекалибровка датчика
// 0x02 - Сброс настроек
// 0x03 - Перезагрузка устройства

#endif // WIFI_CONFIG_H
