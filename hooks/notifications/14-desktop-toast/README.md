# Desktop Toast

> Shows a native desktop notification when Claude finishes working. Displays the actual message content so you know what Claude needs without switching windows.

**Category:** Notifications
**Event:** Notification
**Matcher:** None
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

You are working in another window -- a browser, a document, a Teams call. Claude finishes and needs your input, but you have no way of knowing without manually checking the terminal. By the time you notice, you have wasted five minutes doing nothing.

This hook pops a native desktop notification with Claude's message, visible regardless of which window is in focus.

## How It Works

1. Claude finishes a response and fires the Notification event
2. The hook reads the stdin JSON and extracts the `message` field
3. If no message is present, it falls back to "Claude Code needs your attention"
4. **Windows:** Creates a system tray balloon notification using `System.Windows.Forms.NotifyIcon`
5. **macOS:** Triggers a native notification via `osascript`
6. **Linux:** Uses `notify-send` (requires `libnotify`)

The notification shows for about 3 seconds and then dismisses itself.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/desktop-toast.ps1
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
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/desktop-toast.ps1",
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
  "command": "bash ~/.claude/hooks/desktop-toast.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Switch to another window (browser, file explorer, anything), then ask Claude:

> "What time is it?"

You should see a native notification pop up with Claude's response message, visible even though the terminal is not in focus.

## Combining with Sound on Completion

This hook pairs well with [Sound on Completion](../13-sound-on-completion/). You can register both hooks on the same Notification event -- they run independently:

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
          },
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/desktop-toast.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Now you get both an audible chime and a visual popup.

## Configuration

**Change the notification duration:** Modify the `3000` in `ShowBalloonTip(3000, ...)` to a different value in milliseconds. Note that Windows may override this with its own notification timeout.

**Change the icon:** Replace `[System.Drawing.SystemIcons]::Information` with another system icon:

```powershell
# Options: Application, Asterisk, Error, Exclamation, Hand, Information, Question, Shield, Warning, WinLogo
$notify.Icon = [System.Drawing.SystemIcons]::Application
```

**Fallback message:** Change the default message in the `if (-not $message)` block to whatever you prefer.

## Limitations

- **Windows balloon notifications are basic.** They appear in the system tray area and disappear after a few seconds. On Windows 10/11, they may be routed to the Action Center depending on your notification settings. If notifications are set to "Do Not Disturb" or "Focus Assist", the balloon may be suppressed.
- **The 500ms sleep is required.** Without it, the `NotifyIcon` is disposed before the balloon has time to render. This adds a small delay to hook completion but is well within the 5-second timeout.
- **macOS notifications require terminal permissions.** The first time `osascript` sends a notification, macOS may prompt you to allow notifications from Terminal (or whatever app runs the shell). You need to approve this once.
- **Linux requires libnotify.** The `notify-send` command is part of `libnotify-bin` (Debian/Ubuntu) or `libnotify` (Fedora/Arch). Install it with your package manager if not already present.
