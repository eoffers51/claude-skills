/* PASTE THIS INTO YOUR MAIN SOURCE FILE (the one with app_main), anywhere at
 * file scope. Do not put it in a file of its own: ESP-IDF already has a weak
 * default of this function, so the linker would never pull a separate object
 * in (it would need WHOLE_ARCHIVE, which this skill does not use).
 *
 * Why it is needed: at boot ESP-IDF calls esp_trace_get_user_params() to learn
 * which trace encoder and transport to open. The weak default asks for the
 * encoder named CONFIG_ESP_TRACE_LIB_NAME = "ext" (a hidden Kconfig string, so
 * no sdkconfig can change it), but the esp_sysview component registers itself
 * as "sysview". Without this override the trace build aborts at boot:
 *   E esp_trace_core: Encoder 'ext' or transport 'apptrace' not found
 * This is a copy of what ESP-IDF's examples/system/sysview_tracing does.
 * In the normal build CONFIG_ESP_TRACE_LIB_EXTERNAL is off and all of this
 * compiles to nothing.
 */
#include "sdkconfig.h"
#if CONFIG_ESP_TRACE_LIB_EXTERNAL
#include "esp_trace.h"      /* from esp_trace, brought in by the esp_sysview component */
#include "esp_app_trace.h"  /* esp_apptrace_config_t, APPTRACE_CONFIG_DEFAULT */
#if CONFIG_APPTRACE_DEST_UART
#include "soc/uart_pins.h"  /* U0TXD_GPIO_NUM / U0RXD_GPIO_NUM */
#endif

esp_trace_open_params_t esp_trace_get_user_params(void)
{
    /* All APPTRACE_* values from sdkconfig (JTAG in sdkconfig.sysview_jtag). */
    static esp_apptrace_config_t app_trace_config = APPTRACE_CONFIG_DEFAULT();
#if CONFIG_APPTRACE_DEST_UART
    /* Only if someone selects the UART destination: use the console UART0 pins,
     * as the example does. Not used by the JTAG fragment. */
    app_trace_config.dest_cfg.uart.tx_pin_num = U0TXD_GPIO_NUM;
    app_trace_config.dest_cfg.uart.rx_pin_num = U0RXD_GPIO_NUM;
#endif
    const esp_trace_open_params_t trace_params = {
        .core_cfg       = NULL,
        .encoder_name   = "sysview",   /* registered by espressif/esp_sysview */
        .encoder_cfg    = NULL,
        .transport_name = "apptrace",  /* ESP-IDF app trace over JTAG */
        .transport_cfg  = &app_trace_config,
    };
    return trace_params;
}
#endif /* CONFIG_ESP_TRACE_LIB_EXTERNAL */
