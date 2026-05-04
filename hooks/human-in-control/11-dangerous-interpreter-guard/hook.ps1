# hook.ps1 — Dangerous Interpreter Guard
# Event: PreToolUse | Matcher: Bash
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$command = $json.tool_input.command

if (-not $command) { exit 0 }

$CHAR_THRESHOLD = 80

$interpreterPatterns = @(
    'python3?\s+-c\s+',
    'node\s+-e\s+',
    'ruby\s+-e\s+',
    'perl\s+-e\s+',
    'powershell\s+-Command\s+'
)

foreach ($pattern in $interpreterPatterns) {
    if ($command -match $pattern) {
        $inlineCode = $command -replace "^.*?$pattern", ""
        if ($inlineCode.Length -ge $CHAR_THRESHOLD) {
            [Console]::Error.WriteLine("BLOCKED: Long inline script detected ($($inlineCode.Length) chars).")
            [Console]::Error.WriteLine("Command starts with: $($command.Substring(0, [Math]::Min(100, $command.Length)))...")
            [Console]::Error.WriteLine("Write this to a file first so it can be reviewed.")
            exit 2
        }
    }
}

exit 0
