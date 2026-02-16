#!/bin/bash

# Test script for esp8266flasher.sh

TEST_NAME="Non-existent firmware file check"
SCRIPT_TO_TEST="./esp8266flasher.sh"
NON_EXISTENT_FILE="non_existent_file.bin"

echo "Running test: $TEST_NAME"

# Capture stdout and stderr
output=$($SCRIPT_TO_TEST "$NON_EXISTENT_FILE" 2>&1)
exit_code=$?

# Verify exit code
if [ $exit_code -ne 1 ]; then
    echo "❌ FAILED: Expected exit code 1, got $exit_code"
    exit 1
fi

# Verify error message
expected_msg="❌ Error: File '$NON_EXISTENT_FILE' not found!"
if [[ "$output" != *"$expected_msg"* ]]; then
    echo "❌ FAILED: Expected output to contain '$expected_msg'"
    echo "Actual output:"
    echo "$output"
    exit 1
fi

echo "✅ PASSED: $TEST_NAME"
exit 0
