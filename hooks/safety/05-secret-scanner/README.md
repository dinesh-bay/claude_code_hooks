# Secret Scanner

> Scans file content for API keys, passwords, tokens, and private keys before Claude writes them to disk.

**Category:** Safety
**Event:** PreToolUse
**Matcher:** Write
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude sometimes generates code with hardcoded credentials -- example API keys copied from documentation, placeholder passwords that look real, or secrets it inferred from context. If these end up in a file that gets committed to git, you have a secret leak. Even if you catch it later, the secret is in your git history forever (unless you rewrite history).

This hook scans the content Claude is about to write and blocks it if it detects patterns that look like real secrets.

## What It Detects

| Pattern Name | What It Matches | Example |
|-------------|-----------------|---------|
| AWS Access Key | `AKIA` followed by 16 uppercase alphanumeric characters | `AKIAIOSFODNN7EXAMPLE` |
| AWS Secret Key | `aws_secret_access_key` followed by a value | `aws_secret_access_key = wJalrXUtnFEMI/...` |
| Private Key | PEM-encoded private key headers | `-----BEGIN RSA PRIVATE KEY-----` |
| GitHub Token | `ghp_` followed by 36 alphanumeric characters | `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| Slack Token | `xoxb-`, `xoxp-`, `xoxr-`, `xoxs-` prefixed tokens | `xoxb-123456789-abcdefghij` |
| OpenAI API Key | `sk-` followed by 20+ alphanumeric characters | `sk-abcdefghijklmnopqrstuvwxyz1234` |
| Generic API Key | Key-value pairs with `api_key`, `apikey`, etc. | `api_key = "abc123def456ghi789jkl"` |
| Generic Password | Key-value pairs with `password`, `passwd`, `pwd` | `password: "mysecretpassword123"` |
| Generic Secret | Key-value pairs with `secret` or `token` | `secret = "abcdef1234567890abcdef"` |

## How It Works

1. Claude calls the Write tool with file content
2. The PreToolUse hook fires before the file is written
3. The script reads the stdin JSON and extracts `tool_input.content`
4. It runs the content against 9 regex patterns that match common secret formats
5. **Pattern matched:** exits with code 2 (block) and names the detected secret type
6. **No patterns matched:** exits with code 0, Claude writes the file normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/secret-scanner.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/secret-scanner.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/secret-scanner.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Create a file called test-config.py with the content: API_KEY = 'AKIAIOSFODNN7EXAMPLE1'"

You should see a block message:

```
BLOCKED: Potential AWS Access Key detected in file content.
Review the content before allowing this write.
If this is a false positive (e.g., test fixture), run it manually.
```

## Configuration

The pattern list is defined in the `$patterns` array at the top of the script. Each entry has a `Name` (shown in the block message) and a `Regex` (the detection pattern).

To add a new pattern:

```powershell
@{ Name = "Stripe Secret Key"; Regex = 'sk_live_[A-Za-z0-9]{24,}' }
```

To reduce false positives, you can make patterns more specific (e.g., require longer key lengths) or remove overly broad patterns like "Generic Password".

## Limitations

- **Only the Write tool is scanned.** Content written via the Edit tool (which sends `old_string` and `new_string`) is not checked. A determined pattern could also slip through if Claude uses Bash to write files (`echo "secret" > file.txt`).
- **Regex-based, not entropy-based.** This catches known formats but not random high-entropy strings that could be secrets. A 64-character random hex string without a recognizable prefix would pass through.
- **False positives are possible.** Test fixtures with example keys (like AWS documentation examples), password validation code, or comments explaining secret formats may trigger the scanner. The block message suggests running manually for these cases.
- **Only content is scanned, not file names.** Writing to a file called `secrets.json` is not blocked by this hook (use the Critical File Guard for path-based protection).
- **Large content may be slow.** The regex runs against the entire file content. For very large generated files (10,000+ lines), this adds a small delay but should stay within the 5-second timeout.
