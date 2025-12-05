/**
 * VibeMon MPU6050 Driver Implementation
 * Low-level I2C driver for MPU6050 accelerometer/gyroscope
 */

#include "mpu6050.h"
#include "../config.h"

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2c.h"
#include "esp_log.h"

static const char *TAG = "MPU6050";

// ===========================================
// MPU6050 Register Addresses
// ===========================================
#define MPU6050_REG_SELF_TEST_X     0x0D
#define MPU6050_REG_SELF_TEST_Y     0x0E
#define MPU6050_REG_SELF_TEST_Z     0x0F
#define MPU6050_REG_SELF_TEST_A     0x10
#define MPU6050_REG_SMPLRT_DIV      0x19
#define MPU6050_REG_CONFIG          0x1A
#define MPU6050_REG_GYRO_CONFIG     0x1B
#define MPU6050_REG_ACCEL_CONFIG    0x1C
#define MPU6050_REG_FIFO_EN         0x23
#define MPU6050_REG_INT_PIN_CFG     0x37
#define MPU6050_REG_INT_ENABLE      0x38
#define MPU6050_REG_INT_STATUS      0x3A
#define MPU6050_REG_ACCEL_XOUT_H    0x3B
#define MPU6050_REG_ACCEL_XOUT_L    0x3C
#define MPU6050_REG_ACCEL_YOUT_H    0x3D
#define MPU6050_REG_ACCEL_YOUT_L    0x3E
#define MPU6050_REG_ACCEL_ZOUT_H    0x3F
#define MPU6050_REG_ACCEL_ZOUT_L    0x40
#define MPU6050_REG_TEMP_OUT_H      0x41
#define MPU6050_REG_TEMP_OUT_L      0x42
#define MPU6050_REG_GYRO_XOUT_H     0x43
#define MPU6050_REG_GYRO_XOUT_L     0x44
#define MPU6050_REG_GYRO_YOUT_H     0x45
#define MPU6050_REG_GYRO_YOUT_L     0x46
#define MPU6050_REG_GYRO_ZOUT_H     0x47
#define MPU6050_REG_GYRO_ZOUT_L     0x48
#define MPU6050_REG_USER_CTRL       0x6A
#define MPU6050_REG_PWR_MGMT_1      0x6B
#define MPU6050_REG_PWR_MGMT_2      0x6C
#define MPU6050_REG_WHO_AM_I        0x75

// ===========================================
// Private Variables
// ===========================================
static bool initialized = false;
static mpu6050_accel_range_t current_accel_range = MPU6050_ACCEL_RANGE_4G;
static mpu6050_gyro_range_t current_gyro_range = MPU6050_GYRO_RANGE_500DPS;

// Calibration offsets
static float accel_offset_x = 0;
static float accel_offset_y = 0;
static float accel_offset_z = 0;
static float gyro_offset_x = 0;
static float gyro_offset_y = 0;
static float gyro_offset_z = 0;

// Scale factors
static float accel_scale = 8192.0f;  // For ±4g
static float gyro_scale = 65.5f;     // For ±500 deg/s

// ===========================================
// Private Functions
// ===========================================

static esp_err_t i2c_master_init(void) {
    i2c_config_t conf = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = I2C_MASTER_SDA_IO,
        .scl_io_num = I2C_MASTER_SCL_IO,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = I2C_MASTER_FREQ_HZ,
    };
    
    esp_err_t ret = i2c_param_config(I2C_MASTER_NUM, &conf);
    if (ret != ESP_OK) return ret;
    
    return i2c_driver_install(I2C_MASTER_NUM, conf.mode, 0, 0, 0);
}

static esp_err_t mpu6050_write_byte(uint8_t reg, uint8_t data) {
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (MPU6050_ADDR << 1) | I2C_MASTER_WRITE, true);
    i2c_master_write_byte(cmd, reg, true);
    i2c_master_write_byte(cmd, data, true);
    i2c_master_stop(cmd);
    
    esp_err_t ret = i2c_master_cmd_begin(I2C_MASTER_NUM, cmd, pdMS_TO_TICKS(100));
    i2c_cmd_link_delete(cmd);
    
    return ret;
}

