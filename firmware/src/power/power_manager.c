/**
 * VibeMon Power Manager Implementation
 */

#include "power_manager.h"
#include "../config.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_sleep.h"
#include "esp_timer.h"
#include "driver/rtc_io.h"

static const char *TAG = "POWER_MGR";

static power_mode_t current_mode = POWER_MODE_NORMAL;
static uint64_t last_activity_time = 0;
static bool auto_sleep_enabled = true;

esp_err_t power_manager_init(void) {
    ESP_LOGI(TAG, "Initializing power manager...");
    
    // Configure wake-up sources
    esp_sleep_enable_ext0_wakeup(BUTTON_GPIO, 0);  // Wake on button press (low)
    
    // Configure RTC GPIO for wake-up
    rtc_gpio_pullup_en(BUTTON_GPIO);
    rtc_gpio_pulldown_dis(BUTTON_GPIO);
    
    last_activity_time = esp_timer_get_time();
    
    ESP_LOGI(TAG, "Power manager initialized");
    return ESP_OK;
}

void power_manager_check_sleep(void) {
    if (!auto_sleep_enabled) return;
    
    uint64_t now = esp_timer_get_time();
    uint64_t idle_time = now - last_activity_time;
    
    if (idle_time > (SLEEP_TIMEOUT_MS * 1000)) {
        ESP_LOGI(TAG, "Idle timeout reached, entering deep sleep");
        power_manager_enter_deep_sleep(DEEP_SLEEP_TIME_US);
    }
}

void power_manager_enter_deep_sleep(uint64_t sleep_time_us) {
    ESP_LOGI(TAG, "Entering deep sleep for %llu us", sleep_time_us);
    
    if (sleep_time_us > 0) {
        esp_sleep_enable_timer_wakeup(sleep_time_us);
    }
    
    esp_deep_sleep_start();
}

void power_manager_set_mode(power_mode_t mode) {
    current_mode = mode;
    ESP_LOGI(TAG, "Power mode set to %d", mode);
}

power_mode_t power_manager_get_mode(void) {
    return current_mode;
}

void power_manager_reset_activity(void) {
    last_activity_time = esp_timer_get_time();
}

void power_manager_set_auto_sleep(bool enable) {
    auto_sleep_enabled = enable;
    ESP_LOGI(TAG, "Auto-sleep %s", enable ? "enabled" : "disabled");
}
