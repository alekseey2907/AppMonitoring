/*
 * VibeMon ESP32 Advanced BLE Firmware
 * 
 * Продвинутая прошивка с точным анализом вибрации по ISO 10816
 * 
 * Функции анализа вибрации:
 * - RMS (среднеквадратичное) - основной показатель по ISO
 * - FFT анализ частот (до 500 Гц)
 * - Пиковые значения (Peak) для детекции ударов
 * - Peak-to-Peak (размах) 
 * - Crest Factor (отношение пик/RMS) - диагностика подшипников
 * - Фильтрация шума (высокочастотный фильтр)
 * - Скользящее среднее для стабильности показаний
 * 
 * Подключение:
 * - DS18B20 (температура): GPIO 4
 * - MPU6050 (вибрация): SDA=GPIO 21, SCL=GPIO 22
 * - Светодиод статуса: GPIO 2 (встроенный)
 * 
 * Библиотеки:
 * - OneWire, DallasTemperature
 * - Adafruit MPU6050, Adafruit Unified Sensor
 * - arduinoFFT
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <arduinoFFT.h>
#include <Preferences.h>  // Для сохранения калибровки
#include "wifi_config.h"  // Конфигурация WiFi

// ========== НАСТРОЙКИ ==========
#define DEVICE_NAME "VibeMon-001-Pro"

// Отладка (false = минимум логов для экономии памяти)
#define DEBUG_MODE false

// ВНИМАНИЕ: Для экономии памяти рекомендуется использовать ТОЛЬКО BLE или ТОЛЬКО WiFi
// WiFi настройки (опционально, можно отключить для экономии памяти)
#define WIFI_TCP_PORT 8888           // TCP порт для подключения
#define WIFI_ENABLED false  // false = только BLE (экономия памяти), true = добавить WiFi

// Пины
#define ONE_WIRE_BUS 4
#define LED_PIN 2
#define I2C_SDA 21
#define I2C_SCL 22

// FFT настройки
#define SAMPLES 256              // Количество сэмплов FFT (степень 2)
#define SAMPLING_FREQUENCY 1000  // Частота дискретизации Гц (Найквист = 500 Гц)

// Интервал отправки данных по BLE (мс)
#define BLE_UPDATE_INTERVAL 500

// Пороги по ISO 10816 для машин класса I (мм/с RMS)
#define VIBRATION_GOOD 1.8       // Хорошо
#define VIBRATION_ACCEPTABLE 4.5 // Допустимо
#define VIBRATION_ALARM 11.2     // Тревога

// ========== BLE UUIDs ==========
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define TEMP_CHAR_UUID      "12345678-1234-5678-1234-56789abcdef1"
#define VIBRATION_CHAR_UUID "12345678-1234-5678-1234-56789abcdef2"
#define SPECTRUM_CHAR_UUID  "12345678-1234-5678-1234-56789abcdef3"
#define STATUS_CHAR_UUID    "12345678-1234-5678-1234-56789abcdef4"
#define COMMAND_CHAR_UUID   "12345678-1234-5678-1234-56789abcdef5"  // Команды управления

// ========== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ==========
// BLE переменные
BLEServer* pServer = nullptr;
BLECharacteristic* pTempCharacteristic = nullptr;
BLECharacteristic* pVibrationCharacteristic = nullptr;
BLECharacteristic* pSpectrumCharacteristic = nullptr;
BLECharacteristic* pStatusCharacteristic = nullptr;
BLECharacteristic* pCommandCharacteristic = nullptr;

// WiFi переменные
WiFiServer wifiServer(WIFI_TCP_PORT);
WiFiClient wifiClient;
bool wifiMode = WIFI_ENABLED;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// Датчики
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
Adafruit_MPU6050 mpu;

bool mpuAvailable = false;
bool tempSensorAvailable = false;

// FFT буферы
double vReal[SAMPLES];
double vImag[SAMPLES];
ArduinoFFT<double> FFT = ArduinoFFT<double>(vReal, vImag, SAMPLES, SAMPLING_FREQUENCY);

// Буфер для скользящего среднего
#define MOVING_AVG_SIZE 10
float rmsHistory[MOVING_AVG_SIZE];
int rmsHistoryIndex = 0;
bool rmsHistoryFull = false;

// Данные вибрации
struct VibrationData {
  float rms;           // RMS в g
  float rmsVelocity;   // RMS скорости в мм/с (ISO 10816)
  float peak;          // Пиковое значение
  float peakToPeak;    // Размах (Peak-to-Peak)
  float crestFactor;   // Crest Factor (Peak/RMS)
  float dominantFreq;  // Доминантная частота (Гц)
  float dominantAmp;   // Амплитуда доминантной частоты
  uint8_t status;      // 0=Good, 1=Acceptable, 2=Alarm, 3=Danger
};

VibrationData vibData;
float temperature = 0.0;

// Таймеры
unsigned long lastBLEUpdate = 0;

// ========== BLE CALLBACKS ==========
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✓ Клиент подключен");
    digitalWrite(LED_PIN, HIGH);
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("✗ Клиент отключен");
    digitalWrite(LED_PIN, LOW);
  }
};

// Прототипы функций (для CommandCallbacks)
void forceRecalibration();
void saveCalibration();

// Команды управления устройством
// 0x01 = Перекалибровка
// 0x02 = Сброс настроек  
// 0x03 = Перезагрузка
class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() > 0) {
      uint8_t command = value[0];
      Serial.printf("📨 Получена команда: 0x%02X\n", command);
      
      switch (command) {
        case 0x01:  // Перекалибровка
          Serial.println("🔄 Команда: Перекалибровка");
          forceRecalibration();
          break;
          
        case 0x02:  // Сброс настроек
          Serial.println("🗑️ Команда: Сброс настроек");
          {
            Preferences prefs;
            prefs.begin("vibemon", false);
            prefs.clear();
            prefs.end();
          }
          forceRecalibration();
          break;
          
        case 0x03:  // Перезагрузка
          Serial.println("🔌 Команда: Перезагрузка");
          delay(500);
          ESP.restart();
          break;
          
        default:
          Serial.printf("❓ Неизвестная команда: 0x%02X\n", command);
      }
    }
  }
};

// ========== ИНИЦИАЛИЗАЦИЯ ==========
void setup() {
  Serial.begin(115200);
  Serial.println("\n================================");
  Serial.println("   VibeMon ESP32 Pro v2.0");
  Serial.println("   Advanced Vibration Analysis");
  Serial.println("================================\n");

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(400000); // 400 кГц I2C для быстрого опроса

  // Инициализация датчика температуры
  Serial.print("Инициализация DS18B20... ");
  tempSensor.begin();
  if (tempSensor.getDeviceCount() > 0) {
    tempSensorAvailable = true;
    tempSensor.setResolution(12);
    tempSensor.setWaitForConversion(false); // Асинхронное чтение
    Serial.println("OK");
  } else {
    Serial.println("НЕ НАЙДЕН");
  }

  // Инициализация акселерометра
  Serial.print("Инициализация MPU6050... ");
  if (mpu.begin()) {
    mpuAvailable = true;
    // Настройка для точного измерения вибрации
    mpu.setAccelerometerRange(MPU6050_RANGE_4_G);  // ±4g для лучшей точности
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_44_HZ);    // Встроенный НЧ фильтр
    Serial.println("OK");
    Serial.println("  Диапазон: ±4g");
    Serial.println("  Фильтр: 44 Гц");
  } else {
    Serial.println("НЕ НАЙДЕН");
  }

  // Инициализация связи (BLE или WiFi)
  if (wifiMode) {
    Serial.print("Инициализация WiFi AP... ");
    initWiFi();
    Serial.println("OK");
  } else {
    Serial.print("Инициализация BLE... ");
    initBLE();
    Serial.println("OK");
  }

  // Инициализация буферов
  memset(vReal, 0, sizeof(vReal));
  memset(vImag, 0, sizeof(vImag));
  memset(rmsHistory, 0, sizeof(rmsHistory));
  memset(&vibData, 0, sizeof(vibData));

  // Загрузка калибровки из памяти
  loadCalibration();

  Serial.println("\n--------------------------------");
  Serial.println("Устройство готово!");
  if (wifiMode) {
    Serial.println("Режим: WiFi (домашняя сеть)");
    Serial.print("IP адрес: ");
    Serial.println(WiFi.localIP());
    Serial.printf("TCP порт: %d\n", WIFI_TCP_PORT);
  } else {
    Serial.println("Режим: BLE (Bluetooth)");
    Serial.println("Имя: " + String(DEVICE_NAME));
  }
  Serial.printf("FFT: %d точек @ %d Гц\n", SAMPLES, SAMPLING_FREQUENCY);
  Serial.println("--------------------------------");
  
  if (!calibrated) {
    Serial.println("⏳ Калибровка... Держите датчик неподвижно!");
  }
  Serial.println();

  // Индикация готовности
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

void initBLE() {
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(BLEUUID(SERVICE_UUID), 30);

  // Температура
  pTempCharacteristic = pService->createCharacteristic(
    TEMP_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pTempCharacteristic->addDescriptor(new BLE2902());

  // Данные вибрации (структура VibrationData)
  pVibrationCharacteristic = pService->createCharacteristic(
    VIBRATION_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pVibrationCharacteristic->addDescriptor(new BLE2902());

  // Спектр FFT (8 основных частотных полос)
  pSpectrumCharacteristic = pService->createCharacteristic(
    SPECTRUM_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pSpectrumCharacteristic->addDescriptor(new BLE2902());

  // Статус устройства (JSON)
  pStatusCharacteristic = pService->createCharacteristic(
    STATUS_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pStatusCharacteristic->addDescriptor(new BLE2902());

  // Команды управления (перекалибровка, сброс и т.д.)
  pCommandCharacteristic = pService->createCharacteristic(
    COMMAND_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pCommandCharacteristic->setCallbacks(new CommandCallbacks());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
}

void initWiFi() {
  // Подключение к домашней WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  Serial.print("  Подключение к WiFi: ");
  Serial.println(WIFI_SSID);
  Serial.print("  ");
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("  ✓ WiFi подключен!");
    Serial.print("  IP адрес ESP32: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("  ✗ Ошибка подключения к WiFi!");
    Serial.println("  Проверьте SSID и пароль в wifi_config.h");
  }
  
  wifiServer.begin();
  Serial.printf("  TCP сервер запущен на порту %d\n", WIFI_TCP_PORT);
}

// ========== ВЫСОКОЧАСТОТНЫЙ ФИЛЬТР ==========
// Убирает DC offset (постоянную составляющую/гравитацию)
// Использует IIR фильтр первого порядка

// Калибровочное значение гравитации (будет загружено из памяти или измерено)
float gravityOffset = 9.81;
bool calibrated = false;
int calibrationSamples = 0;
float calibrationSum = 0;

// Хранилище калибровки
Preferences preferences;

// Загрузка калибровки из памяти
void loadCalibration() {
  preferences.begin("vibemon", true);  // read-only
  float saved = preferences.getFloat("gravity", 0);
  preferences.end();
  
  if (saved > 8.0 && saved < 12.0) {  // Валидное значение (около 9.81)
    gravityOffset = saved;
    calibrated = true;
    Serial.printf("✓ Калибровка загружена из памяти: %.3f m/s²\n", gravityOffset);
  } else {
    Serial.println("⚠ Калибровка не найдена, требуется новая калибровка");
    calibrated = false;
  }
}

// Сохранение калибровки в память
void saveCalibration() {
  preferences.begin("vibemon", false);  // read-write
  preferences.putFloat("gravity", gravityOffset);
  preferences.end();
  Serial.printf("💾 Калибровка сохранена: %.3f m/s²\n", gravityOffset);
}

// Принудительная перекалибровка (вызывать при необходимости)
void forceRecalibration() {
  calibrated = false;
  calibrationSamples = 0;
  calibrationSum = 0;
  Serial.println("🔄 Запущена перекалибровка...");
}

// Простой ВЧ фильтр для удаления DC (улучшенная версия)
// alpha = 0.98 даёт частоту среза ~0.3 Гц при 1000 Гц дискретизации
float removeOffset(float input, float& prevInput, float& prevOutput) {
  const float alpha = 0.98;
  float output = alpha * (prevOutput + input - prevInput);
  prevInput = input;
  prevOutput = output;
  return output;
}

// Калибровка - измеряем среднее значение в покое
void calibrateGravity(float magnitude) {
  if (!calibrated) {
    calibrationSum += magnitude;
    calibrationSamples++;
    if (calibrationSamples >= 500) {
      gravityOffset = calibrationSum / calibrationSamples;
      calibrated = true;
      Serial.printf("✓ Калибровка завершена: gravity = %.3f m/s²\n", gravityOffset);
      saveCalibration();  // Сохраняем в память!
    }
  }
}

// ========== СБОР ДАННЫХ ДЛЯ FFT ==========
void collectSamples() {
  static float prevInput = 0, prevOutput = 0;
  
  unsigned long samplingPeriod = 1000000 / SAMPLING_FREQUENCY; // в микросекундах
  
  float minVal = 1000, maxVal = -1000;
  float sumSquares = 0;
  
  for (int i = 0; i < SAMPLES; i++) {
    unsigned long startMicros = micros();
    
    if (mpuAvailable) {
      sensors_event_t a, g, temp;
      mpu.getEvent(&a, &g, &temp);
      
      // Вычисляем общую амплитуду ускорения
      float magnitude = sqrt(
        a.acceleration.x * a.acceleration.x +
        a.acceleration.y * a.acceleration.y +
        a.acceleration.z * a.acceleration.z
      );
      
      // Калибровка при первом запуске
      calibrateGravity(magnitude);
      
      // Удаляем гравитацию (вычитаем калиброванное значение)
      float withoutGravity = magnitude - gravityOffset;
      
      // Дополнительный ВЧ фильтр для удаления остаточного DC
      float filtered = removeOffset(withoutGravity, prevInput, prevOutput);
      
      vReal[i] = filtered;
      vImag[i] = 0;
      
      // Статистика для Peak и RMS
      if (filtered < minVal) minVal = filtered;
      if (filtered > maxVal) maxVal = filtered;
      sumSquares += filtered * filtered;
    } else {
      // Симуляция: сумма синусоид разных частот + шум
      float t = (float)i / SAMPLING_FREQUENCY;
      float simulated = 
        0.5 * sin(2 * PI * 25 * t) +   // 25 Гц - дисбаланс
        0.3 * sin(2 * PI * 50 * t) +   // 50 Гц - сетевая наводка
        0.2 * sin(2 * PI * 100 * t) +  // 100 Гц - 2x частота вращения
        0.1 * random(-100, 100) / 100.0; // Шум
      
      vReal[i] = simulated;
      vImag[i] = 0;
      
      if (simulated < minVal) minVal = simulated;
      if (simulated > maxVal) maxVal = simulated;
      sumSquares += simulated * simulated;
    }
    
    // Точная задержка для частоты дискретизации
    while (micros() - startMicros < samplingPeriod) {
      // Ждём
    }
  }
  
  // Расчёт базовых параметров
  // RMS уже в м/с² (ускорение без гравитации)
  vibData.rms = sqrt(sumSquares / SAMPLES);
  vibData.peak = max(abs(minVal), abs(maxVal));
  vibData.peakToPeak = maxVal - minVal;
  vibData.crestFactor = (vibData.rms > 0) ? vibData.peak / vibData.rms : 0;
  
  // ПОКА НЕ вычисляем скорость - сначала найдём доминантную частоту через FFT
  // Это будет сделано в performFFTAnalysis()
  vibData.rmsVelocity = 0.0; // Временно
}

// ========== FFT АНАЛИЗ ==========
void performFFTAnalysis() {
  // Применяем окно Хэмминга для уменьшения спектральной утечки
  FFT.windowing(FFTWindow::Hamming, FFTDirection::Forward);
  
  // Выполняем FFT
  FFT.compute(FFTDirection::Forward);
  
  // Преобразуем в амплитуды
  FFT.complexToMagnitude();
  
  // Находим доминантную частоту (пропускаем DC компоненту)
  double maxMag = 0;
  int maxIndex = 1;
  
  for (int i = 2; i < SAMPLES / 2; i++) {
    if (vReal[i] > maxMag) {
      maxMag = vReal[i];
      maxIndex = i;
    }
  }
  
  // Частота = индекс * (частота_дискретизации / количество_сэмплов)
  vibData.dominantFreq = (float)maxIndex * SAMPLING_FREQUENCY / SAMPLES;
  vibData.dominantAmp = maxMag / (SAMPLES / 2); // Нормализация
  
  // ПРАВИЛЬНЫЙ расчёт RMS скорости с учётом доминантной частоты
  // Формула: v = a / (2 * PI * f), результат в мм/с
  
  // КРИТИЧНО: Проверяем порог шума ДО расчёта скорости
  if (vibData.rms < 0.05) {  
    // Ускорение < 0.05 м/с² = шум/покой
    vibData.rmsVelocity = 0.0;
  } else if (vibData.dominantFreq > 5.0) {  
    // Есть реальная доминантная частота (не DC)
    vibData.rmsVelocity = (vibData.rms * 1000.0) / (2.0 * PI * vibData.dominantFreq);
  } else {  
    // Частота слишком низкая или не определена
    // Используем среднюю частоту для промышленных вибраций ~10 Гц
    vibData.rmsVelocity = (vibData.rms * 1000.0) / (2.0 * PI * 10.0);
  }
  
  // Дополнительная защита от аномально высоких значений
  if (vibData.rmsVelocity > 100.0) {  
    // Что-то пошло не так (> 100 мм/с это катастрофа)
    vibData.rmsVelocity = 0.0;
  }
}

// ========== ОПРЕДЕЛЕНИЕ СТАТУСА ==========
void updateStatus() {
  // По ISO 10816-1 для машин класса I
  if (vibData.rmsVelocity < VIBRATION_GOOD) {
    vibData.status = 0; // Good (зелёный)
  } else if (vibData.rmsVelocity < VIBRATION_ACCEPTABLE) {
    vibData.status = 1; // Acceptable (жёлтый)
  } else if (vibData.rmsVelocity < VIBRATION_ALARM) {
    vibData.status = 2; // Alarm (оранжевый)
  } else {
    vibData.status = 3; // Danger (красный)
  }
  
  // Дополнительная проверка Crest Factor
  // CF > 6 указывает на удары/повреждения подшипников
  if (vibData.crestFactor > 6.0 && vibData.status < 2) {
    vibData.status = 2; // Повышаем до Alarm
  }
}

// ========== СКОЛЬЗЯЩЕЕ СРЕДНЕЕ ==========
float getMovingAverageRMS() {
  rmsHistory[rmsHistoryIndex] = vibData.rms;
  rmsHistoryIndex = (rmsHistoryIndex + 1) % MOVING_AVG_SIZE;
  if (rmsHistoryIndex == 0) rmsHistoryFull = true;
  
  int count = rmsHistoryFull ? MOVING_AVG_SIZE : rmsHistoryIndex;
  float sum = 0;
  for (int i = 0; i < count; i++) {
    sum += rmsHistory[i];
  }
  return sum / count;
}

// ========== ЧТЕНИЕ ТЕМПЕРАТУРЫ ==========
float readTemperature() {
  static unsigned long lastTempRequest = 0;
  static float lastTemp = 25.0;
  
  if (tempSensorAvailable) {
    // Асинхронное чтение (не блокирует)
    if (millis() - lastTempRequest > 1000) {
      if (tempSensor.isConversionComplete()) {
        float temp = tempSensor.getTempCByIndex(0);
        if (temp != DEVICE_DISCONNECTED_C && temp > -50 && temp < 150) {
          lastTemp = temp;
        }
        tempSensor.requestTemperatures();
        lastTempRequest = millis();
      }
    }
    return lastTemp;
  }
  // Симуляция
  return 45.0 + random(-50, 50) / 10.0;
}

// ========== ПОЛУЧЕНИЕ СПЕКТРА (8 полос) ==========
void getSpectrumBands(float* bands) {
  // Разделяем спектр на 8 полос
  // 0-31, 31-62, 62-125, 125-187, 187-250, 250-312, 312-375, 375-500 Гц
  int bandsPerBin = SAMPLES / 16; // Примерно 16 бинов на полосу
  
  for (int band = 0; band < 8; band++) {
    float sum = 0;
    int startBin = band * bandsPerBin + 1; // +1 чтобы пропустить DC
    int endBin = (band + 1) * bandsPerBin;
    
    for (int i = startBin; i < endBin && i < SAMPLES / 2; i++) {
      sum += vReal[i];
    }
    bands[band] = sum / bandsPerBin;
  }
}

// ========== ОТПРАВКА ДАННЫХ ПО BLE ==========
void sendBLEData() {
  // Температура
  pTempCharacteristic->setValue((uint8_t*)&temperature, sizeof(float));
  pTempCharacteristic->notify();
  
  // Данные вибрации (структура)
  // Формат: [rms(4), rmsVelocity(4), peak(4), peakToPeak(4), crestFactor(4), 
  //          dominantFreq(4), dominantAmp(4), status(1)] = 29 байт
  uint8_t vibBuffer[29];
  memcpy(vibBuffer, &vibData.rms, 4);
  memcpy(vibBuffer + 4, &vibData.rmsVelocity, 4);
  memcpy(vibBuffer + 8, &vibData.peak, 4);
  memcpy(vibBuffer + 12, &vibData.peakToPeak, 4);
  memcpy(vibBuffer + 16, &vibData.crestFactor, 4);
  memcpy(vibBuffer + 20, &vibData.dominantFreq, 4);
  memcpy(vibBuffer + 24, &vibData.dominantAmp, 4);
  vibBuffer[28] = vibData.status;
  
  pVibrationCharacteristic->setValue(vibBuffer, 29);
  pVibrationCharacteristic->notify();
  
  // Спектр (8 полос по 4 байта = 32 байта)
  float bands[8];
  getSpectrumBands(bands);
  pSpectrumCharacteristic->setValue((uint8_t*)bands, 32);
  pSpectrumCharacteristic->notify();
  
  // Статус JSON
  char statusJson[200];
  const char* statusText[] = {"Good", "Acceptable", "Alarm", "Danger"};
  snprintf(statusJson, sizeof(statusJson),
    "{\"rms\":%.3f,\"vel\":%.2f,\"peak\":%.3f,\"cf\":%.2f,\"freq\":%.1f,\"status\":\"%s\",\"temp\":%.1f}",
    vibData.rms, vibData.rmsVelocity, vibData.peak, vibData.crestFactor,
    vibData.dominantFreq, statusText[vibData.status], temperature
  );
  pStatusCharacteristic->setValue(statusJson);
  pStatusCharacteristic->notify();
}

// ========== ВЫВОД В SERIAL ==========
void printStatus() {
#if DEBUG_MODE
  const char* statusText[] = {"✓ GOOD", "~ ACCEPTABLE", "⚠ ALARM", "✗ DANGER"};
  const char* statusColor[] = {"32", "33", "33", "31"}; // ANSI цвета
  
  Serial.printf("\033[%sm", statusColor[vibData.status]);
  Serial.println(statusText[vibData.status]);
  Serial.print("\033[0m"); // Сброс цвета
  
  Serial.printf("  RMS ускорение: %.4f м/с² (%.3f g)\n", vibData.rms, vibData.rms / 9.81);
  Serial.printf("  RMS скорость: %.2f мм/с\n", vibData.rmsVelocity);
  Serial.printf("  Peak: %.4f м/с² | P-P: %.4f м/с²\n", vibData.peak, vibData.peakToPeak);
  Serial.printf("  Crest Factor: %.2f\n", vibData.crestFactor);
  Serial.printf("  Дом. частота: %.1f Гц (амплитуда: %.4f)\n", vibData.dominantFreq, vibData.dominantAmp);
  Serial.printf("  Температура: %.1f°C\n", temperature);
  Serial.printf("  Gravity offset: %.3f м/с²\n", gravityOffset);
  
  if (wifiMode) {
    if (deviceConnected) {
      Serial.println("  [WiFi: Подключен ✓]");
    } else {
      Serial.println("  [WiFi: Ожидание...]");
    }
  } else {
    if (deviceConnected) {
      Serial.println("  [BLE: Подключен ✓]");
    } else {
      Serial.println("  [BLE: Ожидание...]");
    }
  }
  Serial.println();
#else
  // Минимальный вывод для экономии памяти
  Serial.printf("RMS:%.2f мм/с T:%.1f°C S:%d %s\n", 
    vibData.rmsVelocity, temperature, vibData.status,
    deviceConnected ? "OK" : "--");
#endif
}

// ========== ОТПРАВКА ДАННЫХ ПО WiFi ==========
void sendWiFiData() {
  if (!wifiClient.connected()) return;
  
  // Формат: бинарные данные для эффективности
  // Заголовок пакета (4 байта): 0xVIBE
  wifiClient.write(0x56); // 'V'
  wifiClient.write(0x49); // 'I'
  wifiClient.write(0x42); // 'B'
  wifiClient.write(0x45); // 'E'
  
  // Температура (4 байта float)
  wifiClient.write((uint8_t*)&temperature, sizeof(float));
  
  // Данные вибрации (структура VibrationData - 32 байта)
  wifiClient.write((uint8_t*)&vibData, sizeof(VibrationData));
  
  // Спектр FFT (8 полос по 4 байта)
  float bands[8];
  getSpectrumBands(bands);
  wifiClient.write((uint8_t*)bands, 32);
  
  // Статус JSON для совместимости (опционально)
  char statusJson[200];
  const char* statusText[] = {"Good", "Acceptable", "Alarm", "Danger"};
  snprintf(statusJson, sizeof(statusJson),
    "{\"rms\":%.3f,\"vel\":%.2f,\"peak\":%.3f,\"cf\":%.2f,\"freq\":%.1f,\"status\":\"%s\",\"temp\":%.1f}\n",
    vibData.rms, vibData.rmsVelocity, vibData.peak, vibData.crestFactor,
    vibData.dominantFreq, statusText[vibData.status], temperature
  );
  wifiClient.print(statusJson);
}

// ========== ОБРАБОТКА КОМАНД ==========
void handleCommand(uint8_t command) {
  Serial.printf("📨 Получена команда: 0x%02X\n", command);
  
  switch (command) {
    case 0x01:  // Перекалибровка
      Serial.println("🔄 Команда: Перекалибровка");
      forceRecalibration();
      break;
      
    case 0x02:  // Сброс настроек
      Serial.println("🗑️ Команда: Сброс настроек");
      {
        Preferences prefs;
        prefs.begin("vibemon", false);
        prefs.clear();
        prefs.end();
      }
      forceRecalibration();
      break;
      
    case 0x03:  // Перезагрузка
      Serial.println("🔌 Команда: Перезагрузка");
      if (wifiMode && wifiClient.connected()) {
        wifiClient.stop();
      }
      delay(500);
      ESP.restart();
      break;
      
    default:
      Serial.printf("❓ Неизвестная команда: 0x%02X\n", command);
  }
}

// ========== ОСНОВНОЙ ЦИКЛ ==========
void loop() {
  unsigned long currentTime = millis();
  
  // Обработка WiFi клиента
  if (wifiMode) {
    if (!wifiClient.connected()) {
      wifiClient = wifiServer.available();
      if (wifiClient) {
        Serial.println("✓ WiFi клиент подключен: " + wifiClient.remoteIP().toString());
        deviceConnected = true;
        digitalWrite(LED_PIN, HIGH);
      } else {
        deviceConnected = false;
      }
    } else {
      // Проверка команд от клиента
      if (wifiClient.available()) {
        uint8_t cmd = wifiClient.read();
        handleCommand(cmd);
      }
    }
  }
  
  // Сбор данных и FFT анализ
  collectSamples();
  performFFTAnalysis();
  updateStatus();
  
  // Скользящее среднее для стабильности
  float avgRms = getMovingAverageRMS();
  
  // Чтение температуры
  temperature = readTemperature();
  
  // Отправка данных
  if (currentTime - lastBLEUpdate >= BLE_UPDATE_INTERVAL) {
    lastBLEUpdate = currentTime;
    
    printStatus();
    
    if (deviceConnected) {
      if (wifiMode) {
        sendWiFiData();
      } else {
        sendBLEData();
      }
    }
    
    // Мигание LED по статусу
    if (!deviceConnected) {
      // Медленное мигание - ожидание
      digitalWrite(LED_PIN, (currentTime / 500) % 2);
    } else {
      // Мигание по статусу
      switch (vibData.status) {
        case 0: // Good - постоянно горит
          digitalWrite(LED_PIN, HIGH);
          break;
        case 1: // Acceptable - медленное мигание
          digitalWrite(LED_PIN, (currentTime / 1000) % 2);
          break;
        case 2: // Alarm - быстрое мигание
          digitalWrite(LED_PIN, (currentTime / 250) % 2);
          break;
        case 3: // Danger - очень быстрое мигание
          digitalWrite(LED_PIN, (currentTime / 100) % 2);
          break;
      }
    }
  }
  
  // Переподключение BLE
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("BLE реклама перезапущена");
    oldDeviceConnected = deviceConnected;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}
