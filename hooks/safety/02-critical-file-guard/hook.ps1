# hook.ps1 — Critical File Guard
# Event: PreToolUse | Matcher: Write, Edit
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$filePath = $json.tool_input.file_path

if (-not $filePath) { exit 0 }

$fileName = [System.IO.Path]::GetFileName($filePath)
$fullPath = $filePath.Replace('\', '/')

$protectedPatterns = @(
    '\.env$',
    '\.env\..+$',
    'docker-compose\.ya?ml$',
    'Dockerfile$',
    '\.github/workflows/.+$',
    'Jenkinsfile$',
    'azure-pipelines\.ya?ml$',
    '\.claude/settings\.json$',
    '\.config\.(js|ts|mjs)$'
)

foreach ($pattern in $protectedPatterns) {
    if ($fullPath -match $pattern) {
        [Console]::Error.WriteLine("BLOCKED: Modification to critical file: $fileName")
        [Console]::Error.WriteLine("This is a configuration/infrastructure file that should not be overwritten wholesale.")
        [Console]::Error.WriteLine("Tell Claude exactly what line or value to change instead.")
        exit 2
    }
}

exit 0
