# Design Spec: Hook #20 (Context Saver) + Hook Selection Guide

## Purpose

Two additions to the claude-code-hooks repo:
1. **Hook #20 — Context Saver**: Detects when conversation context exceeds ~70%, notifies the user, and saves a styled summary + transcript
2. **Hook Selection Guide**: A doc that tells people which hooks to use based on their role, project, and performance tolerance

---

## Hook #20: Context Saver

### Behavior

1. **PostToolUse** hook fires after every tool call
2. Script reads `transcript_path` from stdin JSON
3. Checks transcript file size — if estimated context > 70% AND no flag file exists for this session:
   - Parses the JSONL transcript to extract: file paths touched, tool names used, CWD
   - Generates topic keywords from file extensions + folder names + tool names
   - Creates a styled Markdown summary file in `~/.claude/saved-conversations/`
   - Shows a Windows balloon notification: "Context at ~73%. Conversation saved."
   - Creates a flag file so it only triggers once per session
4. User can review the saved file later — first 10 lines tell them everything

### Context Estimation

- Transcript file is JSONL (one JSON object per line)
- 1M context window ~ 750K tokens ~ 3MB of JSONL (rough heuristic)
- 70% threshold = ~2.1MB of transcript
- Configurable at top of script: `$THRESHOLD_PERCENT = 70` and `$ESTIMATED_FULL_SIZE_MB = 3`

### Summary File Format

Saved to: `~/.claude/saved-conversations/YYYY-MM-DD_HH-mm_<cwd-folder>.md`

Example: `2026-05-05_14-30_claude-code-hooks.md`

```markdown
# Session Summary

| Field | Value |
|-------|-------|
| Date | 2026-05-05 14:30:00 |
| CWD | `C:\Users\YOUR_USERNAME\Desktop\claude-code-hooks` |
| Session | `a1b2c3d4` |
| Context | ~73% used |

## Topics

`PowerShell` `hooks` `safety` `settings.json` `PreToolUse`

## Files Touched

| Action | File |
|--------|------|
| Created | `hooks/safety/01-block-destructive-commands/hook.ps1` |
| Modified | `README.md` |

---

<details>
<summary>Full Transcript (click to expand)</summary>

[raw JSONL content]

</details>
```

In VS Code markdown preview (Ctrl+Shift+V), this renders as:
- Clean metadata table
- Topic keywords as inline code badges
- Files touched as a table
- Full transcript hidden in a collapsible section (click to expand)

### Topic Keyword Extraction (No AI)

Parse each line of the JSONL transcript. For lines where `tool_name` is "Write" or "Edit":
- Extract file extension (`.ps1`, `.py`, `.ts`, `.md`)
- Extract parent folder name (`hooks/safety`, `docs`, `companion-scripts`)
- Collect unique tool names used (`Write`, `Edit`, `Bash`)

Deduplicate and take the top 8 keywords. These ARE the topics — no NLP needed.

### Files Touched Extraction

Parse JSONL lines for `tool_name` = "Write" or "Edit":
- Extract `tool_input.file_path`
- Check `tool_response.type`: "create" → Created, otherwise → Modified
- Deduplicate by file path, keep first action type

### One-Notification-Per-Session

Flag file: `$env:TEMP/.claude-context-saved-<session-id-first-8-chars>.flag`
Cleared on SessionStart by the same cleanup script as hook #10 (mass-change-detector).

### Notification

Windows balloon notification via `System.Windows.Forms.NotifyIcon`:
- Title: "Claude Code — Context Saver"
- Message: "Context at ~73%. Conversation saved to <filename>"

### Files

```
hooks/context/20-context-saver/
├── hook.ps1                    # Main PostToolUse hook
├── hook.sh                     # Bash alternative
├── settings-snippet.json       # PostToolUse, no matcher, timeout 10
└── README.md                   # Full documentation
```

Settings snippet: PostToolUse, no matcher (fires for all tools to track overall context growth), timeout 10 (needs time to parse JSONL and write summary).

---

## Hook Selection Guide

### File

`docs/which-hooks-do-i-need.md`

### Content

#### Performance Impact

Every hook spawns a process. PreToolUse hooks fire BEFORE each tool call — Claude waits for them.

| Hook Count | Overhead per tool call | Impact |
|-----------|----------------------|--------|
| 1-3 PreToolUse hooks | 0.5-1.5 seconds | Barely noticeable |
| 4-6 PreToolUse hooks | 1-3 seconds | Slight delay, worth it for safety |
| 7-10 PreToolUse hooks | 2-5 seconds | Noticeable delay on every action |
| 10+ PreToolUse hooks | 5+ seconds | Use the combined script instead |

