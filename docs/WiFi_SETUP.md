# WiFi Режим VibeMon

## Обзор

VibeMon теперь поддерживает два режима подключения:
- **BLE (Bluetooth Low Energy)** - беспроводное подключение по Bluetooth
- **WiFi TCP/IP** - подключение через WiFi точку доступа ESP32

## Преимущества WiFi режима

✅ **Выше скорость передачи данных** (~2 обновления/сек vs 1 обновление/сек у BLE)  
✅ **Более стабильное соединение** без ограничений BLE  
✅ **Больше дальность** до 50 метров против 10 метров у BLE  
✅ **Не требует Bluetooth разрешений** на Android/iOS  

## Настройка ESP32 (Прошивка)

### 1. Выбор режима работы

В файле `vibemon_esp32_advanced.ino` измените настройку:

```cpp
#define WIFI_ENABLED true  // true = WiFi, false = BLE
```

### 2. Настройки WiFi (опционально)

В файле `wifi_config.h` или в основном файле:

```cpp
#define WIFI_SSID "VibeMon_AP"      // Имя WiFi сети
#define WIFI_PASSWORD "vibemon123"   // Пароль (минимум 8 символов)
#define WIFI_TCP_PORT 8888           // TCP порт
```

### 3. Прошивка ESP32

1. Откройте `vibemon_esp32_advanced.ino` в Arduino IDE
2. Выберите плату: **ESP32 Dev Module**
3. Нажмите **Upload**
4. Дождитесь завершения прошивки

### 4. Проверка работы

Откройте Serial Monitor (115200 baud):

```
================================
   VibeMon ESP32 Pro v2.0
   Advanced Vibration Analysis
================================

Режим: WiFi TCP/IP
SSID: VibeMon_AP
IP: 192.168.4.1
Порт: 8888
```

## Подключение с мобильного приложения

### Android/iOS

1. **Подключитесь к WiFi сети**
   - Имя сети: `VibeMon_AP`
   - Пароль: `vibemon123`

2. **Откройте приложение VibeMon**
   - Нажмите кнопку **"Подключиться через WiFi"**

3. **Введите параметры подключения**
   - IP адрес: `192.168.4.1` (по умолчанию)
   - Порт: `8888`
   - Нажмите **"Подключиться"**

4. **Готово!**
   - Данные будут поступать через WiFi
   - Все функции (калибровка, перезагрузка) работают

## Протокол передачи данных

### Формат пакета (бинарный)

```
Заголовок:      4 байта     0x56 0x49 0x42 0x45 ("VIBE")
Температура:    4 байта     float (°C)
RMS:            4 байта     float (м/с²)
RMS Velocity:   4 байта     float (мм/с)
Peak:           4 байта     float (м/с²)
Peak-to-Peak:   4 байта     float (м/с²)
Crest Factor:   4 байта     float
Dominant Freq:  4 байта     float (Гц)
Dominant Amp:   4 байта     float
Status:         1 байт      uint8 (0-3)
Padding:        3 байта     выравнивание
Spectrum:       32 байта    8 x float (полосы FFT)
JSON:           переменная  строка со статусом
```

**Итого:** 72 байта бинарных данных + JSON строка

### Команды управления

Отправьте один байт на ESP32:

- `0x01` - Перекалибровка датчика
- `0x02` - Сброс настроек
- `0x03` - Перезагрузка устройства

## Переключение между BLE и WiFi

### Способ 1: Изменение кода (требует перепрошивки)

```cpp
#define WIFI_ENABLED true   // Поменять на false для BLE
```

### Способ 2: Условная компиляция (продвинутый)

Добавьте в код определение режима через кнопку или DIP-переключатель:

```cpp
// Пример: GPIO 0 = режим выбора (LOW = WiFi, HIGH = BLE)
#define MODE_PIN 0

void setup() {
  pinMode(MODE_PIN, INPUT_PULLUP);
  bool wifiMode = (digitalRead(MODE_PIN) == LOW);
  
  if (wifiMode) {
    initWiFi();
  } else {
    initBLE();
  }
}
```

## Устранение проблем

### ESP32 не создаёт WiFi сеть

1. Проверьте Serial Monitor
2. Убедитесь что `WIFI_ENABLED true`
3. Перезагрузите ESP32

### Не удаётся подключиться

1. Проверьте правильность SSID и пароля
2. Убедитесь что телефон подключен к сети `VibeMon_AP`
3. IP должен быть `192.168.4.1`
4. Порт `8888`

### Нет данных после подключения

1. Проверьте Serial Monitor - должны идти обновления
2. Убедитесь что датчик MPU6050 подключен
3. Перезагрузите ESP32

### Ошибка "Timeout"

- ESP32 находится слишком далеко
- Слабый сигнал WiFi
- Перезагрузите устройство

## Технические характеристики

| Параметр | Значение |
|----------|----------|
| Режим WiFi | AP (Access Point) |
| IP адрес | 192.168.4.1 |
| Подсеть | 255.255.255.0 |
| Канал WiFi | 6 |
| Макс. клиентов | 4 |
| Протокол | TCP/IP |
| Порт | 8888 |
| Частота обновлений | ~2 Гц |
| Задержка | <50 мс |

## API для разработчиков

### Python пример

```python
import socket
import struct

# Подключение
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('192.168.4.1', 8888))

while True:
    # Чтение заголовка
    header = sock.recv(4)
    if header == b'VIBE':
        # Чтение данных
        temp = struct.unpack('<f', sock.recv(4))[0]
        data = sock.recv(32)  # VibrationData
        spectrum = sock.recv(32)  # 8 float
        json_line = sock.recv(200).decode().strip()
        
        print(f"Temp: {temp}°C")
        print(f"Status: {json_line}")

sock.close()
```

### Node.js пример

```javascript
const net = require('net');

const client = net.connect({port: 8888, host: '192.168.4.1'}, () => {
  console.log('Connected to VibeMon');
});

client.on('data', (data) => {
  // Поиск заголовка VIBE
  const idx = data.indexOf(Buffer.from([0x56, 0x49, 0x42, 0x45]));
  if (idx >= 0) {
    const temp = data.readFloatLE(idx + 4);
    console.log(`Temperature: ${temp.toFixed(1)}°C`);
  }
});
```

## Безопасность

⚠️ **Внимание:** WiFi пароль по умолчанию `vibemon123` предназначен только для тестирования!

Для производственного использования:
1. Измените пароль на более сложный (минимум 12 символов)
2. Рассмотрите использование WPA2-Enterprise
3. Добавьте аутентификацию на уровне TCP

## Дополнительная информация

- [Документация ESP32 WiFi](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/network/esp_wifi.html)
- [Arduino WiFi Library](https://www.arduino.cc/reference/en/libraries/wifi/)
- [ISO 10816 Vibration Standards](https://www.iso.org/standard/50447.html)