static esp_err_t mpu6050_read_byte(uint8_t reg, uint8_t *data) {
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (MPU6050_ADDR << 1) | I2C_MASTER_WRITE, true);
    i2c_master_write_byte(cmd, reg, true);
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (MPU6050_ADDR << 1) | I2C_MASTER_READ, true);
    i2c_master_read_byte(cmd, data, I2C_MASTER_NACK);
    i2c_master_stop(cmd);
    
    esp_err_t ret = i2c_master_cmd_begin(I2C_MASTER_NUM, cmd, pdMS_TO_TICKS(100));
    i2c_cmd_link_delete(cmd);
    
    return ret;
}

static esp_err_t mpu6050_read_bytes(uint8_t reg, uint8_t *data, size_t len) {
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (MPU6050_ADDR << 1) | I2C_MASTER_WRITE, true);
    i2c_master_write_byte(cmd, reg, true);
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (MPU6050_ADDR << 1) | I2C_MASTER_READ, true);
    i2c_master_read(cmd, data, len, I2C_MASTER_LAST_NACK);
    i2c_master_stop(cmd);
    
    esp_err_t ret = i2c_master_cmd_begin(I2C_MASTER_NUM, cmd, pdMS_TO_TICKS(100));
    i2c_cmd_link_delete(cmd);
    
    return ret;
}

static void update_scale_factors(void) {
    // Accelerometer scale (LSB/g)
    switch (current_accel_range) {
        case MPU6050_ACCEL_RANGE_2G:  accel_scale = 16384.0f; break;
        case MPU6050_ACCEL_RANGE_4G:  accel_scale = 8192.0f; break;
        case MPU6050_ACCEL_RANGE_8G:  accel_scale = 4096.0f; break;
        case MPU6050_ACCEL_RANGE_16G: accel_scale = 2048.0f; break;
    }
    
    // Gyroscope scale (LSB/(deg/s))
    switch (current_gyro_range) {
        case MPU6050_GYRO_RANGE_250DPS:  gyro_scale = 131.0f; break;
        case MPU6050_GYRO_RANGE_500DPS:  gyro_scale = 65.5f; break;
        case MPU6050_GYRO_RANGE_1000DPS: gyro_scale = 32.8f; break;
        case MPU6050_GYRO_RANGE_2000DPS: gyro_scale = 16.4f; break;
    }
}

// ===========================================
// Public Functions
// ===========================================

esp_err_t mpu6050_init(void) {
    mpu6050_config_t config = {
        .accel_range = MPU6050_ACCEL_RANGE_4G,
        .gyro_range = MPU6050_GYRO_RANGE_500DPS,
        .dlpf = MPU6050_DLPF_BW_44,
        .sample_rate_div = 9  // 100Hz (1000 / (1 + 9))
    };
    
    return mpu6050_init_with_config(&config);
}

esp_err_t mpu6050_init_with_config(const mpu6050_config_t *config) {
    esp_err_t ret;
    
    ESP_LOGI(TAG, "Initializing MPU6050...");
    
    // Initialize I2C
    ret = i2c_master_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "I2C init failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Check device ID
    uint8_t who_am_i;
    ret = mpu6050_read_byte(MPU6050_REG_WHO_AM_I, &who_am_i);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to read WHO_AM_I register");
        return ret;
    }
    
    if (who_am_i != 0x68) {
        ESP_LOGE(TAG, "Invalid WHO_AM_I: 0x%02X (expected 0x68)", who_am_i);
        return ESP_ERR_NOT_FOUND;
    }
    
    ESP_LOGI(TAG, "MPU6050 found (WHO_AM_I: 0x%02X)", who_am_i);
    
    // Reset device
    ret = mpu6050_write_byte(MPU6050_REG_PWR_MGMT_1, 0x80);
    if (ret != ESP_OK) return ret;
    vTaskDelay(pdMS_TO_TICKS(100));
    
    // Wake up and set clock source to PLL with X-axis gyro
    ret = mpu6050_write_byte(MPU6050_REG_PWR_MGMT_1, 0x01);
    if (ret != ESP_OK) return ret;
    vTaskDelay(pdMS_TO_TICKS(10));
    
    // Set sample rate divider
    ret = mpu6050_write_byte(MPU6050_REG_SMPLRT_DIV, config->sample_rate_div);
    if (ret != ESP_OK) return ret;
    
    // Set DLPF
    ret = mpu6050_write_byte(MPU6050_REG_CONFIG, config->dlpf);
    if (ret != ESP_OK) return ret;
    
    // Set accelerometer range
    current_accel_range = config->accel_range;
    ret = mpu6050_write_byte(MPU6050_REG_ACCEL_CONFIG, current_accel_range << 3);
    if (ret != ESP_OK) return ret;
    
    // Set gyroscope range
    current_gyro_range = config->gyro_range;
    ret = mpu6050_write_byte(MPU6050_REG_GYRO_CONFIG, current_gyro_range << 3);
    if (ret != ESP_OK) return ret;
    
    // Update scale factors
    update_scale_factors();
    
    initialized = true;
    ESP_LOGI(TAG, "MPU6050 initialized successfully");
    
    return ESP_OK;
}

