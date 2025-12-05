/*
 * VibeMon ESP32 BLE Firmware
 * 
 * Прошивка для ESP32 с датчиками температуры и вибрации
 * Передаёт данные по BLE в веб-приложение VibeMon
 * 
 * Подключение:
 * - DS18B20 (температура): GPIO 4
 * - MPU6050 (вибрация): SDA=GPIO 21, SCL=GPIO 22
 * - Светодиод статуса: GPIO 2 (встроенный)
 * 
 * Для Arduino IDE:
 * 1. Установите библиотеки:
 *    - OneWire
 *    - DallasTemperature
 *    - Adafruit MPU6050
 *    - Adafruit Unified Sensor
 * 2. Выберите плату: ESP32 Dev Module
 * 3. Загрузите прошивку
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// ========== НАСТРОЙКИ ==========
#define DEVICE_NAME "VibeMon-001"

// Пины
#define ONE_WIRE_BUS 4      // DS18B20 температурный датчик
#define LED_PIN 2           // Встроенный светодиод
#define I2C_SDA 21          // MPU6050 SDA
#define I2C_SCL 22          // MPU6050 SCL

// Интервал обновления данных (мс)
#define UPDATE_INTERVAL 1000

// ========== BLE UUIDs ==========
// Эти UUID должны совпадать с веб-приложением!
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define TEMP_CHAR_UUID      "12345678-1234-5678-1234-56789abcdef1"
#define VIBRATION_CHAR_UUID "12345678-1234-5678-1234-56789abcdef2"

// ========== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ==========
BLEServer* pServer = nullptr;
BLECharacteristic* pTempCharacteristic = nullptr;
BLECharacteristic* pVibrationCharacteristic = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// Датчики
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
Adafruit_MPU6050 mpu;

bool mpuAvailable = false;
bool tempSensorAvailable = false;

// Данные
float temperature = 0.0;
float vibration = 0.0;
unsigned long lastUpdate = 0;

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

// ========== ИНИЦИАЛИЗАЦИЯ ==========
void setup() {
  Serial.begin(115200);
  Serial.println("\n=============================");
  Serial.println("   VibeMon ESP32 v1.0");
  Serial.println("=============================\n");

  // Светодиод
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // I2C для MPU6050
  Wire.begin(I2C_SDA, I2C_SCL);

  // Инициализация датчика температуры
  Serial.print("Инициализация DS18B20... ");
  tempSensor.begin();
  if (tempSensor.getDeviceCount() > 0) {
    tempSensorAvailable = true;
    tempSensor.setResolution(12);
    Serial.println("OK");
  } else {
    Serial.println("НЕ НАЙДЕН (будет симуляция)");
  }

  // Инициализация акселерометра/гироскопа
  Serial.print("Инициализация MPU6050... ");
  if (mpu.begin()) {
    mpuAvailable = true;
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    Serial.println("OK");
  } else {
    Serial.println("НЕ НАЙДЕН (будет симуляция)");
  }

  // Инициализация BLE
  Serial.print("Инициализация BLE... ");
  initBLE();
  Serial.println("OK");

  Serial.println("\n-----------------------------");
  Serial.println("Устройство готово к работе!");
  Serial.println("Имя BLE: " + String(DEVICE_NAME));
  Serial.println("-----------------------------\n");

  // Мигание LED для индикации готовности
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

void initBLE() {
  // Создание устройства
  BLEDevice::init(DEVICE_NAME);

  // Создание сервера
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Создание сервиса
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Характеристика температуры
  pTempCharacteristic = pService->createCharacteristic(
    TEMP_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTempCharacteristic->addDescriptor(new BLE2902());

  // Характеристика вибрации
  pVibrationCharacteristic = pService->createCharacteristic(
    VIBRATION_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pVibrationCharacteristic->addDescriptor(new BLE2902());

  // Запуск сервиса
  pService->start();

  // Запуск рекламы
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
}

// ========== ЧТЕНИЕ ДАТЧИКОВ ==========
float readTemperature() {
  if (tempSensorAvailable) {
    tempSensor.requestTemperatures();
    float temp = tempSensor.getTempCByIndex(0);
    if (temp != DEVICE_DISCONNECTED_C && temp > -50 && temp < 150) {
      return temp;
    }
  }
  // Симуляция температуры (40-60°C)
  return 40.0 + random(0, 200) / 10.0;
}

float readVibration() {
  if (mpuAvailable) {
    sensors_event_t a, g, temp;
    mpu.getEvent(&a, &g, &temp);
    
    // Вычисляем общее ускорение (без учета гравитации по Z)
    float ax = a.acceleration.x;
    float ay = a.acceleration.y;
    float az = a.acceleration.z - 9.81; // Убираем гравитацию
    
    // Амплитуда вибрации в g
    float vibMagnitude = sqrt(ax*ax + ay*ay + az*az) / 9.81;
    return vibMagnitude;
  }
  // Симуляция вибрации (0.5-3.0 g)
  return 0.5 + random(0, 250) / 100.0;
}

// ========== ОСНОВНОЙ ЦИКЛ ==========
void loop() {
  unsigned long currentTime = millis();

  // Обновление данных каждые UPDATE_INTERVAL мс
  if (currentTime - lastUpdate >= UPDATE_INTERVAL) {
    lastUpdate = currentTime;

    // Чтение датчиков
    temperature = readTemperature();
    vibration = readVibration();

    // Вывод в Serial
    Serial.print("Температура: ");
    Serial.print(temperature, 1);
    Serial.print("°C | Вибрация: ");
    Serial.print(vibration, 2);
    Serial.print("g");

    // Отправка по BLE если подключен клиент
    if (deviceConnected) {
      // Отправка температуры (float, 4 байта, little-endian)
      pTempCharacteristic->setValue((uint8_t*)&temperature, sizeof(float));
      pTempCharacteristic->notify();

      // Отправка вибрации
      pVibrationCharacteristic->setValue((uint8_t*)&vibration, sizeof(float));
      pVibrationCharacteristic->notify();

      Serial.println(" [BLE ✓]");
    } else {
      Serial.println(" [Ожидание подключения...]");
    }

    // Мигание LED при работе
    if (!deviceConnected) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    }
  }

  // Обработка переподключения
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Реклама BLE перезапущена");
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(10);
}
