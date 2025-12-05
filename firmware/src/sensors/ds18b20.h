/**
 * VibeMon DS18B20 Temperature Sensor Header
 */

#ifndef DS18B20_H
#define DS18B20_H

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize DS18B20 sensor
 * @return ESP_OK on success
 */
esp_err_t ds18b20_init(void);

/**
 * Deinitialize DS18B20 sensor
 * @return ESP_OK on success
 */
esp_err_t ds18b20_deinit(void);

/**
 * Read temperature from DS18B20
 * @param temperature Output for temperature in °C
 * @return ESP_OK on success
 */
esp_err_t ds18b20_read_temperature(float *temperature);

/**
 * Set temperature resolution
 * @param resolution Resolution in bits (9-12)
 * @return ESP_OK on success
 */
esp_err_t ds18b20_set_resolution(uint8_t resolution);

/**
 * Get sensor ROM code (64-bit unique ID)
 * @param rom_code Output buffer (8 bytes)
 * @return ESP_OK on success
 */
esp_err_t ds18b20_get_rom_code(uint8_t *rom_code);

/**
 * Check if sensor is connected
 * @return true if connected
 */
bool ds18b20_is_connected(void);

#ifdef __cplusplus
}
#endif

#endif // DS18B20_H
