/**
 * VibeMon BLE Manager Header
 * Handles all BLE communication
 */

#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"
#include "../sensors/sensor_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// ===========================================
// BLE Connection State
// ===========================================
typedef enum {
    BLE_STATE_IDLE,
    BLE_STATE_ADVERTISING,
    BLE_STATE_CONNECTED,
    BLE_STATE_DISCONNECTING,
    BLE_STATE_OTA_MODE
} ble_state_t;

// ===========================================
// BLE Event Types
// ===========================================
typedef enum {
    BLE_EVENT_CONNECTED,
    BLE_EVENT_DISCONNECTED,
    BLE_EVENT_MTU_CHANGED,
    BLE_EVENT_DATA_RECEIVED,
    BLE_EVENT_NOTIFY_ENABLED,
    BLE_EVENT_NOTIFY_DISABLED,
    BLE_EVENT_OTA_START,
    BLE_EVENT_OTA_DATA,
    BLE_EVENT_OTA_COMPLETE
} ble_event_type_t;

// ===========================================
// BLE Event Data
// ===========================================
typedef struct {
    ble_event_type_t type;
    union {
        struct {
            uint16_t conn_id;
            uint8_t addr[6];
        } connect;
        struct {
            uint16_t mtu;
        } mtu;
        struct {
            uint16_t handle;
            uint8_t *data;
            uint16_t len;
        } data;
    };
} ble_event_t;

// ===========================================
// BLE Event Callback
// ===========================================
typedef void (*ble_event_callback_t)(ble_event_t *event);

// ===========================================
// Public Functions
// ===========================================

/**
 * Initialize BLE subsystem
 * @return ESP_OK on success
 */
esp_err_t ble_manager_init(void);

/**
 * Deinitialize BLE subsystem
 * @return ESP_OK on success
 */
esp_err_t ble_manager_deinit(void);

/**
 * Start BLE advertising
 * @return ESP_OK on success
 */
esp_err_t ble_manager_start_advertising(void);

/**
 * Stop BLE advertising
 * @return ESP_OK on success
 */
esp_err_t ble_manager_stop_advertising(void);

/**
 * Process BLE events (call from BLE task)
 */
void ble_manager_process(void);

/**
 * Check if device is connected
 * @return true if connected
 */
bool ble_manager_is_connected(void);

/**
 * Get current BLE state
 * @return Current BLE state
 */
ble_state_t ble_manager_get_state(void);

/**
 * Get connected device address
 * @param addr Buffer to store address (6 bytes)
 * @return ESP_OK if connected
 */
esp_err_t ble_manager_get_peer_addr(uint8_t *addr);

/**
 * Queue sensor data for transmission
 * @param data Sensor data to send
 * @return ESP_OK on success
 */
esp_err_t ble_manager_queue_data(const sensor_data_t *data);

/**
 * Send notification to connected device
 * @param char_handle Characteristic handle
 * @param data Data to send
 * @param len Data length
 * @return ESP_OK on success
 */
esp_err_t ble_manager_send_notify(uint16_t char_handle, const uint8_t *data, uint16_t len);

/**
 * Send indication to connected device (with acknowledgment)
 * @param char_handle Characteristic handle
 * @param data Data to send
 * @param len Data length
 * @return ESP_OK on success
 */
esp_err_t ble_manager_send_indicate(uint16_t char_handle, const uint8_t *data, uint16_t len);

/**
 * Register event callback
 * @param callback Callback function
 */
void ble_manager_register_callback(ble_event_callback_t callback);

/**
 * Disconnect from connected device
 * @return ESP_OK on success
 */
esp_err_t ble_manager_disconnect(void);

/**
 * Enter OTA mode
 * @return ESP_OK on success
 */
esp_err_t ble_manager_enter_ota_mode(void);

/**
 * Get current MTU size
 * @return MTU size
 */
uint16_t ble_manager_get_mtu(void);

#ifdef __cplusplus
}
#endif

#endif // BLE_MANAGER_H
