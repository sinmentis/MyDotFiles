#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
    printf '{"error":"usage: stop-server.sh <session_dir>"}\n'
    exit 1
fi

SESSION_DIR="$1"
STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"
SERVER_ID_FILE="${STATE_DIR}/server-instance-id"

if [[ ! -f "$PID_FILE" ]]; then
    printf '{"status":"not_running"}\n'
    exit 0
fi

PID="$(tr -d '\r\n' <"$PID_FILE")"
SERVER_ID="$(tr -d '\r\n' <"$SERVER_ID_FILE" 2>/dev/null || true)"
EXPECTED_ARG="--ui-compare-server-id=${SERVER_ID}"

if ! [[ "$PID" =~ ^[0-9]+$ ]] || [[ -z "$SERVER_ID" ]] || ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$PID_FILE"
    printf '{"status":"stale_pid"}\n'
    exit 0
fi

if [[ -r "/proc/${PID}/cmdline" ]]; then
    if ! tr '\0' '\n' <"/proc/${PID}/cmdline" | grep -Fxq -- "$EXPECTED_ARG"; then
        rm -f "$PID_FILE"
        printf '{"status":"stale_pid"}\n'
        exit 0
    fi
fi

kill "$PID"
for _ in {1..30}; do
    if ! kill -0 "$PID" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID"
fi

rm -f "$PID_FILE"
printf '{"status":"stopped"}\n'
