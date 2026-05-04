# Prompt Sensitive Data Audit

> Scans your messages for accidentally pasted secrets before Claude ever sees them.

**Category:** Input Guard
**Event:** UserPromptSubmit
**Matcher:** None (fires for every message you send)
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

You are debugging a database connection issue. You copy the connection string from your app's config to your clipboard, intending to paste it into a config file. Instead, you paste it straight into Claude's input box and hit Enter.

Now that connection string -- with the production password embedded -- is part of your conversation. Claude has seen it. Depending on your setup, it may be sent to Anthropic's servers and stored in conversation history.

The same thing happens with API keys, bearer tokens, and private key blocks. You copy them while working and accidentally paste them into the wrong place. This hook catches it before the message leaves your machine.

## What It Detects

| Pattern Name | What It Matches | Example |
|-------------|-----------------|---------|
| AWS Access Key | `AKIA` followed by 16 uppercase alphanumeric characters | `AKIAIOSFODNN7EXAMPLE` |
| Private Key | PEM-encoded private key headers | `-----BEGIN RSA PRIVATE KEY-----` |
| GitHub Token | `ghp_` followed by 36 alphanumeric characters | `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| Slack Token | `xoxb-`, `xoxp-`, `xoxr-`, `xoxs-` prefixed tokens | `xoxb-123456789-abcdefghij` |
| OpenAI API Key | `sk-` followed by 20+ alphanumeric characters | `sk-abcdefghijklmnopqrstuvwxyz1234` |
| Connection String | Server/Data Source with embedded password | `Server=prod.db.com;Database=app;Password=s3cret` |
| Bearer Token | `Bearer` followed by 20+ characters | `Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6...` |

## How It Works

1. You type (or paste) a message and press Enter
2. The UserPromptSubmit hook fires before Claude processes the message
3. The script reads the message text from stdin JSON
4. It runs the text against 7 regex patterns that match common secret formats
5. **Pattern matched:** exits with code 2 (block) -- the message is NOT sent to Claude, and you see a warning
6. **No patterns matched:** exits with code 0, the message is sent to Claude normally

The key difference from the Secret Scanner (hook #5) is timing. The Secret Scanner checks content Claude is about to *write to a file*. This hook checks content *you are about to send to Claude*. It protects the conversation itself, not the filesystem.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/prompt-sensitive-data-audit.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `UserPromptSubmit` entry into it.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/prompt-sensitive-data-audit.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

UserPromptSubmit hooks do not have a `matcher` field -- they fire for every message you send.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/prompt-sensitive-data-audit.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Type the following into Claude Code:

> "Debug this connection: Server=localhost;Database=myapp;Password=hunter2"

You should see a block message:

```
WARNING: Your message may contain a Connection String.
Sensitive data sent to Claude becomes part of the conversation.
Consider removing it and using environment variables or CONFIG references instead.
```

The message is not sent. Remove the sensitive data and try again.

## Configuration

The pattern list is defined in the `$patterns` array at the top of the script. Each entry has a `Name` (shown in the warning) and a `Regex` (the detection pattern).

To add a new pattern:

```powershell
@{ Name = "Stripe Secret Key"; Regex = 'sk_live_[A-Za-z0-9]{24,}' }
```

To reduce false positives, make patterns more specific (e.g., require longer key lengths) or remove patterns that conflict with your normal workflow.

## Limitations

- **Regex-based, not entropy-based.** This catches known secret formats but not arbitrary high-entropy strings. A 64-character random hex value without a known prefix would pass through.
- **Only your typed/pasted input is scanned.** If Claude generates a secret in a response and you reference it later, the hook does not retroactively flag it.
- **Exit code 2 blocks the message entirely.** There is no partial redaction -- you need to edit the message yourself and resend. This is intentional: partial redaction could leave fragments that still leak context.
- **False positives are possible.** If you routinely discuss secret formats, regex patterns, or security documentation, the hook may block legitimate messages. Narrow the patterns or remove specific entries for your workflow.
- **The `UserPromptSubmit` event field structure may vary.** The script tries multiple common field names (`tool_input.prompt`, `message`, `content`). If Claude Code changes the event payload, the script may need updating.
