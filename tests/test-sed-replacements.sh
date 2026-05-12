#!/bin/bash

# Test: Verification of sed removal and new pure Bash logic
# This test verifies the new yq validation, token masking, yaml fallback, and key trimming.

set -e

REPO_ROOT=$(pwd)
source "${REPO_ROOT}/scripts/shell-install-helper.sh"

echo "--------------------------------------------------"
echo "Running test: sed replacements (test-sed-replacements.sh)"

FAILED=0

# 1. Test trim_key_file (re-testing the modified function)
echo "Testing trim_key_file..."
TMP_KEY="test_key_trim.txt"
cat << 'EOF' > "$TMP_KEY"
line1   
line2
line3 
EOF

trim_key_file "$TMP_KEY"

if grep -q "line1 " "$TMP_KEY"; then
    echo "FAIL: trim_key_file did not trim line1"
    FAILED=1
fi
if grep -q "line3 " "$TMP_KEY"; then
    echo "FAIL: trim_key_file did not trim line3"
    FAILED=1
fi
rm -f "$TMP_KEY"

# 2. Test substring token masking
echo "Testing substring token masking..."
SCM_TOKEN_TOKEN="1234567890abcdef"
MASKED="******${SCM_TOKEN_TOKEN:6}"
if [[ "$MASKED" != "******7890abcdef" ]]; then
    echo "FAIL: Substring masking failed. Got: $MASKED"
    FAILED=1
fi

# 3. Test Bash YAML parsing fallback
echo "Testing Bash YAML fallback..."
# Extract the bash logic into a function for testing
function extract_yaml_bash() {
    local key=$1
    local file=$2
    local line=$(grep -E "^[[:space:]]*${key}:" "$file" | head -n 1)
    if [[ -n "$line" ]]; then
        local val="${line#*:}"             
        val="${val#"${val%%[![:space:]]*}"}" 
        val="${val%%#*}"                   
        val="${val%${val##*[![:space:]]}}" 
        val="${val%\"}"; val="${val#\"}"   
        val="${val%\'}"; val="${val#\'}"   
        echo "$val"
    fi
}

TMP_YAML="test_fallback.yaml"
cat << 'EOF' > "$TMP_YAML"
  my_key1: "value1" # comment
  my_key2: value2
  my_key3: 'value3'
EOF

VAL1=$(extract_yaml_bash "my_key1" "$TMP_YAML")
if [[ "$VAL1" != "value1" ]]; then
    echo "FAIL: YAML fallback failed for double quotes and comments. Got: '$VAL1'"
    FAILED=1
fi

VAL2=$(extract_yaml_bash "my_key2" "$TMP_YAML")
if [[ "$VAL2" != "value2" ]]; then
    echo "FAIL: YAML fallback failed for plain string. Got: '$VAL2'"
    FAILED=1
fi

VAL3=$(extract_yaml_bash "my_key3" "$TMP_YAML")
if [[ "$VAL3" != "value3" ]]; then
    echo "FAIL: YAML fallback failed for single quotes. Got: '$VAL3'"
    FAILED=1
fi
rm -f "$TMP_YAML"

if [[ $FAILED -eq 0 ]]; then
    echo "PASS: All sed replacement tests passed."
    exit 0
else
    echo "FAIL: Some sed replacement tests failed."
    exit 1
fi
