#!/usr/bin/env bash
# Capture Agent Response Hook - Store AI responses in vector database

# Read hook input from stdin
input_json=$(cat)

# Get script directory
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_dir="$(dirname "$script_dir")"
log_file="$skills_dir/hook_debug.log"
vector_store_script="$skills_dir/vector_store.py"

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Extract text field using grep and sed
if echo "$input_json" | grep -q '"text"'; then
    # Extract the text content (handling escaped quotes)
    response_text=$(echo "$input_json" | grep -o '"text":"[^"]*"' | sed 's/"text":"\(.*\)"/\1/' | sed 's/\\n/\n/g' | sed 's/\\r/\r/g' | sed 's/\\t/\t/g' | sed 's/\\"/"/g' | sed 's/\\\\/\\/g')
    
    echo "$timestamp - Extracted text length: ${#response_text}" >> "$log_file"
else
    echo "$timestamp - No text field found in JSON" >> "$log_file"
    echo "{}"
    exit 0
fi

# Check if text is too short
if [ -z "$response_text" ] || [ ${#response_text} -lt 50 ]; then
    echo "$timestamp - Skipping: text too short" >> "$log_file"
    echo "{}"
    exit 0
fi

# Extract session_id
session_id=$(echo "$input_json" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"\([^"]*\)"/\1/')

# Store using direct Python call
echo "$timestamp - Starting storage for ${#response_text} chars" >> "$log_file"

result=$(python3 "$vector_store_script" store "$response_text" 2>&1)

echo "$timestamp - Storage complete: $result" >> "$log_file"
echo "{}"
exit 0
