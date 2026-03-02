#!/bin/bash

# Test script for simulating esptool failure

TEST_NAME="Esptool failure check"
SCRIPT_TO_TEST="./esp8266flasher.sh"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Running test: $TEST_NAME"

# Create a dummy firmware file
DUMMY_FIRMWARE="$TEMP_DIR/firmware.bin"
touch "$DUMMY_FIRMWARE"

# Setup mock environment
MOCK_BIN="$TEMP_DIR/bin"
mkdir -p "$MOCK_BIN"

# Mock python
# The script calls 'python -m esptool ...'
cat << 'EOF' > "$MOCK_BIN/python"
#!/bin/bash
# Check arguments to determine behavior
# args: -m esptool --port ... erase-flash
# args: -m esptool --port ... write-flash ...

# We need to detect if it's a write-flash command
if [[ "$*" == *"write-flash"* ]]; then
    echo "Mock python: Simulating write-flash failure"
    exit 1
elif [[ "$*" == *"erase-flash"* ]]; then
    echo "Mock python: Simulating erase-flash success"
    exit 0
elif [[ "$*" == *"-m venv"* ]]; then
    # Should not be called if we setup venv dir, but just in case
    exit 0
else
    # Default success for other calls
    exit 0
fi
EOF
chmod +x "$MOCK_BIN/python"

# Mock pip (since script calls pip install)
cat << 'EOF' > "$MOCK_BIN/pip"
#!/bin/bash
echo "Mock pip: Success"
exit 0
EOF
chmod +x "$MOCK_BIN/pip"

# Setup Mock Venv
export VENV_DIR="$TEMP_DIR/venv"
mkdir -p "$VENV_DIR/bin"

# Mock activate script
# The script sources this file. It typically modifies PATH and sets up 'deactivate' function.
cat << 'EOF' > "$VENV_DIR/bin/activate"
# Mock activate script
deactivate() {
    echo "Mock deactivate"
}
EOF

# Update PATH to include our mocks
export PATH="$MOCK_BIN:$PATH"

# Run the script
# We pass the dummy firmware file to skip the download part.
# We also set PORT and BAUD to dummy values.
export PORT="/dev/null"
export BAUD="115200"

echo "Running esp8266flasher.sh with mock failure..."
# Capture both stdout and stderr
OUTPUT=$($SCRIPT_TO_TEST "$DUMMY_FIRMWARE" 2>&1)

echo "$OUTPUT"

# Verify output
EXPECTED_MSG="❌ FAILED. Check connections."
if [[ "$OUTPUT" == *"$EXPECTED_MSG"* ]]; then
    echo "✅ Success: Found expected error message."
    exit 0
else
    echo "❌ Failure: Did not find expected error message."
    echo "Expected: $EXPECTED_MSG"
    exit 1
fi
