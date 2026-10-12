// <Project title> - <course / lesson> (<chip>, ESP-IDF, C)
// Source: https://github.com/<user>/<repo>
//
// Wokwi compiles this project with the Arduino ESP32 core, which has its own app_main().
// So main.c here renames ours to <project>_app_main() and setup() starts it.
// Everything else is the repo's ESP-IDF code.

extern "C" void <project>_app_main(void);

void setup()
{
    <project>_app_main(); // usually never returns: the app's while (1) loop runs here
}

void loop() {}
