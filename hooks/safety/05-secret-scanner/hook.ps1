# hook.ps1 — Secret Scanner
# Event: PreToolUse | Matcher: Write
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$content = $json.tool_input.content

if (-not $content) { exit 0 }

$patterns = @(
    @{ Name = "AWS Access Key";    Regex = 'AKIA[0-9A-Z]{16}' },
    @{ Name = "AWS Secret Key";    Regex = '(?i)aws_secret_access_key\s*[:=]\s*\S+' },
    @{ Name = "Private Key";       Regex = '-----BEGIN\s+(RSA|DSA|EC|OPENSSH)?\s*PRIVATE KEY-----' },
    @{ Name = "GitHub Token";      Regex = 'ghp_[A-Za-z0-9_]{36}' },
    @{ Name = "Slack Token";       Regex = 'xox[bprs]-[A-Za-z0-9\-]+' },
    @{ Name = "OpenAI API Key";    Regex = 'sk-[A-Za-z0-9]{20,}' },
    @{ Name = "Generic API Key";   Regex = '(?i)(api[_-]?key|apikey)\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{20,}' },
    @{ Name = "Generic Password";  Regex = '(?i)(password|passwd|pwd)\s*[:=]\s*["\x27]?[^\s"]{8,}' },
    @{ Name = "Generic Secret";    Regex = '(?i)(secret|token)\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{20,}' }
)

foreach ($p in $patterns) {
    if ($content -match $p.Regex) {
        [Console]::Error.WriteLine("BLOCKED: Potential $($p.Name) detected in file content.")
        [Console]::Error.WriteLine("Review the content before allowing this write.")
        [Console]::Error.WriteLine("If this is a false positive (e.g., test fixture), run it manually.")
        exit 2
    }
}

exit 0
