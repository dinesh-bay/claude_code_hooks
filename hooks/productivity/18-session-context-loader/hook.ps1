$cwd = Get-Location

$branch = & git -C $cwd branch --show-current 2>$null
$recentCommits = & git -C $cwd log --oneline -5 2>$null

$output = ""
if ($branch) { $output += "Current branch: $branch`n" }
if ($recentCommits) { $output += "Recent commits:`n$recentCommits`n" }

$todoCount = (Get-ChildItem -Path $cwd -Recurse -Include "*.py","*.ts","*.js" -File -ErrorAction SilentlyContinue |
    Select-String -Pattern "TODO|FIXME|HACK" -ErrorAction SilentlyContinue |
    Measure-Object).Count

if ($todoCount -gt 0) { $output += "`nTODO/FIXME/HACK count: $todoCount" }

if ($output) { Write-Output $output }
exit 0
