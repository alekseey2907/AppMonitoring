/**
 * VibeMon NVS Storage Header
 */

#ifndef NVS_STORAGE_H
#define NVS_STORAGE_H

#include <stdint.h>
#include "esp_err.h"
#include "../sensors/sensor_types.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t nvs_storage_init(void);
esp_err_t nvs_storage_buffer_data(const sensor_data_t *data);
esp_err_t nvs_storage_get_buffered_data(sensor_data_t *data, uint32_t *count);
esp_err_t nvs_storage_clear_buffer(void);
uint32_t nvs_storage_get_buffer_count(void);

#ifdef __cplusplus
}
#endif

#endif // NVS_STORAGE_H
