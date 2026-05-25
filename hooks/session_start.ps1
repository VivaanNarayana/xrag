# Session Start Hook - Initialize vector store session
param()

# Read hook input from stdin
$input_json = [Console]::In.ReadToEnd()

# Get script directory
$script_dir = Split-Path -Parent $PSCommandPath
$skills_dir = Split-Path -Parent $script_dir
$log_file = Join-Path $skills_dir "hook_debug.log"
$vector_store_script = Join-Path $skills_dir "vector_store.py"

# Log that hook was called
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SESSION START HOOK CALLED" | Out-File -FilePath $log_file -Append
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Raw input: $input_json" | Out-File -FilePath $log_file -Append

$hook_input = $input_json | ConvertFrom-Json

# Log session start
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
$session_id = $hook_input.session_id
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Session ID: $session_id" | Out-File -FilePath $log_file -Append

try {
    # Check if Python and dependencies are available
    $python_check = python -c "import sentence_transformers, faiss" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        # Dependencies not installed, fail silently
        Write-Error "Vector store dependencies not installed" -ErrorAction SilentlyContinue
        @{ } | ConvertTo-Json -Compress
        exit 0
    }
    
    # Ensure vector store is initialized
    & python $vector_store_script init 2>&1 | Out-Null
    
    # Return success
    @{ } | ConvertTo-Json -Compress
    exit 0
}
catch {
    # Fail open - don't block session start if vector store fails
    @{ } | ConvertTo-Json -Compress
    exit 0
}
