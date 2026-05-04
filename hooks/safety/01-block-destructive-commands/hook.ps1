# hook.ps1 — Block Destructive Commands
# Event: PreToolUse | Matcher: Bash
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$command = $json.tool_input.command

if (-not $command) { exit 0 }

$patterns = @(
    @{ Pattern = 'rm\s+-rf\b';           Consequence = "recursively delete files and directories" },
    @{ Pattern = 'rm\s+-r\b';            Consequence = "recursively delete files and directories" },
    @{ Pattern = 'rm\s+.*\*';            Consequence = "delete files matching a wildcard pattern" },
    @{ Pattern = 'del\s+/s\s+/q\b';     Consequence = "silently delete files recursively" },
    @{ Pattern = 'rd\s+/s\s+/q\b';      Consequence = "silently remove directories recursively" },
    @{ Pattern = 'rmdir\s+/s\s+/q\b';   Consequence = "silently remove directories recursively" },
    @{ Pattern = 'git\s+reset\s+--hard'; Consequence = "discard all uncommitted changes permanently" },
    @{ Pattern = 'git\s+checkout\s+\.';  Consequence = "discard all unstaged changes in the working directory" },
    @{ Pattern = 'git\s+clean\s+-[fd]';  Consequence = "delete untracked files and directories" },
    @{ Pattern = 'format\s+[a-zA-Z]:';  Consequence = "format a disk drive" }
)

foreach ($p in $patterns) {
    if ($command -match $p.Pattern) {
        [Console]::Error.WriteLine("BLOCKED: $command")
        [Console]::Error.WriteLine("This would $($p.Consequence).")
        [Console]::Error.WriteLine("If intentional, run it manually in your terminal.")
        exit 2
    }
}

exit 0
