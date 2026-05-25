# Capture Agent Response Hook - Store AI responses in vector database
param()

# Read hook input from stdin
$input_json = [Console]::In.ReadToEnd()

# Remove BOM if present
$input_json = $input_json.TrimStart([char]0xFEFF)

# Get script directory
$script_dir = Split-Path -Parent $PSCommandPath
$skills_dir = Split-Path -Parent $script_dir
$log_file = Join-Path $skills_dir "hook_debug.log"
$vector_store_script = Join-Path $skills_dir "vector_store.py"

try {
    # Extract text field first (before trying to parse full JSON)
    # The text field contains escaped content, so we need to extract and unescape it
    if ($input_json -match '"text":"((?:[^"\\]|\\.)*)"') {
        $response_text = $matches[1]
        
        # Unescape common JSON escape sequences
        $response_text = $response_text -replace '\\n', "`n"
        $response_text = $response_text -replace '\\r', "`r"
        $response_text = $response_text -replace '\\t', "`t"
        $response_text = $response_text -replace '\\"', '"'
        $response_text = $response_text -replace '\\\\', '\'
        
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Extracted text length: $($response_text.Length)" | Out-File -FilePath $log_file -Append
    } else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - No text field found in JSON" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    if (-not $response_text -or $response_text.Length -lt 50) {
        # Too short to be useful, skip
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Skipping: text too short" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    # Extract session_id from JSON string (avoid full JSON parsing)
    $session_id = "unknown"
    if ($input_json -match '"session_id":"([^"]+)"') {
        $session_id = $matches[1]
    }
    
    # Run storage directly (without metadata for simplicity - the issue was with metadata JSON escaping)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting storage for $($response_text.Length) chars" | Out-File -FilePath $log_file -Append
    
    # Store using direct Python call
    $result = & python $vector_store_script store $response_text 2>&1
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Storage complete: $result" | Out-File -FilePath $log_file -Append
    @{ } | ConvertTo-Json -Compress
    exit 0
}
catch {
    # Fail open - don't block if storage fails
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: $($_.Exception.Message)" | Out-File -FilePath $log_file -Append
    @{ } | ConvertTo-Json -Compress
    exit 0
}
