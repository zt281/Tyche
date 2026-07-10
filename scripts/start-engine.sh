#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-cpp}"
BASE_PORT="${2:-7700}"

echo "=== Tyche Engine Startup ==="
echo "Mode: $MODE"
echo "Base Port: $BASE_PORT"
echo "Repo Root: $REPO_ROOT"

case "$MODE" in
    cpp)
        ENGINE="$REPO_ROOT/core/cpp/build/tyche_engine"
        if [ ! -f "$ENGINE" ]; then
            echo "Error: C++ engine not found. Build it first:"
            echo "  cd core/cpp && cmake -B build && cmake --build build"
            exit 1
        fi
        echo "Starting C++ Engine..."
        "$ENGINE" --config "$REPO_ROOT/config/tyche_engine.json" --base-port "$BASE_PORT"
        ;;
    python)
        echo "Starting Python Engine..."
        python -m tyche.engine_main --base-port "$BASE_PORT"
        ;;
    *)
        echo "Usage: $0 [cpp|python] [base_port]"
        exit 1
        ;;
esac
