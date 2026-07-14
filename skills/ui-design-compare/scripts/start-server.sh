#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR=""
BIND_HOST="127.0.0.1"
URL_HOST=""
IDLE_TIMEOUT_MINUTES="240"
OPEN_BROWSER="false"
FOREGROUND="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --host)
            BIND_HOST="$2"
            shift 2
            ;;
        --url-host)
            URL_HOST="$2"
            shift 2
            ;;
        --idle-timeout-minutes)
            IDLE_TIMEOUT_MINUTES="$2"
            shift 2
            ;;
        --open)
            OPEN_BROWSER="true"
            shift
            ;;
        --foreground)
            FOREGROUND="true"
            shift
            ;;
        *)
            printf '{"error":"unknown argument: %s"}\n' "$1"
            exit 1
            ;;
    esac
done

if ! command -v node >/dev/null 2>&1; then
    printf '{"error":"node is required"}\n'
    exit 1
fi

if ! [[ "$IDLE_TIMEOUT_MINUTES" =~ ^[0-9]+$ ]] || [[ "$IDLE_TIMEOUT_MINUTES" -lt 1 ]]; then
    printf '{"error":"--idle-timeout-minutes must be a positive integer"}\n'
    exit 1
fi

if [[ -z "$URL_HOST" ]]; then
    if [[ "$BIND_HOST" == "127.0.0.1" || "$BIND_HOST" == "localhost" ]]; then
        URL_HOST="localhost"
    else
        URL_HOST="$BIND_HOST"
    fi
fi

umask 077
SESSION_ID="$$-$(date +%s)"
if [[ -n "$PROJECT_DIR" ]]; then
    SESSION_DIR="${PROJECT_DIR}/.ui-design-compare/${SESSION_ID}"
else
    SESSION_DIR="/tmp/ui-design-compare-${SESSION_ID}"
fi

mkdir -p "${SESSION_DIR}/content" "${SESSION_DIR}/state"

SERVER_ID=""
if [[ -r /dev/urandom ]]; then
    SERVER_ID="$(od -An -N24 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"
fi
if ! [[ "$SERVER_ID" =~ ^[A-Fa-f0-9]{48}$ ]]; then
    SERVER_ID="$(printf '%08x%08x%08x%08x' "$$" "$(date +%s)" "${RANDOM:-0}" "${RANDOM:-0}")"
fi
printf '%s\n' "$SERVER_ID" > "${SESSION_DIR}/state/server-instance-id"

export UI_COMPARE_DIR="$SESSION_DIR"
export UI_COMPARE_HOST="$BIND_HOST"
export UI_COMPARE_URL_HOST="$URL_HOST"
export UI_COMPARE_IDLE_TIMEOUT_MS="$((IDLE_TIMEOUT_MINUTES * 60 * 1000))"
export UI_COMPARE_OPEN="$OPEN_BROWSER"

SERVER_COMMAND=(node "$SCRIPT_DIR/server.js" "--ui-compare-server-id=$SERVER_ID")

if [[ "$FOREGROUND" == "true" ]]; then
    exec env "${SERVER_COMMAND[@]}"
fi

LOG_FILE="${SESSION_DIR}/state/server.log"
nohup env "${SERVER_COMMAND[@]}" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!
printf '%s\n' "$SERVER_PID" > "${SESSION_DIR}/state/server.pid"

for _ in {1..50}; do
    if [[ -s "${SESSION_DIR}/state/server-info" ]]; then
        cat "${SESSION_DIR}/state/server-info"
        exit 0
    fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        cat "$LOG_FILE" >&2
        exit 1
    fi
    sleep 0.1
done

printf '{"error":"server failed to start within 5 seconds"}\n'
exit 1
