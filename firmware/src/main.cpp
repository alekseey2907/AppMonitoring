/**
 * VibeMon ESP32 Firmware
 * Main entry point
 * 
 * @author VibeMon Team
 * @version 1.0.0
 */

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "config.h"
#include "ble/ble_manager.h"
#include "sensors/sensor_manager.h"
#include "power/power_manager.h"
#include "storage/nvs_storage.h"
#include "utils/led_indicator.h"

static const char *TAG = "VIBEMON_MAIN";

// Task handles
static TaskHandle_t sensor_task_handle = NULL;
static TaskHandle_t ble_task_handle = NULL;

/**
 * Sensor reading task
 * Periodically reads vibration and temperature data
 */
void sensor_task(void *pvParameters) {
    ESP_LOGI(TAG, "Sensor task started");
    
    sensor_data_t data;
    
    while (1) {
        // Read sensors
        if (sensor_manager_read(&data) == ESP_OK) {
            // Check thresholds and generate alerts if needed
            sensor_manager_check_thresholds(&data);
            
            // Queue data for BLE transmission
            ble_manager_queue_data(&data);
            
            // Store in local buffer if not connected
            if (!ble_manager_is_connected()) {
                nvs_storage_buffer_data(&data);
            }
        }
        
        // Delay based on configured sample rate
        vTaskDelay(pdMS_TO_TICKS(config_get_sample_interval()));
    }
}

/**
 * BLE management task
 * Handles BLE advertising, connections, and data transmission
 */
void ble_task(void *pvParameters) {
    ESP_LOGI(TAG, "BLE task started");
    
    while (1) {
        // Process BLE events
        ble_manager_process();
        
        // Short delay
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

/**
 * Initialize all system components
 */
esp_err_t system_init(void) {
    esp_err_t ret;
    
    // Initialize NVS
    ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    
    // Load configuration from NVS
    ESP_LOGI(TAG, "Loading configuration...");
    config_load();
    
    // Initialize LED indicator
    ESP_LOGI(TAG, "Initializing LED indicator...");
    led_indicator_init();
    led_indicator_set_state(LED_STATE_INITIALIZING);
    
    // Initialize power management
    ESP_LOGI(TAG, "Initializing power management...");
    power_manager_init();
    
    // Initialize sensors
    ESP_LOGI(TAG, "Initializing sensors...");
    ret = sensor_manager_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize sensors!");
        led_indicator_set_state(LED_STATE_ERROR);
        return ret;
    }
    
    // Initialize BLE
    ESP_LOGI(TAG, "Initializing BLE...");
    ret = ble_manager_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize BLE!");
        led_indicator_set_state(LED_STATE_ERROR);
        return ret;
    }
    
    ESP_LOGI(TAG, "System initialization complete!");
    return ESP_OK;
}

/**
 * Application main entry point
 */
void app_main(void) {
    ESP_LOGI(TAG, "========================================");
    ESP_LOGI(TAG, "VibeMon ESP32 Firmware v%s", FIRMWARE_VERSION);
    ESP_LOGI(TAG, "========================================");
    
    // Initialize system
    if (system_init() != ESP_OK) {
        ESP_LOGE(TAG, "System initialization failed!");
        // Blink error LED and restart after delay
        vTaskDelay(pdMS_TO_TICKS(5000));
        esp_restart();
    }
    
    // Start advertising
    ble_manager_start_advertising();
    led_indicator_set_state(LED_STATE_ADVERTISING);
    
    // Create tasks
    xTaskCreate(
        sensor_task,
        "sensor_task",
        4096,
        NULL,
        5,
        &sensor_task_handle
    );
    
    xTaskCreate(
        ble_task,
        "ble_task",
        4096,
        NULL,
        6,
        &ble_task_handle
    );
    
    ESP_LOGI(TAG, "VibeMon started successfully!");
    
    // Main loop - handle power management
    while (1) {
        // Check for sleep conditions
        power_manager_check_sleep();
        
        // Delay
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
