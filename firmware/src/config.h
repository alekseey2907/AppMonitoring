/**
 * VibeMon Configuration Header
 * Contains all compile-time and runtime configuration
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

// ===========================================
// Firmware Version
// ===========================================
#define FIRMWARE_VERSION "1.0.0"
#define FIRMWARE_VERSION_MAJOR 1
#define FIRMWARE_VERSION_MINOR 0
#define FIRMWARE_VERSION_PATCH 0

// ===========================================
// Hardware Pin Definitions
// ===========================================
// I2C for MPU6050
#define I2C_MASTER_SCL_IO       22
#define I2C_MASTER_SDA_IO       21
#define I2C_MASTER_NUM          I2C_NUM_0
#define I2C_MASTER_FREQ_HZ      400000

// OneWire for DS18B20
#define ONEWIRE_GPIO            4

// LED Indicator
#define LED_GPIO                2
#define LED_PWM_CHANNEL         0
#define LED_PWM_TIMER           0

// Battery ADC
#define BATTERY_ADC_CHANNEL     ADC1_CHANNEL_0  // GPIO36
#define BATTERY_ADC_ATTEN       ADC_ATTEN_DB_11

// Button (Wake from sleep)
#define BUTTON_GPIO             0  // Boot button

// ===========================================
// BLE Configuration
// ===========================================
#define DEVICE_NAME_PREFIX      "VibeMon_"
#define BLE_MTU_SIZE            517

// Service UUIDs
#define SERVICE_UUID_TELEMETRY  "A0000001-0000-1000-8000-00805F9B34FB"
#define SERVICE_UUID_CONTROL    "B0000001-0000-1000-8000-00805F9B34FB"
#define SERVICE_UUID_OTA        "C0000001-0000-1000-8000-00805F9B34FB"

// Characteristic UUIDs - Telemetry
#define CHAR_UUID_VIBRATION     "A0000002-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_TEMPERATURE   "A0000003-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_BATTERY       "A0000004-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_ALERTS        "A0000005-0000-1000-8000-00805F9B34FB"

// Characteristic UUIDs - Control
#define CHAR_UUID_SAMPLE_RATE   "B0000002-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_THRESHOLDS    "B0000003-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_DEVICE_INFO   "B0000004-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_COMMAND       "B0000005-0000-1000-8000-00805F9B34FB"

// Characteristic UUIDs - OTA
#define CHAR_UUID_OTA_CONTROL   "C0000002-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_OTA_DATA      "C0000003-0000-1000-8000-00805F9B34FB"
#define CHAR_UUID_OTA_STATUS    "C0000004-0000-1000-8000-00805F9B34FB"

// ===========================================
// Sensor Configuration
// ===========================================
// MPU6050
#define MPU6050_ADDR            0x68
#define MPU6050_ACCEL_RANGE     MPU6050_ACCEL_RANGE_4G
#define MPU6050_GYRO_RANGE      MPU6050_GYRO_RANGE_500DPS
#define MPU6050_DLPF_BW         MPU6050_DLPF_BW_42

// DS18B20
#define DS18B20_RESOLUTION      12  // 12-bit resolution

// Sample rates (ms)
#define SAMPLE_INTERVAL_NORMAL  1000    // 1 second
#define SAMPLE_INTERVAL_FAST    100     // 100ms for detailed analysis
#define SAMPLE_INTERVAL_SLOW    5000    // 5 seconds for power saving

// ===========================================
// Thresholds (Default Values)
// ===========================================
#define DEFAULT_VIBRATION_WARNING   2.0f    // g
#define DEFAULT_VIBRATION_CRITICAL  4.0f    // g
#define DEFAULT_TEMP_WARNING        60.0f   // °C
#define DEFAULT_TEMP_CRITICAL       80.0f   // °C

// ===========================================
// Power Management
// ===========================================
#define BATTERY_LOW_THRESHOLD   20      // %
#define BATTERY_CRITICAL        10      // %
#define SLEEP_TIMEOUT_MS        60000   // 1 minute without connection
#define DEEP_SLEEP_TIME_US      300000000  // 5 minutes

// ===========================================
// Storage Configuration
// ===========================================
#define NVS_NAMESPACE           "vibemon"
#define MAX_BUFFERED_READINGS   1000
#define BUFFER_SYNC_THRESHOLD   100

// ===========================================
// Runtime Configuration Structure
// ===========================================
typedef struct {
    uint32_t sample_interval_ms;
    float vibration_warning;
    float vibration_critical;
    float temp_warning;
    float temp_critical;
    bool alerts_enabled;
    bool power_saving_mode;
    char device_name[32];
} device_config_t;

// ===========================================
// Configuration Functions
// ===========================================
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Load configuration from NVS
 */
esp_err_t config_load(void);

/**
 * Save configuration to NVS
 */
esp_err_t config_save(void);

/**
 * Get current sample interval
 */
uint32_t config_get_sample_interval(void);

/**
 * Set sample interval
 */
esp_err_t config_set_sample_interval(uint32_t interval_ms);

/**
 * Get vibration thresholds
 */
void config_get_vibration_thresholds(float *warning, float *critical);

/**
 * Set vibration thresholds
 */
esp_err_t config_set_vibration_thresholds(float warning, float critical);

/**
 * Get temperature thresholds
 */
void config_get_temp_thresholds(float *warning, float *critical);

/**
 * Set temperature thresholds
 */
esp_err_t config_set_temp_thresholds(float warning, float critical);

/**
 * Get device name
 */
const char* config_get_device_name(void);

/**
 * Set device name
 */
esp_err_t config_set_device_name(const char *name);

/**
 * Reset configuration to defaults
 */
esp_err_t config_reset_defaults(void);

#ifdef __cplusplus
}
#endif

#endif // CONFIG_H
