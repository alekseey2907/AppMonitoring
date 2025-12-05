/**
 * VibeMon Sensor Manager Header
 * Unified interface for all sensors
 */

#ifndef SENSOR_MANAGER_H
#define SENSOR_MANAGER_H

#include "sensor_types.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize all sensors
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_init(void);

/**
 * Deinitialize all sensors
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_deinit(void);

/**
 * Read all sensor data
 * @param data Output structure for sensor data
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_read(sensor_data_t *data);

/**
 * Read only vibration/acceleration data
 * @param data Output structure for sensor data
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_read_vibration(sensor_data_t *data);

/**
 * Read only temperature data
 * @param temp Output for temperature value
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_read_temperature(float *temp);

/**
 * Read battery status
 * @param level Output for battery level (0-100%)
 * @param voltage Output for battery voltage
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_read_battery(uint8_t *level, float *voltage);

/**
 * Check thresholds and set alert flags
 * @param data Sensor data to check
 */
void sensor_manager_check_thresholds(sensor_data_t *data);

/**
 * Get device status
 * @param status Output structure for device status
 * @return ESP_OK on success
 */
esp_err_t sensor_manager_get_status(device_status_t *status);

/**
 * Perform sensor self-test
 * @return ESP_OK if all sensors pass
 */
esp_err_t sensor_manager_self_test(void);

/**
 * Calculate vibration statistics from buffer
 * @param buffer Array of sensor readings
 * @param count Number of readings
 * @param stats Output structure for statistics
 */
void sensor_manager_calc_vibration_stats(const sensor_data_t *buffer, 
                                          size_t count, 
                                          vibration_stats_t *stats);

/**
 * Enable/disable continuous sampling mode
 * @param enable True to enable
 * @param callback Callback function for each sample
 */
void sensor_manager_set_continuous_mode(bool enable, 
                                         void (*callback)(sensor_data_t *data));

#ifdef __cplusplus
}
#endif

#endif // SENSOR_MANAGER_H
