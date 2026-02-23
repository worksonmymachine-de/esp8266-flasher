#!/bin/bash

SCRIPT_TO_TEST="./esp8266flasher.sh"
TEMP_SCRIPT="./test_script_source.sh"
MOCK_INSTALLED_FILE="mocked_esptool_installed"

# Cleanup function
cleanup() {
    rm -f "$TEMP_SCRIPT" "$MOCK_INSTALLED_FILE"
}
trap cleanup EXIT

# Copy and strip main execution
cp "$SCRIPT_TO_TEST" "$TEMP_SCRIPT"
# Remove the last line which calls main
sed -i '$d' "$TEMP_SCRIPT"

# Mock pip command
pip() {
    echo "pip called with args: $@"
    if [[ "$1" == "install" ]]; then
        # Check if esptool is being installed
        if [[ "$@" == *"esptool"* ]]; then
            touch "$MOCK_INSTALLED_FILE"
        fi
        return 0
    fi
    # Handle 'show' for dependency check
    if [[ "$1" == "show" ]]; then
         if [ -f "$MOCK_INSTALLED_FILE" ]; then
             return 0
         else
             return 1
         fi
    fi
    return 0
}

# Mock python3 command
python3() {
    if [[ "$1" == "-m" && "$2" == "pip" ]]; then
        shift 2
        pip "$@"
        return $?
    fi
    return 0
}

# Source the script
source "$TEMP_SCRIPT"

echo "---------------------------------------------------"
echo "Test 1: Dependencies NOT installed (initial run)"
echo "---------------------------------------------------"
rm -f "$MOCK_INSTALLED_FILE"

# Capture output
output=$(install_dependencies 2>&1)
echo "$output"

# Check if it tried to install
if [[ "$output" == *"pip called with args"* && "$output" == *"install"* ]]; then
    echo "✅ Test 1 Passed: Attempted installation when missing."
else
    echo "❌ Test 1 Failed: Did not attempt installation."
    exit 1
fi

echo "---------------------------------------------------"
echo "Test 2: Dependencies ALREADY installed (second run)"
echo "---------------------------------------------------"
touch "$MOCK_INSTALLED_FILE"

output=$(install_dependencies 2>&1)
echo "$output"

if [[ "$output" == *"Dependencies already installed"* ]]; then
    # Ensure it did NOT call install
    if [[ "$output" == *"pip called with args"* && "$output" == *"install"* ]]; then
         echo "❌ Test 2 Failed: Installed despite presence."
         exit 1
    else
         echo "✅ Test 2 Passed: Skipped installation when present."
    fi
else
    echo "❌ Test 2 Failed: Did not detect installed dependencies (or output message missing)."
    exit 1
fi

exit 0
