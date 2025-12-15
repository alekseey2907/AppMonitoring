/**
 * VibeMon Sensor Manager Implementation
 * Manages MPU6050 accelerometer and DS18B20 temperature sensor
 */

#include "sensor_manager.h"
#include "mpu6050.h"
#include "ds18b20.h"
#include "../config.h"

#include <string.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "driver/adc.h"
#include "esp_adc_cal.h"

static const char *TAG = "SENSOR_MANAGER";

// ===========================================
// Private Variables
// ===========================================
static bool initialized = false;
static device_status_t device_status = {0};
static uint32_t reading_count = 0;
static uint32_t error_count = 0;
static esp_adc_cal_characteristics_t adc_chars;

// Continuous mode
static bool continuous_mode = false;
static void (*continuous_callback)(sensor_data_t *data) = NULL;

// ===========================================
// Battery ADC Constants
// ===========================================
#define BATTERY_ADC_SAMPLES     64
#define BATTERY_VOLTAGE_DIVIDER 2.0f    // Voltage divider ratio
#define BATTERY_FULL_VOLTAGE    4.2f    // Fully charged LiPo
#define BATTERY_EMPTY_VOLTAGE   3.0f    // Empty LiPo

// ===========================================
// Private Functions
// ===========================================

// ВАЖНО: MPU6050 возвращает ускорение в "g" по осям.
// Если брать sqrt(ax^2+ay^2+az^2), то в покое получится ~1g (гравитация),
// и метрика почти не будет меняться даже при тряске/поворотах.
// Поэтому сначала оцениваем вектор гравитации НЧ-фильтром и вычитаем его
// (получаем динамическую составляющую вибрации), затем считаем модуль.
static float calculate_dynamic_vibration_g(float ax, float ay, float az) {
    // NЧ фильтр гравитации (alpha ближе к 1 => более медленная адаптация)
    // При sample rate ~100 Гц alpha=0.99 даёт частоту среза порядка ~0.16 Гц.
    const float alpha = 0.99f;

    static bool gravity_initialized = false;
    static float gx = 0.0f, gy = 0.0f, gz = 1.0f;

    if (!gravity_initialized) {
        gx = ax;
        gy = ay;
        gz = az;
        gravity_initialized = true;
    } else {
        gx = alpha * gx + (1.0f - alpha) * ax;
        gy = alpha * gy + (1.0f - alpha) * ay;
        gz = alpha * gz + (1.0f - alpha) * az;
    }

    const float dx = ax - gx;
    const float dy = ay - gy;
    const float dz = az - gz;

    return sqrtf(dx * dx + dy * dy + dz * dz);
}

static uint8_t voltage_to_percent(float voltage) {
    if (voltage >= BATTERY_FULL_VOLTAGE) return 100;
    if (voltage <= BATTERY_EMPTY_VOLTAGE) return 0;
    
    // Linear interpolation
    float percent = (voltage - BATTERY_EMPTY_VOLTAGE) / 
                    (BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE) * 100.0f;
    return (uint8_t)percent;
}

static esp_err_t init_battery_adc(void) {
    // Configure ADC
    adc1_config_width(ADC_WIDTH_BIT_12);
    adc1_config_channel_atten(BATTERY_ADC_CHANNEL, BATTERY_ADC_ATTEN);
    
    // Characterize ADC
    esp_adc_cal_characterize(ADC_UNIT_1, BATTERY_ADC_ATTEN, 
                             ADC_WIDTH_BIT_12, 1100, &adc_chars);
    
    return ESP_OK;
}

static float read_battery_voltage(void) {
    uint32_t adc_reading = 0;
    
    // Average multiple samples
    for (int i = 0; i < BATTERY_ADC_SAMPLES; i++) {
        adc_reading += adc1_get_raw(BATTERY_ADC_CHANNEL);
    }
    adc_reading /= BATTERY_ADC_SAMPLES;
    
    // Convert to voltage
    uint32_t voltage_mv = esp_adc_cal_raw_to_voltage(adc_reading, &adc_chars);
    
    // Apply voltage divider correction
    return (voltage_mv / 1000.0f) * BATTERY_VOLTAGE_DIVIDER;
}

// ===========================================
// Public Functions
// ===========================================

