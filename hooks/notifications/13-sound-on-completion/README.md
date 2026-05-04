# Sound on Completion

> Plays a system sound when Claude finishes working and needs your input. The simplest possible hook -- a great starting point.

**Category:** Notifications
**Event:** Notification
**Matcher:** None
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude Code often takes 30 seconds to several minutes to complete a task. You tab away to another window, check your email, or read documentation. When you tab back, Claude has been sitting idle for two minutes waiting for your next prompt.

This hook plays an audible sound the moment Claude finishes, so you know it is time to come back without constantly checking.

## How It Works

1. Claude finishes a response and fires the Notification event
2. The hook script runs
3. **Windows:** Plays the system Exclamation sound via `System.Media.SystemSounds`
4. **macOS:** Plays the Glass sound via `afplay`
5. **Linux:** Plays the freedesktop completion sound via `paplay`, or falls back to a terminal bell

That is the entire hook. No stdin parsing, no decisions, no exit codes to worry about.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/sound-on-completion.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `Notification` entry into it.

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/sound-on-completion.ps1",
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
  "command": "bash ~/.claude/hooks/sound-on-completion.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Start a Claude session and ask it to do something that takes a few seconds:

> "List all files in this directory and explain each one"

When Claude finishes, you should hear the system sound.

## Configuration

**Change the Windows sound:** Replace `Exclamation` with another member of `System.Media.SystemSounds`:

```powershell
# Options: Asterisk, Beep, Exclamation, Hand, Question
[System.Media.SystemSounds]::Asterisk.Play()
```

**Change the macOS sound:** Replace the path in `hook.sh` with any `.aiff` file in `/System/Library/Sounds/`:

```bash
afplay /System/Library/Sounds/Ping.aiff
```

**Use a custom sound file:** Point to any audio file your system can play:

```powershell
# Windows — play a .wav file
(New-Object System.Media.SoundPlayer "C:\path\to\sound.wav").PlaySync()
```

## Limitations

- **Windows sound is brief.** The Exclamation sound is a short chime. If your volume is low or you are wearing headphones on another device, you may miss it. Consider pairing with [Desktop Toast](../14-desktop-toast/) for a visual backup.
- **No message content.** This hook ignores the notification message entirely. It just plays a sound regardless of what Claude said. If you want to see the message, use [Desktop Toast](../14-desktop-toast/) instead.
- **Linux sound depends on PulseAudio.** The `paplay` command requires PulseAudio. On systems using PipeWire or bare ALSA, the fallback terminal bell (`\a`) fires instead.
