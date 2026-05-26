#!/usr/bin/env bash
# Inject Context Hook - Add relevant semantic context after file reads/searches

# Read hook input from stdin
input_json=$(cat)

# Get script directory
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_dir="$(dirname "$script_dir")"
log_file="$skills_dir/hook_debug.log"
vector_store_script="$skills_dir/vector_store.py"

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Extract tool_name
tool_name=$(echo "$input_json" | grep -o '"tool_name":"[^"]*"' | sed 's/"tool_name":"\([^"]*\)"/\1/')

echo "$timestamp - INJECT HOOK: Tool = $tool_name" >> "$log_file"

# Check if this is a tool we should inject context for
if ! echo "$tool_name" | grep -qE "^(Read|SemanticSearch|Grep)$"; then
    echo "{}"
    exit 0
fi

# Extract query context from the tool call
query=""

# Try pattern
if echo "$input_json" | grep -q '"pattern"'; then
    query=$(echo "$input_json" | grep -o '"pattern"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    echo "$timestamp - INJECT HOOK: Found pattern: $query" >> "$log_file"
# Try query
elif echo "$input_json" | grep -q '"query"'; then
    query=$(echo "$input_json" | grep -o '"query"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"query"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    echo "$timestamp - INJECT HOOK: Found query: $query" >> "$log_file"
# Try file_path or path
elif echo "$input_json" | grep -qE '"(file_path|path)"'; then
    path=$(echo "$input_json" | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"[^"]*"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' | sed 's/\\\\/\//g')
    filename=$(basename "$path")
    query="information about $filename"
    echo "$timestamp - INJECT HOOK: Found file_path: $path, filename: $filename" >> "$log_file"
fi

echo "$timestamp - INJECT HOOK: Query = $query" >> "$log_file"

# Check if query is too short
if [ -z "$query" ] || [ ${#query} -lt 10 ]; then
    echo "$timestamp - INJECT HOOK: Query too short, skipping" >> "$log_file"
    echo "{}"
    exit 0
fi

# Retrieve relevant context from vector store
echo "$timestamp - INJECT HOOK: Retrieving context..." >> "$log_file"
results_output=$(python3 "$vector_store_script" retrieve "$query" --top-k 2 2>&1)

if [ $? -ne 0 ]; then
    echo "$timestamp - INJECT HOOK: Retrieval failed, exit code = $?" >> "$log_file"
    echo "{}"
    exit 0
fi

# Extract JSON from output (filter out loading messages)
results_json=$(echo "$results_output" | sed -n '/^{/,/^}/p')

if [ -z "$results_json" ]; then
    echo "$timestamp - INJECT HOOK: No JSON found in output" >> "$log_file"
    echo "{}"
    exit 0
fi

# Check if results exist using grep
if ! echo "$results_json" | grep -q '"results"'; then
    echo "$timestamp - INJECT HOOK: No results found" >> "$log_file"
    echo "{}"
    exit 0
fi

# Parse results and format context (simplified - just check if we have results)
if echo "$results_json" | grep -q '"results":\[\]'; then
    echo "$timestamp - INJECT HOOK: No results found" >> "$log_file"
    echo "{}"
    exit 0
fi

# Build context text
context_text="\n\n--- RELEVANT CONTEXT FROM PAST SESSIONS ---\n"

# Extract text and score from first result (simplified parsing)
# This is a basic implementation - for production, consider using jq
result_text=$(echo "$results_json" | grep -o '"text":"[^"]*"' | head -1 | sed 's/"text":"\(.*\)"/\1/')
result_score=$(echo "$results_json" | grep -o '"score":[0-9.]*' | head -1 | sed 's/"score":\([0-9.]*\)/\1/')

if [ ! -z "$result_text" ]; then
    # Truncate if too long
    if [ ${#result_text} -gt 300 ]; then
        result_text="${result_text:0:300}..."
    fi
    
    context_text="${context_text}\nFrom previous conversation (relevance: $result_score):\n${result_text}\n"
    
    context_text="${context_text}\n--- END CONTEXT ---\n\n"
    
    echo "$timestamp - INJECT HOOK: Injecting context" >> "$log_file"
    
    # Return additional context to inject
    # Need to properly escape the context text for JSON
    escaped_context=$(echo "$context_text" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"additional_context\":\"$escaped_context\"}"
else
    echo "$timestamp - INJECT HOOK: No results above threshold" >> "$log_file"
    echo "{}"
fi

exit 0
