#!/usr/bin/env bash
# Produces the evidence that CI and the Release workflow publish for the exercise
# coach: a restore drill, the incident replay, and the agent tool-call replay.
# If the replay deletes production, production is restored afterwards so the
# lab stays usable.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

export LAB_NONINTERACTIVE=1
export LAB_EVIDENCE_DIR="${LAB_EVIDENCE_DIR:-$LAB_DIR/evidence}"
mkdir -p "$LAB_EVIDENCE_DIR"

bash "$LAB_ROOT/scripts/lab/setup.sh"
bash "$LAB_ROOT/scripts/lab/drill.sh"
bash "$LAB_ROOT/scripts/lab/replay-incident.sh"
node "$LAB_ROOT/scripts/replay-agent.mjs" --json "$LAB_EVIDENCE_DIR/agent-replay.json"
if [ "$(lab_count "$LAB_DATABASE" courses_answer)" -eq 0 ]; then
  lab_say "Restoring production after the replay"
  bash "$LAB_ROOT/scripts/lab/recover.sh" >/dev/null
  echo "Production restored."
fi
node "$LAB_ROOT/scripts/lab/evidence.mjs" "$LAB_EVIDENCE_DIR"
