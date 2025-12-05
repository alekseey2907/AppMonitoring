/**
 * VibeMon MPU6050 Driver Header
 * Driver for MPU6050 accelerometer/gyroscope
 */

#ifndef MPU6050_H
#define MPU6050_H

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// ===========================================
// Configuration Enums
// ===========================================
typedef enum {
    MPU6050_ACCEL_RANGE_2G = 0,
    MPU6050_ACCEL_RANGE_4G = 1,
    MPU6050_ACCEL_RANGE_8G = 2,
    MPU6050_ACCEL_RANGE_16G = 3
} mpu6050_accel_range_t;

typedef enum {
    MPU6050_GYRO_RANGE_250DPS = 0,
    MPU6050_GYRO_RANGE_500DPS = 1,
    MPU6050_GYRO_RANGE_1000DPS = 2,
    MPU6050_GYRO_RANGE_2000DPS = 3
} mpu6050_gyro_range_t;

typedef enum {
    MPU6050_DLPF_BW_260 = 0,
    MPU6050_DLPF_BW_184 = 1,
    MPU6050_DLPF_BW_94 = 2,
    MPU6050_DLPF_BW_44 = 3,
    MPU6050_DLPF_BW_21 = 4,
    MPU6050_DLPF_BW_10 = 5,
    MPU6050_DLPF_BW_5 = 6
} mpu6050_dlpf_t;

// ===========================================
// Data Structures
// ===========================================
typedef struct {
    float accel_x;      // Acceleration in g
    float accel_y;
    float accel_z;
    float gyro_x;       // Angular velocity in deg/s
    float gyro_y;
    float gyro_z;
    float temp;         // Temperature in °C
} mpu6050_data_t;

typedef struct {
    mpu6050_accel_range_t accel_range;
    mpu6050_gyro_range_t gyro_range;
    mpu6050_dlpf_t dlpf;
    uint8_t sample_rate_div;
} mpu6050_config_t;

// ===========================================
// Public Functions
// ===========================================

/**
 * Initialize MPU6050 with default configuration
 * @return ESP_OK on success
 */
esp_err_t mpu6050_init(void);

/**
 * Initialize MPU6050 with custom configuration
 * @param config Configuration structure
 * @return ESP_OK on success
 */
esp_err_t mpu6050_init_with_config(const mpu6050_config_t *config);

/**
 * Deinitialize MPU6050
 * @return ESP_OK on success
 */
esp_err_t mpu6050_deinit(void);

/**
 * Read all sensor data
 * @param data Output structure
 * @return ESP_OK on success
 */
esp_err_t mpu6050_read(mpu6050_data_t *data);

/**
 * Read only accelerometer data
 * @param ax, ay, az Acceleration outputs in g
 * @return ESP_OK on success
 */
esp_err_t mpu6050_read_accel(float *ax, float *ay, float *az);

/**
 * Read only gyroscope data
 * @param gx, gy, gz Angular velocity outputs in deg/s
 * @return ESP_OK on success
 */
esp_err_t mpu6050_read_gyro(float *gx, float *gy, float *gz);

/**
 * Read temperature
 * @param temp Temperature output in °C
 * @return ESP_OK on success
 */
esp_err_t mpu6050_read_temperature(float *temp);

/**
 * Set accelerometer range
 * @param range Accelerometer range
 * @return ESP_OK on success
 */
esp_err_t mpu6050_set_accel_range(mpu6050_accel_range_t range);

/**
 * Set gyroscope range
 * @param range Gyroscope range
 * @return ESP_OK on success
 */
esp_err_t mpu6050_set_gyro_range(mpu6050_gyro_range_t range);

/**
 * Set digital low-pass filter
 * @param dlpf DLPF setting
 * @return ESP_OK on success
 */
esp_err_t mpu6050_set_dlpf(mpu6050_dlpf_t dlpf);

/**
 * Calibrate sensor (device must be stationary)
 * @return ESP_OK on success
 */
esp_err_t mpu6050_calibrate(void);

/**
 * Perform self-test
 * @return ESP_OK if self-test passes
 */
esp_err_t mpu6050_self_test(void);

/**
 * Enter sleep mode
 * @return ESP_OK on success
 */
esp_err_t mpu6050_sleep(void);

/**
 * Wake up from sleep mode
 * @return ESP_OK on success
 */
esp_err_t mpu6050_wake(void);

/**
 * Get device ID
 * @return Device ID (should be 0x68)
 */
uint8_t mpu6050_get_device_id(void);

#ifdef __cplusplus
}
#endif

#endif // MPU6050_H
