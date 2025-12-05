/**
 * VibeMon Power Manager Header
 * Handles power management and sleep modes
 */

#ifndef POWER_MANAGER_H
#define POWER_MANAGER_H

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    POWER_MODE_NORMAL,
    POWER_MODE_LOW_POWER,
    POWER_MODE_DEEP_SLEEP
} power_mode_t;

/**
 * Initialize power manager
 * @return ESP_OK on success
 */
esp_err_t power_manager_init(void);

/**
 * Check if device should enter sleep mode
 */
void power_manager_check_sleep(void);

/**
 * Enter deep sleep mode
 * @param sleep_time_us Sleep duration in microseconds (0 for indefinite)
 */
void power_manager_enter_deep_sleep(uint64_t sleep_time_us);

/**
 * Set power mode
 * @param mode Power mode to set
 */
void power_manager_set_mode(power_mode_t mode);

/**
 * Get current power mode
 * @return Current power mode
 */
power_mode_t power_manager_get_mode(void);

/**
 * Reset activity timer (call when device is active)
 */
void power_manager_reset_activity(void);

/**
 * Enable/disable auto-sleep
 * @param enable True to enable
 */
void power_manager_set_auto_sleep(bool enable);

#ifdef __cplusplus
}
#endif

#endif // POWER_MANAGER_H
