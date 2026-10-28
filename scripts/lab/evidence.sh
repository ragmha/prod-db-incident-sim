#!/usr/bin/env bash
# Produces the evidence that CI publishes for the exercise coach: a restore
# drill, the incident replay, and the agent tool-call replay, run in that order
# against a fresh lab.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

export LAB_NONINTERACTIVE=1
export LAB_EVIDENCE_DIR="${LAB_EVIDENCE_DIR:-$LAB_DIR/evidence}"
mkdir -p "$LAB_EVIDENCE_DIR"

bash "$LAB_ROOT/scripts/lab/setup.sh"
bash "$LAB_ROOT/scripts/lab/drill.sh"
bash "$LAB_ROOT/scripts/lab/replay-incident.sh"
node "$LAB_ROOT/scripts/replay-agent.mjs" --json "$LAB_EVIDENCE_DIR/agent-replay.json"
node "$LAB_ROOT/scripts/lab/evidence.mjs" "$LAB_EVIDENCE_DIR"
