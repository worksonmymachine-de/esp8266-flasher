#!/bin/bash

# Test script for esp8266flasher.sh - Download Failure Scenario

TEST_NAME="Download failure check"
SCRIPT_TO_TEST="./esp8266flasher.sh"
MOCK_DIR="$(pwd)/tests/mock_bin"
MOCK_FIRMWARE_NAME="ESP8266_GENERIC-20240105-v1.22.1.bin"

echo "Running test: $TEST_NAME"

# 1. Setup Mock Environment
# Ensure we start clean
rm -rf "$MOCK_DIR"
mkdir -p "$MOCK_DIR"

# Mock curl: Returns a valid firmware link
cat <<EOF > "$MOCK_DIR/curl"
#!/bin/bash
echo 'href="/resources/firmware/$MOCK_FIRMWARE_NAME"'
EOF
chmod +x "$MOCK_DIR/curl"

# Mock wget: Fails with exit code 1
cat <<EOF > "$MOCK_DIR/wget"
#!/bin/bash
echo "Mock wget failing..."
exit 1
EOF
chmod +x "$MOCK_DIR/wget"

# Ensure the mock firmware file does NOT exist in the current directory
if [ -f "$MOCK_FIRMWARE_NAME" ]; then
    rm "$MOCK_FIRMWARE_NAME"
fi

# 2. Run the script with modified PATH
# We pipe "y" to confirm the download prompt
# Save original PATH to restore if needed (though shell verifies exit)
ORIGINAL_PATH="$PATH"
export PATH="$MOCK_DIR:$PATH"

output=$(echo "y" | "$SCRIPT_TO_TEST" 2>&1)
exit_code=$?

export PATH="$ORIGINAL_PATH"

# 3. Verify Results

# Cleanup
rm -rf "$MOCK_DIR"
if [ -f "$MOCK_FIRMWARE_NAME" ]; then
    rm "$MOCK_FIRMWARE_NAME"
fi

# Verify exit code
if [ $exit_code -ne 1 ]; then
    echo "❌ FAILED: Expected exit code 1, got $exit_code"
    echo "Output:"
    echo "$output"
    exit 1
fi

# Verify error message
expected_msg="❌ Error: Download failed."
if [[ "$output" != *"$expected_msg"* ]]; then
    echo "❌ FAILED: Expected output to contain '$expected_msg'"
    echo "Actual output:"
    echo "$output"
    exit 1
fi

echo "✅ PASSED: $TEST_NAME"
exit 0
