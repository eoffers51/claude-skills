// Only built in SystemView trace builds (see the CMake snippet: it is added
// when CONFIG_ESP_TRACE_LIB_EXTERNAL is set, together with WHOLE_ARCHIVE).
//
// At boot ESP-IDF calls esp_trace_get_user_params() to find out which trace
// encoder and transport to open. Its default (a weak function in esp_trace)
// asks for the encoder "ext", but the esp_sysview component registers itself
// as "sysview", so the default fails at boot with
//   "Encoder 'ext' or transport 'apptrace' not found" -> abort().
// ESP-IDF's own sysview_tracing example overrides it the same way.
#include "esp_trace.h"

esp_trace_open_params_t esp_trace_get_user_params(void) {
  const esp_trace_open_params_t trace_params = {
      .core_cfg = NULL,
      .encoder_name = "sysview", // registered by espressif/esp_sysview
      .encoder_cfg = NULL,       // default SystemView settings
      .transport_name =
          "apptrace",        // ESP-IDF app trace: UART or JTAG, from menuconfig
      .transport_cfg = NULL, // NULL = use the APPTRACE_* values from sdkconfig
  };
  return trace_params;
}
