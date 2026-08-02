#!/usr/bin/env bash
set -euo pipefail

# ==============================================
# Script: git-pull-main.sh
# What it does:
#   1. Checkout to "main" branch
#   2. Pull latest changes from origin
# ==============================================

MAIN_BRANCH="main"

echo "==> Checking out '${MAIN_BRANCH}' branch..."
git checkout "${MAIN_BRANCH}"

echo "==> Pulling latest '${MAIN_BRANCH}' from origin..."
git pull origin "${MAIN_BRANCH}"

echo "==> Done! '${MAIN_BRANCH}' is up to date."
