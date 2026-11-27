#!/usr/bin/env bash
# Prepare a GrowWise worktree: check the tools the repo needs, then enable the codex-review gate.
# Rerunnable and noninteractive. It never installs tools, builds, runs tests (those run on
# mac-mini over SSH), touches credentials, changes branches, or pulls or pushes.
#
# git-lfs is required because the repo tracks images through Git LFS: without it a checkout
# holds pointer files instead of the assets.
set -euo pipefail

fail() {
  printf 'setup-worktree: %s\n' "$*" >&2
  exit 1
}

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

missing_tools=()
for tool in swift swiftlint swiftformat git-lfs; do
  command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if [ "${#missing_tools[@]}" -gt 0 ]; then
  echo "Install the Xcode command line tools, then run: brew install swiftlint swiftformat git-lfs" >&2
  fail "missing required tools: ${missing_tools[*]}"
fi

# The automated codex-review gate must be active in every worktree. The shared script lives
# outside the repo; SKIP_REVIEW_GATE=1 skips it on hosts without Codex.
gate_script="$HOME/.claude/scripts/enable-review-gate.sh"
if [ "${SKIP_REVIEW_GATE:-0}" = 1 ]; then
  printf 'setup-worktree: skipping the codex-review gate (SKIP_REVIEW_GATE=1)\n'
elif [ -x "$gate_script" ]; then
  "$gate_script" "$repo_root"
else
  fail "missing $gate_script, which enables the codex-review gate; restore it or set SKIP_REVIEW_GATE=1 on a host without Codex"
fi

printf 'setup-worktree: ready. Next: swiftlint lint --strict --config .swiftlint.yml\n'
