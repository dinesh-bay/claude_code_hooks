# hook.ps1 — Test File Deletion Guard
# Event: PreToolUse | Matcher: Bash, Write
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$toolName = $json.tool_name

$testPatterns = @(
    'test_.*\.py$',
    '.*\.spec\.(ts|js)$',
    '.*\.test\.(ts|js|tsx|jsx)$',
    '.*_test\.go$',
    'conftest\.py$',
    '.*\.test\.py$'
)

if ($toolName -eq "Bash") {
    $command = $json.tool_input.command
    if (-not $command) { exit 0 }

    if ($command -match '\b(rm|del|Remove-Item)\b') {
        foreach ($pattern in $testPatterns) {
            if ($command -match $pattern) {
                [Console]::Error.WriteLine("BLOCKED: Attempted to delete a test file.")
                [Console]::Error.WriteLine("Command: $command")
                [Console]::Error.WriteLine("Tests are your safety net. Fix the tests, don't delete them.")
                exit 2
            }
        }
    }
}

if ($toolName -eq "Write") {
    $filePath = $json.tool_input.file_path
    if (-not $filePath) { exit 0 }

    $fileName = [System.IO.Path]::GetFileName($filePath)
    $isTestFile = $false
    foreach ($pattern in $testPatterns) {
        if ($fileName -match $pattern) { $isTestFile = $true; break }
    }

    if ($isTestFile -and (Test-Path $filePath)) {
        $existingLines = (Get-Content $filePath | Measure-Object -Line).Lines
        $newContent = $json.tool_input.content
        $newLines = ($newContent -split "`n").Count

        if ($existingLines -gt 10 -and $newLines -lt ($existingLines * 0.5)) {
            [Console]::Error.WriteLine("BLOCKED: About to overwrite test file $fileName ($existingLines lines -> $newLines lines).")
            [Console]::Error.WriteLine("This would remove more than half the test content.")
            [Console]::Error.WriteLine("Use Edit for targeted changes instead.")
            exit 2
        }
    }
}

exit 0
