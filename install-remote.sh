#!/bin/bash
# =========================================================================
# zeromd one-liner installer
# =========================================================================
# Usage:
#   bash <(curl -sL https://raw.githubusercontent.com/anthropics/zeromd/main/install-remote.sh)
#
# This script:
#   1. Clones zeromd to ~/.zeromd/zeromd (via HTTPS, no SSH needed)
#   2. Runs scripts/setup.sh (which handles everything else)
#   3. On re-run: pulls latest updates, then runs setup again
# =========================================================================

set -euo pipefail

ZEROMD_HOME="$HOME/.zeromd"
ZEROMD_REPO="$ZEROMD_HOME/zeromd"
REPO_URL="https://github.com/yuukiLike/zeromd.git"

echo "zeromd installer"
echo ""

# Ensure git is available
if ! command -v git &>/dev/null; then
    echo "ERROR: git not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

mkdir -p "$ZEROMD_HOME"

if [ -d "$ZEROMD_REPO/.git" ]; then
    # Already cloned — pull latest
    echo "Updating zeromd..."
    git -C "$ZEROMD_REPO" pull --quiet 2>/dev/null || true
else
    # Fresh clone via HTTPS (no SSH key needed for public repo)
    echo "Downloading zeromd..."
    git clone --quiet "$REPO_URL" "$ZEROMD_REPO"
fi

echo ""
exec bash "$ZEROMD_REPO/scripts/setup.sh" "$@"
