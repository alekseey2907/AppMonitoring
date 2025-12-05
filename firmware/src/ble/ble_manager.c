/**
 * VibeMon BLE Manager Implementation
 * Handles BLE GATT Server and all BLE communication
 */

#include "ble_manager.h"
#include "../config.h"

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"

#include "esp_log.h"
#include "esp_bt.h"
#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_bt_main.h"
#include "esp_gatt_common_api.h"

static const char *TAG = "BLE_MANAGER";

// ===========================================
// Private Variables
// ===========================================
static ble_state_t ble_state = BLE_STATE_IDLE;
static uint16_t ble_conn_id = 0;
static uint16_t ble_mtu = 23;  // Default BLE MTU
static uint8_t peer_addr[6] = {0};
static ble_event_callback_t event_callback = NULL;
static SemaphoreHandle_t ble_mutex = NULL;
static QueueHandle_t data_queue = NULL;

// GATT handles
static uint16_t gatts_if = ESP_GATT_IF_NONE;
static uint16_t telemetry_handle_table[4];  // Telemetry service handles
static uint16_t control_handle_table[4];    // Control service handles
static uint16_t ota_handle_table[3];        // OTA service handles

// ===========================================
// UUID Definitions
// ===========================================
// 128-bit base UUID: xxxxxxxx-0000-1000-8000-00805F9B34FB
static const uint8_t SERVICE_TELEMETRY_UUID[16] = {
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80,
    0x00, 0x10, 0x00, 0x00, 0x01, 0x00, 0x00, 0xA0
};

static const uint8_t CHAR_VIBRATION_UUID[16] = {
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80,
    0x00, 0x10, 0x00, 0x00, 0x02, 0x00, 0x00, 0xA0
};

static const uint8_t CHAR_TEMPERATURE_UUID[16] = {
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80,
    0x00, 0x10, 0x00, 0x00, 0x03, 0x00, 0x00, 0xA0
};

static const uint8_t SERVICE_CONTROL_UUID[16] = {
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80,
    0x00, 0x10, 0x00, 0x00, 0x01, 0x00, 0x00, 0xB0
};

static const uint8_t SERVICE_OTA_UUID[16] = {
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80,
    0x00, 0x10, 0x00, 0x00, 0x01, 0x00, 0x00, 0xC0
};

// ===========================================
// Advertising Data
// ===========================================
static esp_ble_adv_data_t adv_data = {
    .set_scan_rsp = false,
    .include_name = true,
    .include_txpower = true,
    .min_interval = 0x0006,
    .max_interval = 0x0010,
    .appearance = 0x00,
    .manufacturer_len = 0,
    .p_manufacturer_data = NULL,
    .service_data_len = 0,
    .p_service_data = NULL,
    .service_uuid_len = 0,
    .p_service_uuid = NULL,
    .flag = (ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT),
};

static esp_ble_adv_params_t adv_params = {
    .adv_int_min = 0x20,
    .adv_int_max = 0x40,
    .adv_type = ADV_TYPE_IND,
    .own_addr_type = BLE_ADDR_TYPE_PUBLIC,
    .channel_map = ADV_CHNL_ALL,
    .adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,
};

// ===========================================
// GATT Service Definitions
// ===========================================
static const uint16_t PRIMARY_SERVICE_UUID = ESP_GATT_UUID_PRI_SERVICE;
static const uint16_t CHAR_DECLARATION_UUID = ESP_GATT_UUID_CHAR_DECLARE;
static const uint16_t CHAR_CLIENT_CONFIG_UUID = ESP_GATT_UUID_CHAR_CLIENT_CONFIG;

static const uint8_t char_prop_read_notify = ESP_GATT_CHAR_PROP_BIT_READ | ESP_GATT_CHAR_PROP_BIT_NOTIFY;
static const uint8_t char_prop_read_write = ESP_GATT_CHAR_PROP_BIT_READ | ESP_GATT_CHAR_PROP_BIT_WRITE;
static const uint8_t char_prop_write = ESP_GATT_CHAR_PROP_BIT_WRITE;

