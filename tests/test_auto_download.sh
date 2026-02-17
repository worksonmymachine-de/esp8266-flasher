#!/bin/bash

# Test script for auto-download functionality of esp8266flasher.sh

TEST_NAME="Auto-download and Flash Test"
SCRIPT_TO_TEST="$(realpath ./esp8266flasher.sh)"
TEST_DIR=$(mktemp -d)
MOCKS_DIR="$TEST_DIR/mocks"
VENV_DIR="$TEST_DIR/venv"
FIRMWARE_FILENAME="ESP8266_GENERIC-20240101-v1.23.0.bin"

echo "---------------------------------------------------"
echo "🚀 Running test: $TEST_NAME"
echo "---------------------------------------------------"

# Create mocks directory
mkdir -p "$MOCKS_DIR"

# Mock curl
cat <<EOF > "$MOCKS_DIR/curl"
#!/bin/bash
echo '<html><body><a href="/resources/firmware/$FIRMWARE_FILENAME">Download</a></body></html>'
EOF
chmod +x "$MOCKS_DIR/curl"

# Mock wget
cat <<EOF > "$MOCKS_DIR/wget"
#!/bin/bash
# Mock download by creating the file
touch "$FIRMWARE_FILENAME"
exit 0
EOF
chmod +x "$MOCKS_DIR/wget"

# Mock python3 (for venv creation)
cat <<EOF > "$MOCKS_DIR/python3"
#!/bin/bash
if [[ "\$1" == "-m" && "\$2" == "venv" ]]; then
    mkdir -p "\$3/bin"
    # Create a dummy activate script with deactivate function
    {
        echo "deactivate() { echo 'Deactivated venv'; }"
        echo "export VIRTUAL_ENV='\$3'"
    } > "\$3/bin/activate"
    exit 0
fi
exit 0
EOF
chmod +x "$MOCKS_DIR/python3"

# Mock python (for esptool execution)
cat <<EOF > "$MOCKS_DIR/python"
#!/bin/bash
echo "MOCKED_PYTHON_CALL: \$*"
exit 0
EOF
chmod +x "$MOCKS_DIR/python"

# Mock pip
cat <<EOF > "$MOCKS_DIR/pip"
#!/bin/bash
exit 0
EOF
chmod +x "$MOCKS_DIR/pip"

# Update PATH to include mocks
export PATH="$MOCKS_DIR:$PATH"
export VENV_DIR="$VENV_DIR"

# Change to test directory to avoid polluting repo root
cd "$TEST_DIR" || exit 1

# Run the script with "y" as input
echo "y" | "$SCRIPT_TO_TEST" > "output.log" 2>&1
EXIT_CODE=$?

# Verify exit code
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ FAILED: Script exited with code $EXIT_CODE"
    cat "output.log"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Verify output
OUTPUT=$(cat "output.log")

# Check if correct firmware was found
if ! echo "$OUTPUT" | grep -q "Found latest version: $FIRMWARE_FILENAME"; then
    echo "❌ FAILED: Did not find expected firmware version message."
    echo "Output snippet:"
    echo "$OUTPUT" | head -n 20
    rm -rf "$TEST_DIR"
    exit 1
fi

# Check if python/esptool mock was called
if ! echo "$OUTPUT" | grep -q "MOCKED_PYTHON_CALL: -m esptool"; then
    echo "❌ FAILED: Did not attempt to flash using python/esptool."
    rm -rf "$TEST_DIR"
    exit 1
fi

echo "✅ PASSED: $TEST_NAME"

# Cleanup
rm -rf "$TEST_DIR"
exit 0
