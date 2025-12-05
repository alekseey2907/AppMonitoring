/**
 * VibeMon LED Indicator Header
 */

#ifndef LED_INDICATOR_H
#define LED_INDICATOR_H

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LED_STATE_OFF,
    LED_STATE_INITIALIZING,
    LED_STATE_ADVERTISING,
    LED_STATE_CONNECTED,
    LED_STATE_DATA_TRANSFER,
    LED_STATE_ERROR,
    LED_STATE_LOW_BATTERY
} led_state_t;

esp_err_t led_indicator_init(void);
void led_indicator_set_state(led_state_t state);
led_state_t led_indicator_get_state(void);

#ifdef __cplusplus
}
#endif

#endif // LED_INDICATOR_H
