# Combined PreToolUse Safety Script
# Replaces individual hooks #1, #2, #3, #4, #5, #6, #7, #8, #11, #12
# One PowerShell process instead of 10

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$toolName = $json.tool_name
$cwd = $json.cwd

# === BASH TOOL CHECKS ===
if ($toolName -eq "Bash") {
    $command = $json.tool_input.command
    if (-not $command) { exit 0 }

    # Hook #1: Block Destructive Commands
    $destructivePatterns = @(
        @{ Pattern = 'rm\s+-rf\b';           Msg = "recursively delete files and directories" },
        @{ Pattern = 'rm\s+-r\b';            Msg = "recursively delete files and directories" },
        @{ Pattern = 'rm\s+.*\*';            Msg = "delete files matching a wildcard" },
        @{ Pattern = 'del\s+/s\s+/q\b';     Msg = "silently delete files recursively" },
        @{ Pattern = 'rd\s+/s\s+/q\b';      Msg = "silently remove directories recursively" },
        @{ Pattern = 'git\s+reset\s+--hard'; Msg = "discard all uncommitted changes" },
        @{ Pattern = 'git\s+checkout\s+\.';  Msg = "discard all unstaged changes" },
        @{ Pattern = 'git\s+clean\s+-[fd]';  Msg = "delete untracked files" },
        @{ Pattern = 'format\s+[a-zA-Z]:';  Msg = "format a disk drive" }
    )
    foreach ($p in $destructivePatterns) {
        if ($command -match $p.Pattern) {
            [Console]::Error.WriteLine("BLOCKED [Safety]: $command")
            [Console]::Error.WriteLine("This would $($p.Msg).")
            exit 2
        }
    }

    # Hook #7: Branch Protection
    if ($command -match 'git\s+push\s+.*--force') {
        [Console]::Error.WriteLine("BLOCKED [Git]: Force push is not allowed.")
        exit 2
    }
    if ($command -match 'git\s+push\s+\S+\s+(main|master)\b') {
        [Console]::Error.WriteLine("BLOCKED [Git]: Direct push to main/master is not allowed.")
        exit 2
    }

    # Hook #6: Uncommitted Work Guard
    $dangerousGit = @('git\s+reset\s+--hard', 'git\s+checkout\s+[a-zA-Z]', 'git\s+stash\s+drop', 'git\s+stash\s+clear', 'git\s+restore\s+\.')
    foreach ($pattern in $dangerousGit) {
        if ($command -match $pattern) {
            $gitStatus = & git -C $cwd status --porcelain 2>$null
            if ($gitStatus) {
                $count = ($gitStatus -split "`n" | Where-Object { $_ }).Count
                [Console]::Error.WriteLine("BLOCKED [Safety]: $command — you have $count uncommitted file(s).")
                exit 2
            }
        }
    }

    # Hook #11: Dangerous Interpreter Guard
    $interpreters = @('python3?\s+-c\s+', 'node\s+-e\s+', 'ruby\s+-e\s+', 'perl\s+-e\s+', 'powershell\s+-Command\s+')
    foreach ($pattern in $interpreters) {
        if ($command -match $pattern) {
            $inline = $command -replace "^.*?$pattern", ""
            if ($inline.Length -ge 80) {
                [Console]::Error.WriteLine("BLOCKED [Control]: Long inline script ($($inline.Length) chars). Write to a file first.")
                exit 2
            }
        }
    }

    # Hook #12 (Bash part): Test File Deletion Guard
    if ($command -match '\b(rm|del|Remove-Item)\b') {
        $testPatterns = @('test_.*\.py', '.*\.spec\.(ts|js)', '.*\.test\.(ts|js|tsx|jsx)', '.*_test\.go', 'conftest\.py')
        foreach ($tp in $testPatterns) {
            if ($command -match $tp) {
                [Console]::Error.WriteLine("BLOCKED [Control]: Cannot delete test files. Fix them, don't delete them.")
                exit 2
            }
        }
    }
}

