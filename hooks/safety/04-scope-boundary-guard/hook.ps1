# hook.ps1 — Scope Boundary Guard
# Event: PreToolUse | Matcher: Write, Edit
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$cwd = $json.cwd
$toolName = $json.tool_name

if (-not $cwd) { exit 0 }

$targetPath = $null
if ($toolName -eq "Write" -or $toolName -eq "Edit") {
    $targetPath = $json.tool_input.file_path
}

if (-not $targetPath) { exit 0 }

$resolvedTarget = [System.IO.Path]::GetFullPath($targetPath)
$resolvedCwd = [System.IO.Path]::GetFullPath($cwd)

if (-not $resolvedTarget.StartsWith($resolvedCwd, [System.StringComparison]::OrdinalIgnoreCase)) {
    [Console]::Error.WriteLine("BLOCKED: Operation targets a file outside your project.")
    [Console]::Error.WriteLine("  Target: $resolvedTarget")
    [Console]::Error.WriteLine("  Project: $resolvedCwd")
    [Console]::Error.WriteLine("If intentional, run it manually or use additionalDirectories in settings.")
    exit 2
}

exit 0
