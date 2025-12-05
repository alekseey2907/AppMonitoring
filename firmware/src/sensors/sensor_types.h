/**
 * VibeMon Sensor Types
 * Common data structures for sensor data
 */

#ifndef SENSOR_TYPES_H
#define SENSOR_TYPES_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ===========================================
// Alert Flags
// ===========================================
#define ALERT_FLAG_NONE             0x00
#define ALERT_FLAG_VIBRATION_WARN   0x01
#define ALERT_FLAG_VIBRATION_CRIT   0x02
#define ALERT_FLAG_TEMP_WARN        0x04
#define ALERT_FLAG_TEMP_CRIT        0x08
#define ALERT_FLAG_BATTERY_LOW      0x10
#define ALERT_FLAG_SENSOR_ERROR     0x20

// ===========================================
// Sensor Data Structure
// ===========================================
typedef struct {
    uint32_t timestamp;         // Unix timestamp (seconds since epoch)
    float accel_x;              // Acceleration X-axis (g)
    float accel_y;              // Acceleration Y-axis (g)
    float accel_z;              // Acceleration Z-axis (g)
    float gyro_x;               // Gyroscope X-axis (deg/s)
    float gyro_y;               // Gyroscope Y-axis (deg/s)
    float gyro_z;               // Gyroscope Z-axis (deg/s)
    float temperature;          // Temperature (°C)
    float vibration_rms;        // Calculated RMS vibration (g)
    float vibration_peak;       // Peak vibration (g)
    uint8_t battery_level;      // Battery level (0-100%)
    float battery_voltage;      // Battery voltage (V)
    uint8_t flags;              // Alert flags
} sensor_data_t;

// ===========================================
// MPU6050 Raw Data
// ===========================================
typedef struct {
    int16_t accel_x_raw;
    int16_t accel_y_raw;
    int16_t accel_z_raw;
    int16_t gyro_x_raw;
    int16_t gyro_y_raw;
    int16_t gyro_z_raw;
    int16_t temp_raw;
} mpu6050_raw_data_t;

// ===========================================
// Vibration Statistics (for FFT/analysis)
// ===========================================
typedef struct {
    float rms;                  // Root Mean Square
    float peak;                 // Peak value
    float crest_factor;         // Peak / RMS
    float dominant_freq;        // Dominant frequency (Hz)
    float spectrum[64];         // FFT spectrum bins
} vibration_stats_t;

// ===========================================
// Device Status
// ===========================================
typedef struct {
    bool mpu6050_ok;
    bool ds18b20_ok;
    bool battery_ok;
    uint8_t battery_level;
    float battery_voltage;
    bool charging;
    uint32_t uptime_seconds;
    uint32_t readings_count;
    uint32_t errors_count;
} device_status_t;

#ifdef __cplusplus
}
#endif

#endif // SENSOR_TYPES_H
