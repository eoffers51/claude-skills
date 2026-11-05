# Add to the app component's CMakeLists.txt (usually main/CMakeLists.txt).
# Build the SRCS / PRIV_REQUIRES lists in variables first, then:

set(extra_args "")

# SystemView trace builds only: tell esp_trace to use the "sysview" encoder
# from espressif/esp_sysview (see trace_params.c).
if(CONFIG_ESP_TRACE_LIB_EXTERNAL)
    list(APPEND srcs "trace_params.c")
    list(APPEND priv_requires esp_trace)
    # esp_trace already has a weak esp_trace_get_user_params(), so the linker
    # would never pull trace_params.c.obj out of libmain.a. WHOLE_ARCHIVE links
    # every object of this component, and the strong definition wins.
    list(APPEND extra_args WHOLE_ARCHIVE)
endif()

idf_component_register(SRCS ${srcs}
                       PRIV_REQUIRES ${priv_requires}
                       ${extra_args})

# Example of the lists above for a one-file app:
#   set(srcs "main.c")
#   set(priv_requires esp_driver_gpio)