// Telemetry Service attributes
static const esp_gatts_attr_db_t telemetry_gatt_db[] = {
    // Service Declaration
    [0] = {
        {ESP_GATT_AUTO_RSP},
        {ESP_UUID_LEN_16, (uint8_t *)&PRIMARY_SERVICE_UUID, ESP_GATT_PERM_READ,
         sizeof(SERVICE_TELEMETRY_UUID), sizeof(SERVICE_TELEMETRY_UUID), (uint8_t *)SERVICE_TELEMETRY_UUID}
    },
    // Vibration Characteristic Declaration
    [1] = {
        {ESP_GATT_AUTO_RSP},
        {ESP_UUID_LEN_16, (uint8_t *)&CHAR_DECLARATION_UUID, ESP_GATT_PERM_READ,
         sizeof(uint8_t), sizeof(char_prop_read_notify), (uint8_t *)&char_prop_read_notify}
    },
    // Vibration Characteristic Value
    [2] = {
        {ESP_GATT_AUTO_RSP},
        {ESP_UUID_LEN_128, (uint8_t *)CHAR_VIBRATION_UUID, ESP_GATT_PERM_READ,
         20, 0, NULL}
    },
    // Vibration CCCD
    [3] = {
        {ESP_GATT_AUTO_RSP},
        {ESP_UUID_LEN_16, (uint8_t *)&CHAR_CLIENT_CONFIG_UUID, ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE,
         2, 0, NULL}
    },
};

// ===========================================
// GAP Event Handler
// ===========================================
static void gap_event_handler(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
    switch (event) {
        case ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT:
            ESP_LOGI(TAG, "Advertising data set complete");
            esp_ble_gap_start_advertising(&adv_params);
            break;
            
        case ESP_GAP_BLE_ADV_START_COMPLETE_EVT:
            if (param->adv_start_cmpl.status == ESP_BT_STATUS_SUCCESS) {
                ESP_LOGI(TAG, "Advertising started");
                ble_state = BLE_STATE_ADVERTISING;
            } else {
                ESP_LOGE(TAG, "Advertising start failed");
            }
            break;
            
        case ESP_GAP_BLE_ADV_STOP_COMPLETE_EVT:
            ESP_LOGI(TAG, "Advertising stopped");
            break;
            
        case ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT:
            ESP_LOGI(TAG, "Connection params updated: interval=%d, latency=%d, timeout=%d",
                     param->update_conn_params.interval,
                     param->update_conn_params.latency,
                     param->update_conn_params.timeout);
            break;
            
        default:
            break;
    }
}

// ===========================================
// GATT Server Event Handler
// ===========================================
static void gatts_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatt_if,
                                esp_ble_gatts_cb_param_t *param) {
    switch (event) {
        case ESP_GATTS_REG_EVT:
            if (param->reg.status == ESP_GATT_OK) {
                ESP_LOGI(TAG, "GATT server registered, app_id=%d", param->reg.app_id);
                gatts_if = gatt_if;
                
                // Set device name
                esp_ble_gap_set_device_name(config_get_device_name());
                
                // Configure advertising data
                esp_ble_gap_config_adv_data(&adv_data);
                
                // Create attribute table for telemetry service
                esp_ble_gatts_create_attr_tab(telemetry_gatt_db, gatt_if,
                    sizeof(telemetry_gatt_db) / sizeof(telemetry_gatt_db[0]), 0);
            } else {
                ESP_LOGE(TAG, "GATT server registration failed, status=%d", param->reg.status);
            }
            break;
            
        case ESP_GATTS_CREAT_ATTR_TAB_EVT:
            if (param->add_attr_tab.status == ESP_GATT_OK) {
                ESP_LOGI(TAG, "Attribute table created, num_handle=%d", param->add_attr_tab.num_handle);
                memcpy(telemetry_handle_table, param->add_attr_tab.handles,
                       sizeof(telemetry_handle_table));
                esp_ble_gatts_start_service(telemetry_handle_table[0]);
            }
            break;
            
        case ESP_GATTS_START_EVT:
            ESP_LOGI(TAG, "Service started, handle=%d", param->start.service_handle);
            break;
            
        case ESP_GATTS_CONNECT_EVT:
            ESP_LOGI(TAG, "Client connected, conn_id=%d", param->connect.conn_id);
            ble_conn_id = param->connect.conn_id;
            memcpy(peer_addr, param->connect.remote_bda, 6);
            ble_state = BLE_STATE_CONNECTED;
            
            // Update connection parameters for better throughput
            esp_ble_conn_update_params_t conn_params = {0};
            memcpy(conn_params.bda, param->connect.remote_bda, sizeof(esp_bd_addr_t));
            conn_params.min_int = 0x06;  // 7.5ms
            conn_params.max_int = 0x10;  // 20ms
            conn_params.latency = 0;
            conn_params.timeout = 400;   // 4 seconds
            esp_ble_gap_update_conn_params(&conn_params);
            
            // Notify via callback
            if (event_callback) {
                ble_event_t evt = {
                    .type = BLE_EVENT_CONNECTED,
                    .connect = {
                        .conn_id = param->connect.conn_id
                    }
                };
                memcpy(evt.connect.addr, param->connect.remote_bda, 6);
                event_callback(&evt);
            }
            break;
            
        case ESP_GATTS_DISCONNECT_EVT:
            ESP_LOGI(TAG, "Client disconnected, reason=0x%x", param->disconnect.reason);
            ble_state = BLE_STATE_IDLE;
            
            // Notify via callback
            if (event_callback) {
                ble_event_t evt = {.type = BLE_EVENT_DISCONNECTED};
                event_callback(&evt);
            }
            
            // Restart advertising
            esp_ble_gap_start_advertising(&adv_params);
            break;
            
        case ESP_GATTS_MTU_EVT:
            ESP_LOGI(TAG, "MTU changed to %d", param->mtu.mtu);
            ble_mtu = param->mtu.mtu;
            
            if (event_callback) {
                ble_event_t evt = {
                    .type = BLE_EVENT_MTU_CHANGED,
                    .mtu = {.mtu = param->mtu.mtu}
                };
                event_callback(&evt);
            }
            break;
            
        case ESP_GATTS_READ_EVT:
            ESP_LOGI(TAG, "Read request, handle=%d", param->read.handle);
            break;
            
        case ESP_GATTS_WRITE_EVT:
            ESP_LOGI(TAG, "Write request, handle=%d, len=%d", param->write.handle, param->write.len);
            
            if (event_callback) {
                ble_event_t evt = {
                    .type = BLE_EVENT_DATA_RECEIVED,
                    .data = {
                        .handle = param->write.handle,
                        .data = param->write.value,
                        .len = param->write.len
                    }
                };
                event_callback(&evt);
            }
            break;
            
        case ESP_GATTS_CONF_EVT:
            ESP_LOGD(TAG, "Confirm received, status=%d", param->conf.status);
            break;
            
        default:
            break;
    }
}