esp_err_t mpu6050_deinit(void) {
    if (!initialized) return ESP_OK;
    
    mpu6050_sleep();
    i2c_driver_delete(I2C_MASTER_NUM);
    initialized = false;
    
    return ESP_OK;
}

esp_err_t mpu6050_read(mpu6050_data_t *data) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    uint8_t buffer[14];
    esp_err_t ret = mpu6050_read_bytes(MPU6050_REG_ACCEL_XOUT_H, buffer, 14);
    if (ret != ESP_OK) {
        return ret;
    }
    
    // Parse accelerometer data
    int16_t ax_raw = (buffer[0] << 8) | buffer[1];
    int16_t ay_raw = (buffer[2] << 8) | buffer[3];
    int16_t az_raw = (buffer[4] << 8) | buffer[5];
    
    // Parse temperature data
    int16_t temp_raw = (buffer[6] << 8) | buffer[7];
    
    // Parse gyroscope data
    int16_t gx_raw = (buffer[8] << 8) | buffer[9];
    int16_t gy_raw = (buffer[10] << 8) | buffer[11];
    int16_t gz_raw = (buffer[12] << 8) | buffer[13];
    
    // Convert to physical units with calibration
    data->accel_x = (ax_raw / accel_scale) - accel_offset_x;
    data->accel_y = (ay_raw / accel_scale) - accel_offset_y;
    data->accel_z = (az_raw / accel_scale) - accel_offset_z;
    
    data->gyro_x = (gx_raw / gyro_scale) - gyro_offset_x;
    data->gyro_y = (gy_raw / gyro_scale) - gyro_offset_y;
    data->gyro_z = (gz_raw / gyro_scale) - gyro_offset_z;
    
    // Temperature: Temp in °C = (TEMP_OUT / 340) + 36.53
    data->temp = (temp_raw / 340.0f) + 36.53f;
    
    return ESP_OK;
}

esp_err_t mpu6050_read_accel(float *ax, float *ay, float *az) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    uint8_t buffer[6];
    esp_err_t ret = mpu6050_read_bytes(MPU6050_REG_ACCEL_XOUT_H, buffer, 6);
    if (ret != ESP_OK) {
        return ret;
    }
    
    int16_t ax_raw = (buffer[0] << 8) | buffer[1];
    int16_t ay_raw = (buffer[2] << 8) | buffer[3];
    int16_t az_raw = (buffer[4] << 8) | buffer[5];
    
    *ax = (ax_raw / accel_scale) - accel_offset_x;
    *ay = (ay_raw / accel_scale) - accel_offset_y;
    *az = (az_raw / accel_scale) - accel_offset_z;
    
    return ESP_OK;
}

esp_err_t mpu6050_read_gyro(float *gx, float *gy, float *gz) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    uint8_t buffer[6];
    esp_err_t ret = mpu6050_read_bytes(MPU6050_REG_GYRO_XOUT_H, buffer, 6);
    if (ret != ESP_OK) {
        return ret;
    }
    
    int16_t gx_raw = (buffer[0] << 8) | buffer[1];
    int16_t gy_raw = (buffer[2] << 8) | buffer[3];
    int16_t gz_raw = (buffer[4] << 8) | buffer[5];
    
    *gx = (gx_raw / gyro_scale) - gyro_offset_x;
    *gy = (gy_raw / gyro_scale) - gyro_offset_y;
    *gz = (gz_raw / gyro_scale) - gyro_offset_z;
    
    return ESP_OK;
}

esp_err_t mpu6050_read_temperature(float *temp) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    uint8_t buffer[2];
    esp_err_t ret = mpu6050_read_bytes(MPU6050_REG_TEMP_OUT_H, buffer, 2);
    if (ret != ESP_OK) {
        return ret;
    }
    
    int16_t temp_raw = (buffer[0] << 8) | buffer[1];
    *temp = (temp_raw / 340.0f) + 36.53f;
    
    return ESP_OK;
}

