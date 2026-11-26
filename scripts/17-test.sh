#!/bin/bash
# Runs the unit tests (works on macOS and Linux; the core logic is Foundation-only).
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
