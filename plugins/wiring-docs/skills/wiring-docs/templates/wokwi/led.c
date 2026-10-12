// Wokwi-only version of components/led/led.c
//
// wokwi.com compiles ESP-IDF code with the Arduino ESP32 core, which doesn't have
// the espressif/led_strip component. This file keeps the same led.h API but uses
// the core's built-in WS2812 function instead. The real firmware uses led.c.
// Adapt the function names to the project's own header.

#include "led.h"
#include "esp32-hal-rgb-led.h"
#include "esp_arduino_version.h"

// Pin of the LED, remembered by led_init
static int s_gpio;

esp_err_t led_init(int gpio)
{
    // Remember the pin and start with the LED off
    s_gpio = gpio;
    return led_set_rgb(0, 0, 0);
}

esp_err_t led_set_rgb(uint8_t red, uint8_t green, uint8_t blue)
{
    // Send the color to the WS2812 (the core handles the GRB order and RMT timing)
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    rgbLedWrite(s_gpio, red, green, blue);
#else
    neopixelWrite(s_gpio, red, green, blue);
#endif
    return ESP_OK;
}