esp_err_t sensor_manager_init(void) {
    esp_err_t ret;
    
    ESP_LOGI(TAG, "Initializing sensor manager...");
    
    // Initialize MPU6050
    ret = mpu6050_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "MPU6050 initialization failed!");
        device_status.mpu6050_ok = false;
        error_count++;
    } else {
        ESP_LOGI(TAG, "MPU6050 initialized");
        device_status.mpu6050_ok = true;
    }
    
    // Initialize DS18B20
    ret = ds18b20_init();
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "DS18B20 initialization failed!");
        device_status.ds18b20_ok = false;
        error_count++;
    } else {
        ESP_LOGI(TAG, "DS18B20 initialized");
        device_status.ds18b20_ok = true;
    }
    
    // Initialize battery ADC
    ret = init_battery_adc();
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "Battery ADC initialization failed!");
        device_status.battery_ok = false;
    } else {
        device_status.battery_ok = true;
    }
    
    // At least MPU6050 must work
    if (!device_status.mpu6050_ok) {
        ESP_LOGE(TAG, "Critical sensor (MPU6050) not available!");
        return ESP_FAIL;
    }
    
    initialized = true;
    ESP_LOGI(TAG, "Sensor manager initialized");
    return ESP_OK;
}

esp_err_t sensor_manager_deinit(void) {
    ESP_LOGI(TAG, "Deinitializing sensor manager...");
    
    mpu6050_deinit();
    ds18b20_deinit();
    
    initialized = false;
    return ESP_OK;
}

esp_err_t sensor_manager_read(sensor_data_t *data) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (!data) {
        return ESP_ERR_INVALID_ARG;
    }
    
    memset(data, 0, sizeof(sensor_data_t));
    
    // Get timestamp
    data->timestamp = (uint32_t)(esp_timer_get_time() / 1000000);
    
    // Read MPU6050
    if (device_status.mpu6050_ok) {
        mpu6050_data_t mpu_data;
        if (mpu6050_read(&mpu_data) == ESP_OK) {
            data->accel_x = mpu_data.accel_x;
            data->accel_y = mpu_data.accel_y;
            data->accel_z = mpu_data.accel_z;
            data->gyro_x = mpu_data.gyro_x;
            data->gyro_y = mpu_data.gyro_y;
            data->gyro_z = mpu_data.gyro_z;
            
            // Calculate vibration metrics (динамическая составляющая без гравитации)
            data->vibration_rms = calculate_dynamic_vibration_g(data->accel_x, data->accel_y, data->accel_z);

            // Peak по динамической составляющей (приближённо)
            // Для простоты используем отклонения от оценённой гравитации через два вызова:
            // сохраняем peak как максимум мгновенного модуля динамики.
            data->vibration_peak = fmaxf(data->vibration_peak, data->vibration_rms);
        } else {
            error_count++;
            data->flags |= ALERT_FLAG_SENSOR_ERROR;
        }
    }
    
    // Read DS18B20
    if (device_status.ds18b20_ok) {
        float temp;
        if (ds18b20_read_temperature(&temp) == ESP_OK) {
            data->temperature = temp;
        } else {
            // Try internal MPU6050 temperature as fallback
            mpu6050_read_temperature(&data->temperature);
        }
    } else {
        // Use MPU6050 internal temperature
        mpu6050_read_temperature(&data->temperature);
    }
    
    // Read battery
    if (device_status.battery_ok) {
        data->battery_voltage = read_battery_voltage();
        data->battery_level = voltage_to_percent(data->battery_voltage);
    }
    
    reading_count++;
    device_status.readings_count = reading_count;
    device_status.errors_count = error_count;
    
    return ESP_OK;
}

esp_err_t sensor_manager_read_vibration(sensor_data_t *data) {
    if (!initialized || !device_status.mpu6050_ok) {
        return ESP_ERR_INVALID_STATE;
    }
    
    mpu6050_data_t mpu_data;
    esp_err_t ret = mpu6050_read(&mpu_data);
    if (ret != ESP_OK) {
        return ret;
    }
    
    data->timestamp = (uint32_t)(esp_timer_get_time() / 1000000);
    data->accel_x = mpu_data.accel_x;
    data->accel_y = mpu_data.accel_y;
    data->accel_z = mpu_data.accel_z;
    data->gyro_x = mpu_data.gyro_x;
    data->gyro_y = mpu_data.gyro_y;
    data->gyro_z = mpu_data.gyro_z;
    data->vibration_rms = calculate_dynamic_vibration_g(data->accel_x, data->accel_y, data->accel_z);
    data->vibration_peak = fmaxf(data->vibration_peak, data->vibration_rms);
    
    return ESP_OK;
}

esp_err_t sensor_manager_read_temperature(float *temp) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (device_status.ds18b20_ok) {
        return ds18b20_read_temperature(temp);
    } else {
        return mpu6050_read_temperature(temp);
    }
}

