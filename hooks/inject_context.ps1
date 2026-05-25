# Inject Context Hook - Add relevant semantic context after file reads/searches
param()

# Read hook input from stdin
$input_json = [Console]::In.ReadToEnd()

# Remove BOM if present
$input_json = $input_json.TrimStart([char]0xFEFF)

# Get script directory
$script_dir = Split-Path -Parent $PSCommandPath
$skills_dir = Split-Path -Parent $script_dir
$vector_store_script = Join-Path $skills_dir "vector_store.py"
$log_file = Join-Path $skills_dir "hook_debug.log"

try {
    # Extract tool_name using regex (avoid ConvertFrom-Json issues)
    $tool_name = ""
    if ($input_json -match '"tool_name":"([^"]+)"') {
        $tool_name = $matches[1]
    }
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Tool = $tool_name" | Out-File -FilePath $log_file -Append
    
    if ($tool_name -notmatch "^(Read|SemanticSearch|Grep)$") {
        # Not a read/search tool, skip
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    # Extract query context from the tool call using regex
    # Note: tool_input contains the actual parameters
    $query = ""
    if ($input_json -match '"pattern"\s*:\s*"((?:[^"\\]|\\.)+)"') {
        $query = $matches[1]
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Found pattern: $query" | Out-File -FilePath $log_file -Append
    }
    elseif ($input_json -match '"query"\s*:\s*"((?:[^"\\]|\\.)+)"') {
        $query = $matches[1]
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Found query: $query" | Out-File -FilePath $log_file -Append
    }
    elseif ($input_json -match '"(?:file_path|path)"\s*:\s*"((?:[^"\\]|\\.)+)"') {
        $path = $matches[1]
        # Unescape the path
        $path = $path -replace '\\\\', '\'
        # Extract just the filename from the path for a better query  
        $filename = [System.IO.Path]::GetFileName($path)
        $query = "information about $filename"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Found file_path: $path, filename: $filename" | Out-File -FilePath $log_file -Append
    }
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Query = $query" | Out-File -FilePath $log_file -Append
    
    if (-not $query -or $query.Length -lt 10) {
        # Query too short or missing
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Query too short, skipping" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    # Retrieve relevant context from vector store
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Retrieving context..." | Out-File -FilePath $log_file -Append
    $results_output = & python $vector_store_script retrieve $query --top-k 2 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        # Retrieval failed
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Retrieval failed, exit code = $LASTEXITCODE" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    # Extract JSON from output (filter out loading messages)
    $results_json = ""
    $json_started = $false
    foreach ($line in $results_output) {
        if ($line -match '^\s*\{') {
            $json_started = $true
        }
        if ($json_started) {
            $results_json += $line + "`n"
        }
    }
    
    if (-not $results_json) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: No JSON found in output" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    $results = $results_json | ConvertFrom-Json
    
    if (-not $results.results -or $results.results.Count -eq 0) {
        # No relevant results found
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: No results found" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    # Format retrieved context
    $context_text = "`n`n--- RELEVANT CONTEXT FROM PAST SESSIONS ---`n"
    $injected_count = 0
    
    foreach ($result in $results.results) {
        if ($result.score -gt 0.15) {
            $preview = $result.text
            if ($preview.Length -gt 300) {
                $preview = $preview.Substring(0, 300) + "..."
            }
            $context_text += "`nFrom previous conversation (relevance: $([math]::Round($result.score, 2))):`n$preview`n"
            $injected_count++
        }
    }
    
    if ($injected_count -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: No results above threshold" | Out-File -FilePath $log_file -Append
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    $context_text += "`n--- END CONTEXT ---`n`n"
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK: Injecting $injected_count results" | Out-File -FilePath $log_file -Append
    
    # Return additional context to inject
    @{
        additional_context = $context_text
    } | ConvertTo-Json -Compress
    
    exit 0
}
catch {
    # Fail open - don't block if context injection fails
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INJECT HOOK ERROR: $($_.Exception.Message)" | Out-File -FilePath $log_file -Append
    @{ } | ConvertTo-Json -Compress
    exit 0
}
