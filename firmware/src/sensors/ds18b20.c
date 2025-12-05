/**
 * VibeMon DS18B20 Temperature Sensor Implementation
 * OneWire driver for DS18B20 digital temperature sensor
 */

#include "ds18b20.h"
#include "../config.h"

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_timer.h"

static const char *TAG = "DS18B20";

// ===========================================
// OneWire Timing Constants (microseconds)
// ===========================================
#define OW_RESET_PULSE      480
#define OW_PRESENCE_WAIT    70
#define OW_PRESENCE_TIMEOUT 240
#define OW_SLOT_TIME        60
#define OW_WRITE_1_LOW      6
#define OW_WRITE_0_LOW      60
#define OW_READ_SAMPLE      9
#define OW_RECOVERY         10

// ===========================================
// DS18B20 Commands
// ===========================================
#define DS18B20_CMD_SEARCH_ROM      0xF0
#define DS18B20_CMD_READ_ROM        0x33
#define DS18B20_CMD_MATCH_ROM       0x55
#define DS18B20_CMD_SKIP_ROM        0xCC
#define DS18B20_CMD_CONVERT_T       0x44
#define DS18B20_CMD_READ_SCRATCHPAD 0xBE
#define DS18B20_CMD_WRITE_SCRATCHPAD 0x4E
#define DS18B20_CMD_COPY_SCRATCHPAD 0x48
#define DS18B20_CMD_READ_POWER      0xB4

// ===========================================
// Private Variables
// ===========================================
static bool initialized = false;
static uint8_t rom_code[8] = {0};
static uint8_t resolution = 12;  // Default 12-bit resolution

// ===========================================
// Private Functions - OneWire Low Level
// ===========================================

static inline void ow_delay_us(uint32_t us) {
    uint64_t start = esp_timer_get_time();
    while (esp_timer_get_time() - start < us);
}

static void ow_set_output(void) {
    gpio_set_direction(ONEWIRE_GPIO, GPIO_MODE_OUTPUT);
}

static void ow_set_input(void) {
    gpio_set_direction(ONEWIRE_GPIO, GPIO_MODE_INPUT);
}

static void ow_write_low(void) {
    gpio_set_level(ONEWIRE_GPIO, 0);
}

static void ow_write_high(void) {
    gpio_set_level(ONEWIRE_GPIO, 1);
}

static int ow_read(void) {
    return gpio_get_level(ONEWIRE_GPIO);
}

static bool ow_reset(void) {
    bool presence = false;
    
    // Pull low for reset pulse
    ow_set_output();
    ow_write_low();
    ow_delay_us(OW_RESET_PULSE);
    
    // Release line
    ow_set_input();
    ow_delay_us(OW_PRESENCE_WAIT);
    
    // Check for presence pulse (device pulls low)
    if (ow_read() == 0) {
        presence = true;
    }
    
    // Wait for end of presence pulse
    ow_delay_us(OW_PRESENCE_TIMEOUT);
    
    return presence;
}

static void ow_write_bit(uint8_t bit) {
    ow_set_output();
    ow_write_low();
    
    if (bit) {
        ow_delay_us(OW_WRITE_1_LOW);
        ow_set_input();
        ow_delay_us(OW_SLOT_TIME - OW_WRITE_1_LOW);
    } else {
        ow_delay_us(OW_WRITE_0_LOW);
        ow_set_input();
    }
    
    ow_delay_us(OW_RECOVERY);
}

static uint8_t ow_read_bit(void) {
    uint8_t bit = 0;
    
    ow_set_output();
    ow_write_low();
    ow_delay_us(OW_WRITE_1_LOW);
    
    ow_set_input();
    ow_delay_us(OW_READ_SAMPLE);
    
    if (ow_read()) {
        bit = 1;
    }
    
    ow_delay_us(OW_SLOT_TIME - OW_READ_SAMPLE);
    
    return bit;
}

static void ow_write_byte(uint8_t byte) {
    for (int i = 0; i < 8; i++) {
        ow_write_bit(byte & 0x01);
        byte >>= 1;
    }
}

static uint8_t ow_read_byte(void) {
    uint8_t byte = 0;
    
    for (int i = 0; i < 8; i++) {
        byte >>= 1;
        if (ow_read_bit()) {
            byte |= 0x80;
        }
    }
    
    return byte;
}

// ===========================================
// CRC8 Calculation
// ===========================================
static uint8_t crc8(const uint8_t *data, uint8_t len) {
    uint8_t crc = 0;
    
    for (uint8_t i = 0; i < len; i++) {
        uint8_t byte = data[i];
        for (uint8_t j = 0; j < 8; j++) {
            uint8_t mix = (crc ^ byte) & 0x01;
            crc >>= 1;
            if (mix) {
                crc ^= 0x8C;
            }
            byte >>= 1;
        }
    }
    
    return crc;
}

