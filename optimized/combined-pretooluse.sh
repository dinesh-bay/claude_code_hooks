#!/usr/bin/env bash
# Combined PreToolUse Safety Script (Bash version)
# Replaces individual hooks #1, #2, #3, #4, #5, #6, #7, #8, #11, #12
# One process instead of 10
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))")
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))")

# === BASH TOOL CHECKS ===
if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))")
    [ -z "$COMMAND" ] && exit 0

    # Hook #1: Block Destructive Commands
    if echo "$COMMAND" | grep -qP 'rm\s+-rf\b'; then
        echo "BLOCKED [Safety]: $COMMAND" >&2
        echo "This would recursively delete files and directories." >&2
        exit 2
    fi
    if echo "$COMMAND" | grep -qP 'rm\s+-r\b'; then
        echo "BLOCKED [Safety]: $COMMAND" >&2
        echo "This would recursively delete files and directories." >&2
        exit 2
    fi
    if echo "$COMMAND" | grep -qP 'rm\s+.*\*'; then
        echo "BLOCKED [Safety]: $COMMAND" >&2
        echo "This would delete files matching a wildcard." >&2
        exit 2
    fi
    if echo "$COMMAND" | grep -qP 'git\s+reset\s+--hard'; then
        echo "BLOCKED [Safety]: $COMMAND" >&2
        echo "This would discard all uncommitted changes." >&2
        exit 2
    fi
    if echo "$COMMAND" | grep -qP 'git\s+checkout\s+\.'; then
        echo "BLOCKED [Safety]: $COMMAND" >&2
        echo "This would discard all unstaged changes." >&2
        exit 2
    fi
    if echo "$COMMAND" | grep -qP 'git\s+clean\s+-[fd]'; then
        echo "BLOCKED [Safety]: $COMMAND" >&2
        echo "This would delete untracked files." >&2
        exit 2
    fi

    # Hook #7: Branch Protection
    if echo "$COMMAND" | grep -qP 'git\s+push\s+.*--force'; then
        echo "BLOCKED [Git]: Force push is not allowed." >&2
        exit 2
    fi
    if echo "$COMMAND" | grep -qP 'git\s+push\s+\S+\s+(main|master)\b'; then
        echo "BLOCKED [Git]: Direct push to main/master is not allowed." >&2
        exit 2
    fi

    # Hook #6: Uncommitted Work Guard
    check_uncommitted() {
        if [ -n "$CWD" ] && [ -d "$CWD" ]; then
            local status
            status=$(git -C "$CWD" status --porcelain 2>/dev/null || true)
            if [ -n "$status" ]; then
                local count
                count=$(echo "$status" | grep -c '.' || true)
                echo "BLOCKED [Safety]: $COMMAND — you have $count uncommitted file(s)." >&2
                exit 2
            fi
        fi
    }
    if echo "$COMMAND" | grep -qP 'git\s+reset\s+--hard'; then check_uncommitted; fi
    if echo "$COMMAND" | grep -qP 'git\s+checkout\s+[a-zA-Z]'; then check_uncommitted; fi
    if echo "$COMMAND" | grep -qP 'git\s+stash\s+drop'; then check_uncommitted; fi
    if echo "$COMMAND" | grep -qP 'git\s+stash\s+clear'; then check_uncommitted; fi
    if echo "$COMMAND" | grep -qP 'git\s+restore\s+\.'; then check_uncommitted; fi

    # Hook #11: Dangerous Interpreter Guard
    for pattern in 'python3?\s+-c\s+' 'node\s+-e\s+' 'ruby\s+-e\s+' 'perl\s+-e\s+'; do
        if echo "$COMMAND" | grep -qP "$pattern"; then
            INLINE=$(echo "$COMMAND" | sed -E "s/^.*$pattern//")
            LEN=${#INLINE}
            if [ "$LEN" -ge 80 ]; then
                echo "BLOCKED [Control]: Long inline script ($LEN chars). Write to a file first." >&2
                exit 2
            fi
        fi
    done

    # Hook #12 (Bash part): Test File Deletion Guard
    if echo "$COMMAND" | grep -qP '\b(rm|del)\b'; then
        for tp in 'test_.*\.py' '.*\.spec\.(ts|js)' '.*\.test\.(ts|js|tsx|jsx)' '.*_test\.go' 'conftest\.py'; do
            if echo "$COMMAND" | grep -qP "$tp"; then
                echo "BLOCKED [Control]: Cannot delete test files. Fix them, don't delete them." >&2
                exit 2
            fi
        done
    fi
fi

# === WRITE TOOL CHECKS ===
if [ "$TOOL_NAME" = "Write" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")
    [ -z "$FILE_PATH" ] && exit 0

    FILE_NAME=$(basename "$FILE_PATH")
    FULL_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

    # Hook #2: Critical File Guard
    for cp in '\.env$' '\.env\..+$' 'docker-compose\.ya?ml$' 'Dockerfile$' '\.github/workflows/.+$' 'Jenkinsfile$' 'azure-pipelines\.ya?ml$' '\.claude/settings\.json$' '\.config\.(js|ts|mjs)$'; do
        if echo "$FULL_PATH" | grep -qP "$cp"; then
            echo "BLOCKED [Safety]: Critical file $FILE_NAME — tell Claude exactly what to change." >&2
            exit 2
        fi
    done

    # Hook #3: Large File Overwrite Guard
    if [ -f "$FILE_PATH" ]; then
        LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
        if [ "$LINE_COUNT" -ge 300 ]; then
            echo "BLOCKED [Safety]: $FILE_NAME has $LINE_COUNT lines. Use Edit instead of rewriting." >&2
            exit 2
        fi
    fi

    # Hook #4: Scope Boundary Guard
    if [ -n "$CWD" ]; then
        RESOLVED=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
        RESOLVED_CWD=$(realpath "$CWD" 2>/dev/null || echo "$CWD")
        case "$RESOLVED" in
            "$RESOLVED_CWD"*) ;;  # inside project, OK
            *)
                echo "BLOCKED [Safety]: File outside project: $RESOLVED" >&2
                exit 2
                ;;
        esac
    fi

    # Hook #5: Secret Scanner
    CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('content',''))" 2>/dev/null || true)
    if [ -n "$CONTENT" ]; then
        if echo "$CONTENT" | grep -qP 'AKIA[0-9A-Z]{16}'; then
            echo "BLOCKED [Safety]: Potential AWS Key detected in content." >&2; exit 2
        fi
        if echo "$CONTENT" | grep -qP '-----BEGIN\s+(RSA|DSA|EC|OPENSSH)?\s*PRIVATE KEY-----'; then
            echo "BLOCKED [Safety]: Potential Private Key detected in content." >&2; exit 2
        fi
        if echo "$CONTENT" | grep -qP 'ghp_[A-Za-z0-9_]{36}'; then
            echo "BLOCKED [Safety]: Potential GitHub Token detected in content." >&2; exit 2
        fi
        if echo "$CONTENT" | grep -qP 'sk-[A-Za-z0-9]{20,}'; then
            echo "BLOCKED [Safety]: Potential OpenAI Key detected in content." >&2; exit 2
        fi
        if echo "$CONTENT" | grep -qP 'xox[bprs]-[A-Za-z0-9\-]+'; then
            echo "BLOCKED [Safety]: Potential Slack Token detected in content." >&2; exit 2
        fi
        if echo "$CONTENT" | grep -qiP '(password|secret|token|api[_-]?key)\s*[:=]\s*["\x27]?[^\s"]{8,}'; then
            echo "BLOCKED [Safety]: Potential Generic Secret detected in content." >&2; exit 2
        fi
    fi

    # Hook #8: Dependency Change Guard
    case "$FILE_NAME" in
        package.json|package-lock.json|requirements.txt|Pipfile|Pipfile.lock|Gemfile|Gemfile.lock|go.mod|go.sum|pom.xml|build.gradle|Cargo.toml|Cargo.lock)
            echo "BLOCKED [Git]: Dependency file $FILE_NAME — review changes carefully." >&2
            exit 2
            ;;
    esac

    # Hook #12 (Write part): Test File Deletion Guard
    IS_TEST=false
    for tp in 'test_.*\.py$' '.*\.spec\.(ts|js)$' '.*\.test\.(ts|js|tsx|jsx)$' '.*_test\.go$' 'conftest\.py$'; do
        if echo "$FILE_NAME" | grep -qP "$tp"; then IS_TEST=true; break; fi
    done
    if [ "$IS_TEST" = true ] && [ -f "$FILE_PATH" ]; then
        EXISTING=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
        NEW_LINES=$(echo "$INPUT" | python3 -c "import sys,json; c=json.load(sys.stdin).get('tool_input',{}).get('content',''); print(len(c.split(chr(10))))")
        if [ "$EXISTING" -gt 10 ]; then
            THRESHOLD=$((EXISTING / 2))
            if [ "$NEW_LINES" -lt "$THRESHOLD" ]; then
                echo "BLOCKED [Control]: Test file $FILE_NAME would shrink from $EXISTING to $NEW_LINES lines." >&2
                exit 2
            fi
        fi
    fi
