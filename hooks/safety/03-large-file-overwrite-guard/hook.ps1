# hook.ps1 — Large File Overwrite Guard
# Event: PreToolUse | Matcher: Write
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$filePath = $json.tool_input.file_path

if (-not $filePath) { exit 0 }

$THRESHOLD = 300

if (Test-Path $filePath) {
    $lineCount = (Get-Content $filePath -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    if ($lineCount -ge $THRESHOLD) {
        $fileName = [System.IO.Path]::GetFileName($filePath)
        [Console]::Error.WriteLine("BLOCKED: About to overwrite $fileName ($lineCount lines).")
        [Console]::Error.WriteLine("Use the Edit tool for targeted changes instead of rewriting the entire file.")
        [Console]::Error.WriteLine("If a full rewrite is truly needed, run it manually.")
        exit 2
    }
}

exit 0
