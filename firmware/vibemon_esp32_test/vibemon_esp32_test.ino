/*
 * VibeMon ESP32 BLE - ТЕСТОВАЯ ВЕРСИЯ
 * 
 * Упрощённая прошивка БЕЗ реальных датчиков
 * Генерирует тестовые данные для проверки BLE
 * 
 * Подходит для любой ESP32 без дополнительных компонентов!
 * 
 * Для Arduino IDE:
 * 1. Выберите плату: ESP32 Dev Module
 * 2. Загрузите прошивку
 * 3. Откройте веб-приложение VibeMon в Chrome
 * 4. Нажмите "Подключить ESP32"
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ========== НАСТРОЙКИ ==========
#define DEVICE_NAME "VibeMon-001"
#define LED_PIN 2  // Встроенный светодиод

// Интервал обновления данных (мс)
#define UPDATE_INTERVAL 1000

// ========== BLE UUIDs ==========
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define TEMP_CHAR_UUID      "12345678-1234-5678-1234-56789abcdef1"
#define VIBRATION_CHAR_UUID "12345678-1234-5678-1234-56789abcdef2"

// ========== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ==========
BLEServer* pServer = nullptr;
BLECharacteristic* pTempCharacteristic = nullptr;
BLECharacteristic* pVibrationCharacteristic = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

float temperature = 45.0;
float vibration = 1.5;
unsigned long lastUpdate = 0;

// Для симуляции реалистичных данных
float tempTrend = 0.1;
float vibTrend = 0.05;

// ========== BLE CALLBACKS ==========
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✓ Клиент подключен!");
    digitalWrite(LED_PIN, HIGH);
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("✗ Клиент отключен");
    digitalWrite(LED_PIN, LOW);
  }
};

// ========== SETUP ==========
void setup() {
  Serial.begin(115200);
  
  Serial.println("\n╔════════════════════════════════╗");
  Serial.println("║   VibeMon ESP32 TEST v1.0      ║");
  Serial.println("║   Тестовая версия (симуляция)  ║");
  Serial.println("╚════════════════════════════════╝\n");

  // LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Random seed
  randomSeed(analogRead(0));

  // BLE
  Serial.print("Инициализация BLE... ");
  initBLE();
  Serial.println("OK!");

  Serial.println("\n┌─────────────────────────────────┐");
  Serial.println("│ Устройство готово!              │");
  Serial.println("│ Имя BLE: " + String(DEVICE_NAME) + "           │");
  Serial.println("│                                 │");
  Serial.println("│ Откройте VibeMon в Chrome и    │");
  Serial.println("│ нажмите 'Подключить ESP32'     │");
  Serial.println("└─────────────────────────────────┘\n");

  // Startup blink
  for (int i = 0; i < 5; i++) {
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

  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Temperature characteristic
  pTempCharacteristic = pService->createCharacteristic(
    TEMP_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTempCharacteristic->addDescriptor(new BLE2902());

  // Vibration characteristic
  pVibrationCharacteristic = pService->createCharacteristic(
    VIBRATION_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pVibrationCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
}

// ========== СИМУЛЯЦИЯ ДАННЫХ ==========
void updateSimulatedData() {
  // Температура: медленное изменение 35-75°C
  temperature += tempTrend + (random(-10, 11) / 100.0);
  if (temperature > 75) { tempTrend = -0.1; }
  if (temperature < 35) { tempTrend = 0.1; }
  temperature = constrain(temperature, 30, 80);

  // Вибрация: более быстрые колебания 0.5-4.0g
  vibration += vibTrend + (random(-20, 21) / 100.0);
  if (vibration > 3.5) { vibTrend = -0.05; }
  if (vibration < 0.8) { vibTrend = 0.05; }
  vibration = constrain(vibration, 0.5, 4.5);

  // Иногда добавляем "скачки" для реалистичности
  if (random(100) < 5) {
    vibration += random(-50, 51) / 100.0;
    vibration = constrain(vibration, 0.5, 4.5);
  }
}

// ========== LOOP ==========
void loop() {
  unsigned long currentTime = millis();

  if (currentTime - lastUpdate >= UPDATE_INTERVAL) {
    lastUpdate = currentTime;

    updateSimulatedData();

    // Serial output
    Serial.print("🌡 ");
    Serial.print(temperature, 1);
    Serial.print("°C  │  📳 ");
    Serial.print(vibration, 2);
    Serial.print("g");

    if (deviceConnected) {
      // Send BLE notifications
      pTempCharacteristic->setValue((uint8_t*)&temperature, sizeof(float));
      pTempCharacteristic->notify();

      pVibrationCharacteristic->setValue((uint8_t*)&vibration, sizeof(float));
      pVibrationCharacteristic->notify();

      Serial.println("  │  📶 BLE");
    } else {
      Serial.println("  │  ⏳ Ожидание...");
      // Blink LED when waiting
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    }
  }

  // Handle reconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("📡 BLE реклама перезапущена");
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(10);
}