fi

# === EDIT TOOL CHECKS ===
if [ "$TOOL_NAME" = "Edit" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")
    [ -z "$FILE_PATH" ] && exit 0

    FILE_NAME=$(basename "$FILE_PATH")
    FULL_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

    # Hook #2: Critical File Guard (also applies to Edit)
    for cp in '\.env$' '\.env\..+$' 'docker-compose\.ya?ml$' 'Dockerfile$' '\.github/workflows/.+$' 'Jenkinsfile$' 'azure-pipelines\.ya?ml$' '\.claude/settings\.json$' '\.config\.(js|ts|mjs)$'; do
        if echo "$FULL_PATH" | grep -qP "$cp"; then
            echo "BLOCKED [Safety]: Critical file $FILE_NAME — tell Claude exactly what to change." >&2
            exit 2
        fi
    done

    # Hook #4: Scope Boundary Guard (also applies to Edit)
    if [ -n "$CWD" ]; then
        RESOLVED=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
        RESOLVED_CWD=$(realpath "$CWD" 2>/dev/null || echo "$CWD")
        case "$RESOLVED" in
            "$RESOLVED_CWD"*) ;;
            *)
                echo "BLOCKED [Safety]: File outside project: $RESOLVED" >&2
                exit 2
                ;;
        esac
    fi

    # Hook #8: Dependency Change Guard (also applies to Edit)
    case "$FILE_NAME" in
        package.json|package-lock.json|requirements.txt|Pipfile|Pipfile.lock|Gemfile|Gemfile.lock|go.mod|go.sum|pom.xml|build.gradle|Cargo.toml|Cargo.lock)
            echo "BLOCKED [Git]: Dependency file $FILE_NAME — review changes carefully." >&2
            exit 2
            ;;
    esac
fi

exit 0
