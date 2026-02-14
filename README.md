# esp8266-flasher
Flashes your ESP8266 with esptool. You can provide a firmware file, but it can also scrape the latest 2MB+ version from the micropython.org site. Sets up a venv at the current location and installs esptool, erases and flashes the device at /dev/ttyUSB0.