esp_err_t sensor_manager_read_battery(uint8_t *level, float *voltage) {
    if (!initialized || !device_status.battery_ok) {
        return ESP_ERR_INVALID_STATE;
    }
    
    float v = read_battery_voltage();
    if (voltage) *voltage = v;
    if (level) *level = voltage_to_percent(v);
    
    return ESP_OK;
}

void sensor_manager_check_thresholds(sensor_data_t *data) {
    if (!data) return;
    
    float vib_warn, vib_crit, temp_warn, temp_crit;
    config_get_vibration_thresholds(&vib_warn, &vib_crit);
    config_get_temp_thresholds(&temp_warn, &temp_crit);
    
    data->flags = ALERT_FLAG_NONE;
    
    // Check vibration
    if (data->vibration_rms >= vib_crit) {
        data->flags |= ALERT_FLAG_VIBRATION_CRIT;
        ESP_LOGW(TAG, "CRITICAL: Vibration %.2f g", data->vibration_rms);
    } else if (data->vibration_rms >= vib_warn) {
        data->flags |= ALERT_FLAG_VIBRATION_WARN;
        ESP_LOGW(TAG, "WARNING: Vibration %.2f g", data->vibration_rms);
    }
    
    // Check temperature
    if (data->temperature >= temp_crit) {
        data->flags |= ALERT_FLAG_TEMP_CRIT;
        ESP_LOGW(TAG, "CRITICAL: Temperature %.1f °C", data->temperature);
    } else if (data->temperature >= temp_warn) {
        data->flags |= ALERT_FLAG_TEMP_WARN;
        ESP_LOGW(TAG, "WARNING: Temperature %.1f °C", data->temperature);
    }
    
    // Check battery
    if (data->battery_level <= BATTERY_LOW_THRESHOLD) {
        data->flags |= ALERT_FLAG_BATTERY_LOW;
        ESP_LOGW(TAG, "WARNING: Battery low %d%%", data->battery_level);
    }
}

esp_err_t sensor_manager_get_status(device_status_t *status) {
    if (!status) {
        return ESP_ERR_INVALID_ARG;
    }
    
    memcpy(status, &device_status, sizeof(device_status_t));
    
    // Update uptime
    status->uptime_seconds = (uint32_t)(esp_timer_get_time() / 1000000);
    
    // Update battery
    if (device_status.battery_ok) {
        status->battery_voltage = read_battery_voltage();
        status->battery_level = voltage_to_percent(status->battery_voltage);
    }
    
    return ESP_OK;
}

esp_err_t sensor_manager_self_test(void) {
    ESP_LOGI(TAG, "Running sensor self-test...");
    
    esp_err_t result = ESP_OK;
    
    // Test MPU6050
    if (device_status.mpu6050_ok) {
        if (mpu6050_self_test() != ESP_OK) {
            ESP_LOGE(TAG, "MPU6050 self-test FAILED");
            result = ESP_FAIL;
        } else {
            ESP_LOGI(TAG, "MPU6050 self-test PASSED");
        }
    }
    
    // Test DS18B20
    if (device_status.ds18b20_ok) {
        float temp;
        if (ds18b20_read_temperature(&temp) != ESP_OK || temp < -40 || temp > 125) {
            ESP_LOGE(TAG, "DS18B20 self-test FAILED");
            result = ESP_FAIL;
        } else {
            ESP_LOGI(TAG, "DS18B20 self-test PASSED (%.1f °C)", temp);
        }
    }
    
    return result;
}

void sensor_manager_calc_vibration_stats(const sensor_data_t *buffer, 
                                          size_t count, 
                                          vibration_stats_t *stats) {
    if (!buffer || !stats || count == 0) return;
    
    float sum_sq = 0;
    float max_val = 0;
    
    for (size_t i = 0; i < count; i++) {
        float rms = buffer[i].vibration_rms;
        sum_sq += rms * rms;
        if (rms > max_val) max_val = rms;
    }
    
    stats->rms = sqrtf(sum_sq / count);
    stats->peak = max_val;
    stats->crest_factor = (stats->rms > 0) ? (stats->peak / stats->rms) : 0;
    
    // FFT would be calculated here in full implementation
    stats->dominant_freq = 0;  // Placeholder
    memset(stats->spectrum, 0, sizeof(stats->spectrum));
}

void sensor_manager_set_continuous_mode(bool enable, 
                                         void (*callback)(sensor_data_t *data)) {
    continuous_mode = enable;
    continuous_callback = callback;
    
    if (enable) {
        ESP_LOGI(TAG, "Continuous sampling mode enabled");
    } else {
        ESP_LOGI(TAG, "Continuous sampling mode disabled");
    }
}