// ===========================================
// Public Functions
// ===========================================

esp_err_t ds18b20_init(void) {
    ESP_LOGI(TAG, "Initializing DS18B20...");
    
    // Configure GPIO
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << ONEWIRE_GPIO),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);
    
    // Check for device presence
    if (!ow_reset()) {
        ESP_LOGE(TAG, "No device found on OneWire bus");
        return ESP_ERR_NOT_FOUND;
    }
    
    // Read ROM code
    ow_reset();
    ow_write_byte(DS18B20_CMD_READ_ROM);
    
    for (int i = 0; i < 8; i++) {
        rom_code[i] = ow_read_byte();
    }
    
    // Verify CRC
    if (crc8(rom_code, 7) != rom_code[7]) {
        ESP_LOGE(TAG, "ROM CRC error");
        return ESP_ERR_INVALID_CRC;
    }
    
    // Verify family code (0x28 for DS18B20)
    if (rom_code[0] != 0x28) {
        ESP_LOGE(TAG, "Invalid family code: 0x%02X", rom_code[0]);
        return ESP_ERR_NOT_FOUND;
    }
    
    ESP_LOGI(TAG, "DS18B20 found: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X",
             rom_code[0], rom_code[1], rom_code[2], rom_code[3],
             rom_code[4], rom_code[5], rom_code[6], rom_code[7]);
    
    // Set default resolution
    ds18b20_set_resolution(DS18B20_RESOLUTION);
    
    initialized = true;
    ESP_LOGI(TAG, "DS18B20 initialized successfully");
    
    return ESP_OK;
}

esp_err_t ds18b20_deinit(void) {
    initialized = false;
    return ESP_OK;
}

esp_err_t ds18b20_read_temperature(float *temperature) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (!temperature) {
        return ESP_ERR_INVALID_ARG;
    }
    
    // Start temperature conversion
    if (!ow_reset()) {
        return ESP_ERR_NOT_FOUND;
    }
    
    ow_write_byte(DS18B20_CMD_SKIP_ROM);
    ow_write_byte(DS18B20_CMD_CONVERT_T);
    
    // Wait for conversion (depends on resolution)
    uint16_t wait_ms;
    switch (resolution) {
        case 9:  wait_ms = 94; break;
        case 10: wait_ms = 188; break;
        case 11: wait_ms = 375; break;
        case 12:
        default: wait_ms = 750; break;
    }
    
    vTaskDelay(pdMS_TO_TICKS(wait_ms));
    
    // Read scratchpad
    if (!ow_reset()) {
        return ESP_ERR_NOT_FOUND;
    }
    
    ow_write_byte(DS18B20_CMD_SKIP_ROM);
    ow_write_byte(DS18B20_CMD_READ_SCRATCHPAD);
    
    uint8_t scratchpad[9];
    for (int i = 0; i < 9; i++) {
        scratchpad[i] = ow_read_byte();
    }
    
    // Verify CRC
    if (crc8(scratchpad, 8) != scratchpad[8]) {
        ESP_LOGE(TAG, "Scratchpad CRC error");
        return ESP_ERR_INVALID_CRC;
    }
    
    // Calculate temperature
    int16_t raw = (scratchpad[1] << 8) | scratchpad[0];
    
    // Handle negative temperatures
    if (raw & 0x8000) {
        raw = ~raw + 1;
        *temperature = -(raw / 16.0f);
    } else {
        *temperature = raw / 16.0f;
    }
    
    return ESP_OK;
}

esp_err_t ds18b20_set_resolution(uint8_t res) {
    if (res < 9) res = 9;
    if (res > 12) res = 12;
    
    if (!ow_reset()) {
        return ESP_ERR_NOT_FOUND;
    }
    
    // Configuration register value (R1, R0 bits)
    uint8_t config;
    switch (res) {
        case 9:  config = 0x1F; break;
        case 10: config = 0x3F; break;
        case 11: config = 0x5F; break;
        case 12:
        default: config = 0x7F; break;
    }
    
    ow_write_byte(DS18B20_CMD_SKIP_ROM);
    ow_write_byte(DS18B20_CMD_WRITE_SCRATCHPAD);
    ow_write_byte(0x00);  // TH register (high alarm)
    ow_write_byte(0x00);  // TL register (low alarm)
    ow_write_byte(config);
    
    resolution = res;
    ESP_LOGI(TAG, "Resolution set to %d bits", resolution);
    
    return ESP_OK;
}

esp_err_t ds18b20_get_rom_code(uint8_t *rom) {
    if (!initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (!rom) {
        return ESP_ERR_INVALID_ARG;
    }
    
    memcpy(rom, rom_code, 8);
    return ESP_OK;
}

bool ds18b20_is_connected(void) {
    return initialized && ow_reset();
}