PostToolUse hooks with `async: true` have zero impact — they run in the background.
Notification, SessionStart, Stop hooks fire rarely — negligible impact.

#### Presets

**Starter (3 hooks)** — Install these first, no exceptions
| # | Hook | Event | Why |
|---|------|-------|-----|
| 1 | Block Destructive Commands | PreToolUse | Prevents rm -rf, git reset --hard |
| 7 | Branch Protection | PreToolUse | Prevents push to main, force push |
| 13 | Sound on Completion | Notification | Know when Claude needs you |

Overhead: 2 PreToolUse processes per Bash command, 0 for Write/Edit. Minimal.

**Safe Default (6 hooks)** — Best protection-to-performance ratio
| # | Hook | Event | Why |
|---|------|-------|-----|
| 1 | Block Destructive Commands | PreToolUse | Core safety |
| 2 | Critical File Guard | PreToolUse | Protect .env, CI configs |
| 5 | Secret Scanner | PreToolUse | Catch API keys before they're written |
| 6 | Uncommitted Work Guard | PreToolUse | Don't lose uncommitted changes |
| 7 | Branch Protection | PreToolUse | Protect main branch |
| 13 | Sound on Completion | Notification | Awareness |

Overhead: 3-4 PreToolUse processes per tool call. Worth it.

**QA / Tester (9 hooks)** — For test-focused teams
| # | Hook | Event | Added because |
|---|------|-------|------|
| | All Safe Default hooks | | Core protection |
| 12 | Test File Deletion Guard | PreToolUse | Tests are sacred |
| 19 | Prompt Sensitive Data Audit | UserPromptSubmit | Don't paste creds |
| 20 | Context Saver | PostToolUse | Preserve session knowledge |

**Team / Shared Codebase (12 hooks)** — When multiple people work on the same repo
| # | Hook | Event | Added because |
|---|------|-------|------|
| | All Safe Default hooks | | Core protection |
| 3 | Large File Overwrite Guard | PreToolUse | Protect large shared files |
| 8 | Dependency Change Guard | PreToolUse | Lock file changes need review |
| 10 | Mass Change Detector | PostToolUse | Catch runaway refactors |
| 15 | Session Summary on Exit | Stop | Track who did what |
| 18 | Session Context Loader | SessionStart | Know the current state |
| 20 | Context Saver | PostToolUse | Audit trail |

**Everything (all 20)** — Maximum protection, use the combined script
For this preset, recommend using the combined-safety.ps1 to reduce PreToolUse overhead.

#### The Combined Safety Script (Performance Optimization)

For advanced users running 6+ PreToolUse hooks: instead of 6 separate PowerShell processes, combine all PreToolUse checks into ONE script.

`optimized/combined-pretooluse.ps1` — A single script that:
1. Reads stdin JSON once
2. Checks tool_name to decide which checks apply
3. Runs all relevant checks (destructive commands, critical files, secrets, etc.)
4. Exits 2 on first match, exits 0 if all pass

This reduces 6 processes to 1 — from 3 seconds overhead to 0.5 seconds.

Provide this as an `optimized/` folder in the repo with:
- `combined-pretooluse.ps1` (all PreToolUse checks in one script)
- `combined-pretooluse.sh` (bash version)
- `settings-snippet.json` (single PreToolUse entry, no matcher)
- `README.md` (explains the optimization, which individual hooks it replaces)

### File Structure for New Additions

```
hooks/context/20-context-saver/        # Hook #20
├── hook.ps1
├── hook.sh
├── settings-snippet.json
└── README.md

optimized/                              # Combined script
├── combined-pretooluse.ps1
├── combined-pretooluse.sh
├── settings-snippet.json
└── README.md

docs/which-hooks-do-i-need.md          # Selection guide
```

### Updates to Existing Files

- `README.md` — Add hook #20 to catalog, add "Which Hooks Do I Need?" section linking to the guide
- `docs/hooks-explained.md` — Add performance section noting the combined script option

---

## Verification

1. Hook #20: Start a session, work until transcript > 2.1MB (or lower threshold for testing), verify notification fires and summary file is created with correct metadata + topics + collapsible transcript
2. Selection guide: Review presets for accuracy — each preset should be self-contained
3. Combined script: Replace 6 individual PreToolUse hooks with the combined one, verify all checks still work
4. Summary file: Open in VS Code, press Ctrl+Shift+V, verify it renders with tables, code badges, and collapsible transcript
