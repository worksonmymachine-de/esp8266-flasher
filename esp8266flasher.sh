#!/bin/bash

# --- CONFIGURATION ---
VENV_DIR="venv"
PORT="/dev/ttyUSB0"
BAUD="460800"
DOWNLOAD_PAGE="https://micropython.org/download/ESP8266_GENERIC/"
BASE_URL="https://micropython.org"

# --- 1. DETERMINE FIRMWARE FILE ---
if [ -n "$1" ]; then
    FIRMWARE_FILE="$1"

    # Ensure filename is treated as a path (prevents argument injection)
    if [[ "$FIRMWARE_FILE" == -* ]]; then
        FIRMWARE_FILE="./$FIRMWARE_FILE"
    fi

    if [ ! -f "$FIRMWARE_FILE" ]; then
        echo "❌ Error: File '$FIRMWARE_FILE' not found!"
        exit 1
    fi
else
    # --- AUTO-DOWNLOAD MODE ---
    echo "🔍 No firmware file provided."
    echo "🌐 Scraping $DOWNLOAD_PAGE for the latest release..."
    
    # Extract relative path, ensuring no trailing quotes or garbage
    RELATIVE_PATH=$(curl -s $DOWNLOAD_PAGE | grep -oP 'href="\K/resources/firmware/ESP8266_GENERIC-\d+-[^"]+\.bin' | head -n 1 | tr -d '"')
    
    if [ -z "$RELATIVE_PATH" ]; then
        echo "❌ Error: Could not find a valid .bin link."
        exit 1
    fi

    DOWNLOAD_URL="${BASE_URL}${RELATIVE_PATH}"
    FIRMWARE_FILE=$(basename "$RELATIVE_PATH")

    # Ensure filename is treated as a path (prevents argument injection)
    if [[ "$FIRMWARE_FILE" == -* ]]; then
        FIRMWARE_FILE="./$FIRMWARE_FILE"
    fi

    echo "---------------------------------------"
    echo "✅ Found latest version: $FIRMWARE_FILE"
    echo "---------------------------------------"

    # --- USER CONFIRMATION ---
    read -p "❓ Download this firmware and flash it? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "🚫 Operation cancelled by user."
        exit 0
    fi
    
    # --- DOWNLOAD LOGIC ---
    if [ -f "$FIRMWARE_FILE" ]; then
        echo "📂 File already exists locally. Using cached version."
    else
        echo "⬇️  Downloading from: $DOWNLOAD_URL"
        wget -q --show-progress -U "Mozilla/5.0" "$DOWNLOAD_URL"
        if [ $? -ne 0 ]; then
            echo "❌ Error: Download failed."
            exit 1
        fi
    fi
fi

# --- 2. SETUP & ACTIVATE VENV ---
if [ ! -d "$VENV_DIR" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

echo "🔌 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# --- 3. INSTALL TOOLS ---
echo "📦 Checking build tools..."
pip install --upgrade pip -q
pip install esptool -q

# --- 4. FLASH THE FIRMWARE ---
echo "---------------------------------------"
echo "🔥 FLASHING: $FIRMWARE_FILE"
echo "📍 PORT:     $PORT"
echo "---------------------------------------"

echo "🧹 Erasing flash memory..."
python -m esptool --port "$PORT" --baud "$BAUD" erase-flash

echo "✍️  Writing firmware..."
python -m esptool --port "$PORT" --baud "$BAUD" write-flash --flash_size=detect -fm dout 0 "$FIRMWARE_FILE"

if [ $? -eq 0 ]; then
    echo "---------------------------------------"
    echo "✅ SUCCESS! Firmware flashed."
else
    echo "---------------------------------------"
    echo "❌ FAILED. Check connections."
fi

deactivate
