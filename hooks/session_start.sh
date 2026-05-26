#!/usr/bin/env bash
# Session Start Hook - Initialize vector store session

# Read hook input from stdin
input_json=$(cat)

# Get script directory
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_dir="$(dirname "$script_dir")"
log_file="$skills_dir/hook_debug.log"
vector_store_script="$skills_dir/vector_store.py"

# Log that hook was called
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo "$timestamp - SESSION START HOOK CALLED" >> "$log_file"
echo "$timestamp - Raw input: $input_json" >> "$log_file"

# Extract session_id using grep and sed
session_id=$(echo "$input_json" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"\([^"]*\)"/\1/')
echo "$timestamp - Session ID: $session_id" >> "$log_file"

# Check if Python and dependencies are available
if ! python3 -c "import sentence_transformers, faiss" 2>/dev/null; then
    # Dependencies not installed, fail silently
    echo "{}"
    exit 0
fi

# Ensure vector store is initialized
python3 "$vector_store_script" init >/dev/null 2>&1

# Return success
echo "{}"
exit 0
