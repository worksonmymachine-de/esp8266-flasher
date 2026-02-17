#!/bin/bash

# --- CONFIGURATION ---
VENV_DIR="${VENV_DIR:-venv}"
PORT="${PORT:-/dev/ttyUSB0}"
BAUD="${BAUD:-460800}"
DOWNLOAD_PAGE="https://micropython.org/download/ESP8266_GENERIC/"
BASE_URL="https://micropython.org"

# --- FUNCTIONS ---

# Determines the firmware file to use.
# If an argument is provided, checks if it exists.
# If not, scrapes the download page and prompts to download the latest version.
# Sets the global variable FIRMWARE_FILE.
get_firmware_file() {
    local firmware_arg="$1"

    if [ -n "$firmware_arg" ]; then
        FIRMWARE_FILE="$firmware_arg"

        # Ensure filename is treated as a path (prevents argument injection)
        if [[ "$FIRMWARE_FILE" == -* ]]; then
            FIRMWARE_FILE="./$FIRMWARE_FILE"
        fi

        if [ ! -f "$FIRMWARE_FILE" ]; then
            echo "❌ Error: File '$FIRMWARE_FILE' not found!"
            return 1
        fi
    else
        download_firmware
        if [ $? -ne 0 ]; then
             return 1
        fi
    fi
    return 0
}

# Scrapes the MicroPython website for the latest ESP8266 firmware and downloads it.
# Sets the global variable FIRMWARE_FILE.
download_firmware() {
    echo "🔍 No firmware file provided."
    echo "🌐 Scraping $DOWNLOAD_PAGE for the latest release..."
    
    # Extract relative path, ensuring no trailing quotes or garbage
    local relative_path
    relative_path=$(curl -s $DOWNLOAD_PAGE | grep -oP 'href="\K/resources/firmware/ESP8266_GENERIC-\d+-[^"]+\.bin' | head -n 1 | tr -d '"')
    
    if [ -z "$relative_path" ]; then
        echo "❌ Error: Could not find a valid .bin link."
        return 1
    fi

    local download_url="${BASE_URL}${relative_path}"
    FIRMWARE_FILE=$(basename "$relative_path")

    # Ensure filename is treated as a path (prevents argument injection)
    if [[ "$FIRMWARE_FILE" == -* ]]; then
        FIRMWARE_FILE="./$FIRMWARE_FILE"
    fi

    echo "---------------------------------------"
    echo "✅ Found latest version: $FIRMWARE_FILE"
    echo "---------------------------------------"

    # --- USER CONFIRMATION ---
    local confirm
    read -r -p "❓ Download this firmware and flash it? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "🚫 Operation cancelled by user."
        exit 0
    fi
    
    # --- DOWNLOAD LOGIC ---
    if [ -f "$FIRMWARE_FILE" ]; then
        echo "📂 File already exists locally. Using cached version."
    else
        echo "⬇️  Downloading from: $download_url"
        wget -q --show-progress -U "Mozilla/5.0" "$download_url"
        if [ $? -ne 0 ]; then
            echo "❌ Error: Download failed."
            return 1
        fi
    fi
    return 0
}

# Creates and activates the virtual environment.
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "🔧 Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to create virtual environment."
            return 1
        fi
    fi

    echo "🔌 Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to activate virtual environment."
        return 1
    fi
    return 0
}

# Installs required Python dependencies in the virtual environment.
install_dependencies() {
    echo "📦 Checking build tools..."
    pip install --upgrade pip -q
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to upgrade pip."
        return 1
    fi

    pip install esptool -q
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to install esptool."
        return 1
    fi
    return 0
}

# Flashes the firmware to the device.
flash_firmware() {
    local firmware_file="$1"
    local port="$2"
    local baud="$3"

    echo "---------------------------------------"
    echo "🔥 FLASHING: $firmware_file"
    echo "📍 PORT:     $port"
    echo "---------------------------------------"

    echo "🧹 Erasing flash memory..."
    python -m esptool --port "$port" --baud "$baud" erase-flash

    echo "✍️  Writing firmware..."
    python -m esptool --port "$port" --baud "$baud" write-flash --flash_size=detect -fm dout 0 "$firmware_file"

    if [ $? -eq 0 ]; then
        echo "---------------------------------------"
        echo "✅ SUCCESS! Firmware flashed."
    else
        echo "---------------------------------------"
        echo "❌ FAILED. Check connections."
        return 1
    fi
    return 0
}

# Main function to orchestrate the flashing process.
main() {
    get_firmware_file "$1"
    if [ $? -ne 0 ]; then
        exit 1
    fi

    setup_venv
    if [ $? -ne 0 ]; then
        exit 1
    fi

    install_dependencies
    if [ $? -ne 0 ]; then
        exit 1
    fi

    flash_firmware "$FIRMWARE_FILE" "$PORT" "$BAUD"

    deactivate
}

# Run main
main "$@"
