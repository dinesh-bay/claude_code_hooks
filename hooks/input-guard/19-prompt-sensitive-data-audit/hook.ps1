# hook.ps1 — Prompt Sensitive Data Audit
# Event: UserPromptSubmit | Matcher: none
# Exit 0 = allow, Exit 2 = block (stderr shown to user)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json

# UserPromptSubmit may have the prompt in different fields — try common ones
$prompt = $json.tool_input.prompt
if (-not $prompt) { $prompt = $json.message }
if (-not $prompt) { $prompt = $json.content }
if (-not $prompt) { exit 0 }

$patterns = @(
    @{ Name = "AWS Access Key";    Regex = 'AKIA[0-9A-Z]{16}' },
    @{ Name = "Private Key";       Regex = '-----BEGIN\s+(RSA|DSA|EC|OPENSSH)?\s*PRIVATE KEY-----' },
    @{ Name = "GitHub Token";      Regex = 'ghp_[A-Za-z0-9_]{36}' },
    @{ Name = "Slack Token";       Regex = 'xox[bprs]-[A-Za-z0-9\-]+' },
    @{ Name = "OpenAI API Key";    Regex = 'sk-[A-Za-z0-9]{20,}' },
    @{ Name = "Connection String"; Regex = '(?i)(server|data source)=[^;]+;.*(password|pwd)=[^;]+' },
    @{ Name = "Bearer Token";      Regex = '(?i)bearer\s+[A-Za-z0-9_\-\.]{20,}' }
)

foreach ($p in $patterns) {
    if ($prompt -match $p.Regex) {
        [Console]::Error.WriteLine("WARNING: Your message may contain a $($p.Name).")
        [Console]::Error.WriteLine("Sensitive data sent to Claude becomes part of the conversation.")
        [Console]::Error.WriteLine("Consider removing it and using environment variables or CONFIG references instead.")
        exit 2
    }
}

exit 0