// ===========================================
// Public Functions
// ===========================================

esp_err_t ble_manager_init(void) {
    esp_err_t ret;
    
    ESP_LOGI(TAG, "Initializing BLE manager...");
    
    // Create mutex
    ble_mutex = xSemaphoreCreateMutex();
    if (!ble_mutex) {
        ESP_LOGE(TAG, "Failed to create mutex");
        return ESP_FAIL;
    }
    
    // Create data queue
    data_queue = xQueueCreate(20, sizeof(sensor_data_t));
    if (!data_queue) {
        ESP_LOGE(TAG, "Failed to create data queue");
        return ESP_FAIL;
    }
    
    // Release memory for classic BT (we only use BLE)
    ESP_ERROR_CHECK(esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT));
    
    // Initialize BT controller
    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    ret = esp_bt_controller_init(&bt_cfg);
    if (ret) {
        ESP_LOGE(TAG, "BT controller init failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Enable BT controller in BLE mode
    ret = esp_bt_controller_enable(ESP_BT_MODE_BLE);
    if (ret) {
        ESP_LOGE(TAG, "BT controller enable failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Initialize Bluedroid
    ret = esp_bluedroid_init();
    if (ret) {
        ESP_LOGE(TAG, "Bluedroid init failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ret = esp_bluedroid_enable();
    if (ret) {
        ESP_LOGE(TAG, "Bluedroid enable failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Register callbacks
    ret = esp_ble_gatts_register_callback(gatts_event_handler);
    if (ret) {
        ESP_LOGE(TAG, "GATTS callback register failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ret = esp_ble_gap_register_callback(gap_event_handler);
    if (ret) {
        ESP_LOGE(TAG, "GAP callback register failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Register GATT server application
    ret = esp_ble_gatts_app_register(0);
    if (ret) {
        ESP_LOGE(TAG, "GATTS app register failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Set MTU size
    ret = esp_ble_gatt_set_local_mtu(BLE_MTU_SIZE);
    if (ret) {
        ESP_LOGE(TAG, "Set MTU failed: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ESP_LOGI(TAG, "BLE manager initialized successfully");
    return ESP_OK;
}

esp_err_t ble_manager_deinit(void) {
    ESP_LOGI(TAG, "Deinitializing BLE manager...");
    
    esp_bluedroid_disable();
    esp_bluedroid_deinit();
    esp_bt_controller_disable();
    esp_bt_controller_deinit();
    
    if (ble_mutex) {
        vSemaphoreDelete(ble_mutex);
        ble_mutex = NULL;
    }
    
    if (data_queue) {
        vQueueDelete(data_queue);
        data_queue = NULL;
    }
    
    ble_state = BLE_STATE_IDLE;
    return ESP_OK;
}

esp_err_t ble_manager_start_advertising(void) {
    ESP_LOGI(TAG, "Starting BLE advertising...");
    return esp_ble_gap_start_advertising(&adv_params);
}

esp_err_t ble_manager_stop_advertising(void) {
    ESP_LOGI(TAG, "Stopping BLE advertising...");
    return esp_ble_gap_stop_advertising();
}

void ble_manager_process(void) {
    sensor_data_t data;
    
    // Process queued data
    if (ble_state == BLE_STATE_CONNECTED) {
        if (xQueueReceive(data_queue, &data, 0) == pdTRUE) {
            // Prepare telemetry packet
            uint8_t packet[20];
            
            // Packet format: [timestamp(4)] [accel_x(2)] [accel_y(2)] [accel_z(2)] 
            //                [temp(2)] [battery(1)] [flags(1)] [reserved(6)]
            uint32_t timestamp = data.timestamp;
            memcpy(&packet[0], &timestamp, 4);
            
            int16_t ax = (int16_t)(data.accel_x * 1000);
            int16_t ay = (int16_t)(data.accel_y * 1000);
            int16_t az = (int16_t)(data.accel_z * 1000);
            int16_t temp = (int16_t)(data.temperature * 100);
            
            memcpy(&packet[4], &ax, 2);
            memcpy(&packet[6], &ay, 2);
            memcpy(&packet[8], &az, 2);
            memcpy(&packet[10], &temp, 2);
            packet[12] = data.battery_level;
            packet[13] = data.flags;
            
            // Send notification
            esp_ble_gatts_send_indicate(gatts_if, ble_conn_id,
                telemetry_handle_table[2], sizeof(packet), packet, false);
        }
    }
}

bool ble_manager_is_connected(void) {
    return ble_state == BLE_STATE_CONNECTED;
}

ble_state_t ble_manager_get_state(void) {
    return ble_state;
}

esp_err_t ble_manager_get_peer_addr(uint8_t *addr) {
    if (!ble_manager_is_connected()) {
        return ESP_ERR_INVALID_STATE;
    }
    memcpy(addr, peer_addr, 6);
    return ESP_OK;
}

esp_err_t ble_manager_queue_data(const sensor_data_t *data) {
    if (!data_queue) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (xQueueSend(data_queue, data, 0) != pdTRUE) {
        ESP_LOGW(TAG, "Data queue full, dropping data");
        return ESP_ERR_NO_MEM;
    }
    
    return ESP_OK;
}

esp_err_t ble_manager_send_notify(uint16_t char_handle, const uint8_t *data, uint16_t len) {
    if (ble_state != BLE_STATE_CONNECTED) {
        return ESP_ERR_INVALID_STATE;
    }
    
    return esp_ble_gatts_send_indicate(gatts_if, ble_conn_id, char_handle, len, (uint8_t *)data, false);
}

esp_err_t ble_manager_send_indicate(uint16_t char_handle, const uint8_t *data, uint16_t len) {
    if (ble_state != BLE_STATE_CONNECTED) {
        return ESP_ERR_INVALID_STATE;
    }
    
    return esp_ble_gatts_send_indicate(gatts_if, ble_conn_id, char_handle, len, (uint8_t *)data, true);
}

void ble_manager_register_callback(ble_event_callback_t callback) {
    event_callback = callback;
}

esp_err_t ble_manager_disconnect(void) {
    if (ble_state != BLE_STATE_CONNECTED) {
        return ESP_ERR_INVALID_STATE;
    }
    
    ble_state = BLE_STATE_DISCONNECTING;
    return esp_ble_gap_disconnect(peer_addr);
}

esp_err_t ble_manager_enter_ota_mode(void) {
    ESP_LOGI(TAG, "Entering OTA mode");
    ble_state = BLE_STATE_OTA_MODE;
    return ESP_OK;
}

uint16_t ble_manager_get_mtu(void) {
    return ble_mtu;
}
