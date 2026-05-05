# Which Hooks Do I Need?

Every hook spawns a process. This guide helps you pick the right ones without slowing Claude down.

## Performance Impact

PreToolUse hooks fire BEFORE each tool call -- Claude waits for them to finish.

| Hook Count (PreToolUse) | Overhead per tool call | Feels like... |
|------------------------|----------------------|---------------|
| 1-3 | 0.5-1.5 seconds | Barely noticeable |
| 4-6 | 1-3 seconds | Slight pause, worth it for safety |
| 7-10 | 2-5 seconds | Noticeable delay on every action |
| 10+ | 5+ seconds | Use the [combined script](../optimized/) instead |

**Zero-cost hooks** (don't affect tool speed):
- PostToolUse with `async: true` (clipboard, formatting)
- Notification hooks (sound, toast)
- SessionStart hooks (context loader)
- Stop hooks (session summary)
- PreCompact hooks (transcript backup)

These run in the background or fire rarely. Install as many as you want.

## Presets

### Starter -- Install These First (3 hooks)

The non-negotiable minimum. If you use Claude Code, you need these.

| # | Hook | Event | Why |
|---|------|-------|-----|
| 1 | [Block Destructive Commands](../hooks/safety/01-block-destructive-commands/) | PreToolUse | Prevents rm -rf, git reset --hard |
| 7 | [Branch Protection](../hooks/git/07-branch-protection/) | PreToolUse | Prevents push to main, force push |
| 13 | [Sound on Completion](../hooks/notifications/13-sound-on-completion/) | Notification | Know when Claude needs you |

**Performance**: 2 PreToolUse processes per Bash command, 0 for Write/Edit. Minimal.

### Safe Default -- Best Protection-to-Performance Ratio (6 hooks)

For daily Claude Code users who want solid protection without slowdown.

| # | Hook | Event | Why |
|---|------|-------|-----|
| 1 | Block Destructive Commands | PreToolUse | Core safety |
| 2 | [Critical File Guard](../hooks/safety/02-critical-file-guard/) | PreToolUse | Protect .env, CI configs, Dockerfiles |
| 5 | [Secret Scanner](../hooks/safety/05-secret-scanner/) | PreToolUse | Catch API keys before they're written |
| 6 | [Uncommitted Work Guard](../hooks/safety/06-uncommitted-work-guard/) | PreToolUse | Don't lose uncommitted changes |
| 7 | Branch Protection | PreToolUse | Protect main branch |
| 13 | Sound on Completion | Notification | Awareness |

**Performance**: 3-4 PreToolUse processes per tool call (~1.5-2 seconds). Worth it.

### QA / Tester (9 hooks)

For QA teams and testers adopting AI coding tools.

| # | Hook | Event | Added because |
|---|------|-------|--------------|
| | _All Safe Default hooks_ | | Core protection |
| 12 | [Test File Deletion Guard](../hooks/human-in-control/12-test-file-deletion-guard/) | PreToolUse | Tests are sacred -- never delete them |
| 19 | [Prompt Sensitive Data Audit](../hooks/input-guard/19-prompt-sensitive-data-audit/) | UserPromptSubmit | Don't accidentally paste credentials |
| 20 | [Context Saver](../hooks/context/20-context-saver/) | PostToolUse | Preserve session knowledge across 5+ sessions |

**Performance**: 5 PreToolUse + async PostToolUse. ~2-2.5 seconds per tool call.

### Team / Shared Codebase (12 hooks)

When multiple people work on the same repo and you need guardrails + audit trail.

| # | Hook | Event | Added because |
|---|------|-------|--------------|
| | _All Safe Default hooks_ | | Core protection |
| 3 | [Large File Overwrite Guard](../hooks/safety/03-large-file-overwrite-guard/) | PreToolUse | Protect large shared files from rewrites |
| 8 | [Dependency Change Guard](../hooks/git/08-dependency-change-guard/) | PreToolUse | Lock file changes need review |
| 10 | [Mass Change Detector](../hooks/human-in-control/10-mass-change-detector/) | PostToolUse | Catch runaway refactors |
| 15 | [Session Summary on Exit](../hooks/notifications/15-session-summary-on-exit/) | Stop | Track who did what |
| 18 | [Session Context Loader](../hooks/productivity/18-session-context-loader/) | SessionStart | Know the current state |
| 20 | [Context Saver](../hooks/context/20-context-saver/) | PostToolUse | Audit trail |

**Performance**: 6 PreToolUse processes per tool call (~3 seconds). Consider the [combined script](../optimized/) to reduce to ~0.5 seconds.

### Everything (all 20 hooks)

Maximum protection. **Must use the [combined script](../optimized/)** to keep performance acceptable.

**Performance without combined script**: 10+ PreToolUse processes (5+ seconds per tool call). Not recommended.
**Performance with combined script**: 1 PreToolUse process + async PostToolUse (~0.5-1 second). Acceptable.

## How To Choose

Ask yourself:
1. **Am I working alone or on a shared codebase?** -- Shared = Team preset
2. **Do I write tests?** -- Yes = QA/Tester preset
3. **Am I worried about data loss?** -- Start with Safe Default
4. **Am I just starting with hooks?** -- Starter preset, add more later

## Upgrading

Start with Starter. After a week, if you haven't been slowed down, upgrade to Safe Default. Then add individual hooks as you hit specific pain points. You don't need to jump to "Everything" -- most people are fine with 6-9 hooks.