esp_err_t mpu6050_set_accel_range(mpu6050_accel_range_t range) {
    esp_err_t ret = mpu6050_write_byte(MPU6050_REG_ACCEL_CONFIG, range << 3);
    if (ret == ESP_OK) {
        current_accel_range = range;
        update_scale_factors();
    }
    return ret;
}

esp_err_t mpu6050_set_gyro_range(mpu6050_gyro_range_t range) {
    esp_err_t ret = mpu6050_write_byte(MPU6050_REG_GYRO_CONFIG, range << 3);
    if (ret == ESP_OK) {
        current_gyro_range = range;
        update_scale_factors();
    }
    return ret;
}

esp_err_t mpu6050_set_dlpf(mpu6050_dlpf_t dlpf) {
    return mpu6050_write_byte(MPU6050_REG_CONFIG, dlpf);
}

esp_err_t mpu6050_calibrate(void) {
    ESP_LOGI(TAG, "Calibrating MPU6050 (keep device stationary)...");
    
    float ax_sum = 0, ay_sum = 0, az_sum = 0;
    float gx_sum = 0, gy_sum = 0, gz_sum = 0;
    const int samples = 100;
    
    mpu6050_data_t data;
    
    // Temporarily disable offsets
    accel_offset_x = 0;
    accel_offset_y = 0;
    accel_offset_z = 0;
    gyro_offset_x = 0;
    gyro_offset_y = 0;
    gyro_offset_z = 0;
    
    for (int i = 0; i < samples; i++) {
        if (mpu6050_read(&data) == ESP_OK) {
            ax_sum += data.accel_x;
            ay_sum += data.accel_y;
            az_sum += data.accel_z;
            gx_sum += data.gyro_x;
            gy_sum += data.gyro_y;
            gz_sum += data.gyro_z;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    
    // Calculate offsets (Z-axis should be 1g at rest)
    accel_offset_x = ax_sum / samples;
    accel_offset_y = ay_sum / samples;
    accel_offset_z = (az_sum / samples) - 1.0f;  // Subtract 1g for gravity
    
    gyro_offset_x = gx_sum / samples;
    gyro_offset_y = gy_sum / samples;
    gyro_offset_z = gz_sum / samples;
    
    ESP_LOGI(TAG, "Calibration complete:");
    ESP_LOGI(TAG, "  Accel offsets: %.4f, %.4f, %.4f", 
             accel_offset_x, accel_offset_y, accel_offset_z);
    ESP_LOGI(TAG, "  Gyro offsets: %.2f, %.2f, %.2f", 
             gyro_offset_x, gyro_offset_y, gyro_offset_z);
    
    return ESP_OK;
}

esp_err_t mpu6050_self_test(void) {
    ESP_LOGI(TAG, "Running self-test...");
    
    // Read self-test registers
    uint8_t st_x, st_y, st_z, st_a;
    mpu6050_read_byte(MPU6050_REG_SELF_TEST_X, &st_x);
    mpu6050_read_byte(MPU6050_REG_SELF_TEST_Y, &st_y);
    mpu6050_read_byte(MPU6050_REG_SELF_TEST_Z, &st_z);
    mpu6050_read_byte(MPU6050_REG_SELF_TEST_A, &st_a);
    
    // Basic check - read some data
    mpu6050_data_t data;
    esp_err_t ret = mpu6050_read(&data);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Self-test FAILED: Cannot read data");
        return ESP_FAIL;
    }
    
    // Check for reasonable values
    if (data.accel_x < -16 || data.accel_x > 16 ||
        data.accel_y < -16 || data.accel_y > 16 ||
        data.accel_z < -16 || data.accel_z > 16) {
        ESP_LOGE(TAG, "Self-test FAILED: Accelerometer out of range");
        return ESP_FAIL;
    }
    
    ESP_LOGI(TAG, "Self-test PASSED");
    return ESP_OK;
}

esp_err_t mpu6050_sleep(void) {
    return mpu6050_write_byte(MPU6050_REG_PWR_MGMT_1, 0x40);  // Set SLEEP bit
}

esp_err_t mpu6050_wake(void) {
    return mpu6050_write_byte(MPU6050_REG_PWR_MGMT_1, 0x01);  // Clear SLEEP, use PLL
}

uint8_t mpu6050_get_device_id(void) {
    uint8_t id;
    mpu6050_read_byte(MPU6050_REG_WHO_AM_I, &id);
    return id;
}