# === WRITE TOOL CHECKS ===
if ($toolName -eq "Write") {
    $filePath = $json.tool_input.file_path
    $content = $json.tool_input.content
    if (-not $filePath) { exit 0 }

    $fileName = [System.IO.Path]::GetFileName($filePath)
    $fullPath = $filePath.Replace('\', '/')

    # Hook #2: Critical File Guard
    $criticalPatterns = @('\.env$', '\.env\..+$', 'docker-compose\.ya?ml$', 'Dockerfile$', '\.github/workflows/.+$', 'Jenkinsfile$', 'azure-pipelines\.ya?ml$', '\.claude/settings\.json$', '\.config\.(js|ts|mjs)$')
    foreach ($cp in $criticalPatterns) {
        if ($fullPath -match $cp) {
            [Console]::Error.WriteLine("BLOCKED [Safety]: Critical file $fileName — tell Claude exactly what to change.")
            exit 2
        }
    }

    # Hook #3: Large File Overwrite Guard
    if (Test-Path $filePath) {
        $lineCount = (Get-Content $filePath -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        if ($lineCount -ge 300) {
            [Console]::Error.WriteLine("BLOCKED [Safety]: $fileName has $lineCount lines. Use Edit instead of rewriting.")
            exit 2
        }
    }

    # Hook #4: Scope Boundary Guard
    if ($cwd) {
        $resolved = [System.IO.Path]::GetFullPath($filePath)
        $resolvedCwd = [System.IO.Path]::GetFullPath($cwd)
        if (-not $resolved.StartsWith($resolvedCwd, [System.StringComparison]::OrdinalIgnoreCase)) {
            [Console]::Error.WriteLine("BLOCKED [Safety]: File outside project: $resolved")
            exit 2
        }
    }

    # Hook #5: Secret Scanner
    if ($content) {
        $secretPatterns = @(
            @{ Name = "AWS Key";       Regex = 'AKIA[0-9A-Z]{16}' },
            @{ Name = "Private Key";   Regex = '-----BEGIN\s+(RSA|DSA|EC|OPENSSH)?\s*PRIVATE KEY-----' },
            @{ Name = "GitHub Token";  Regex = 'ghp_[A-Za-z0-9_]{36}' },
            @{ Name = "OpenAI Key";    Regex = 'sk-[A-Za-z0-9]{20,}' },
            @{ Name = "Slack Token";   Regex = 'xox[bprs]-[A-Za-z0-9\-]+' },
            @{ Name = "Generic Secret"; Regex = '(?i)(password|secret|token|api[_-]?key)\s*[:=]\s*["\x27]?[^\s"]{8,}' }
        )
        foreach ($sp in $secretPatterns) {
            if ($content -match $sp.Regex) {
                [Console]::Error.WriteLine("BLOCKED [Safety]: Potential $($sp.Name) detected in content.")
                exit 2
            }
        }
    }

    # Hook #8: Dependency Change Guard
    $depFiles = @('package.json','package-lock.json','requirements.txt','Pipfile','Pipfile.lock','Gemfile','Gemfile.lock','go.mod','go.sum','pom.xml','build.gradle','Cargo.toml','Cargo.lock')
    if ($depFiles -contains $fileName) {
        [Console]::Error.WriteLine("BLOCKED [Git]: Dependency file $fileName — review changes carefully.")
        exit 2
    }

    # Hook #12 (Write part): Test File Deletion Guard
    $testPatterns = @('test_.*\.py$', '.*\.spec\.(ts|js)$', '.*\.test\.(ts|js|tsx|jsx)$', '.*_test\.go$', 'conftest\.py$')
    $isTest = $false
    foreach ($tp in $testPatterns) { if ($fileName -match $tp) { $isTest = $true; break } }
    if ($isTest -and (Test-Path $filePath)) {
        $existing = (Get-Content $filePath | Measure-Object -Line).Lines
        $newLines = ($content -split "`n").Count
        if ($existing -gt 10 -and $newLines -lt ($existing * 0.5)) {
            [Console]::Error.WriteLine("BLOCKED [Control]: Test file $fileName would shrink from $existing to $newLines lines.")
            exit 2
        }
    }
}

# === EDIT TOOL CHECKS ===
if ($toolName -eq "Edit") {
    $filePath = $json.tool_input.file_path
    if (-not $filePath) { exit 0 }

    $fileName = [System.IO.Path]::GetFileName($filePath)
    $fullPath = $filePath.Replace('\', '/')

    # Hook #2: Critical File Guard (also applies to Edit)
    $criticalPatterns = @('\.env$', '\.env\..+$', 'docker-compose\.ya?ml$', 'Dockerfile$', '\.github/workflows/.+$', 'Jenkinsfile$', 'azure-pipelines\.ya?ml$', '\.claude/settings\.json$', '\.config\.(js|ts|mjs)$')
    foreach ($cp in $criticalPatterns) {
        if ($fullPath -match $cp) {
            [Console]::Error.WriteLine("BLOCKED [Safety]: Critical file $fileName — tell Claude exactly what to change.")
            exit 2
        }
    }

    # Hook #4: Scope Boundary Guard (also applies to Edit)
    if ($cwd) {
        $resolved = [System.IO.Path]::GetFullPath($filePath)
        $resolvedCwd = [System.IO.Path]::GetFullPath($cwd)
        if (-not $resolved.StartsWith($resolvedCwd, [System.StringComparison]::OrdinalIgnoreCase)) {
            [Console]::Error.WriteLine("BLOCKED [Safety]: File outside project: $resolved")
            exit 2
        }
    }

    # Hook #8: Dependency Change Guard (also applies to Edit)
    $depFiles = @('package.json','package-lock.json','requirements.txt','Pipfile','Pipfile.lock','Gemfile','Gemfile.lock','go.mod','go.sum','pom.xml','build.gradle','Cargo.toml','Cargo.lock')
    if ($depFiles -contains $fileName) {
        [Console]::Error.WriteLine("BLOCKED [Git]: Dependency file $fileName — review changes carefully.")
        exit 2
    }
}

exit 0
