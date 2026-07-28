#!/usr/bin/env bash
set -euo pipefail

# ==============================================
# Script: git-push-branch.sh
# What it does:
#   1. Checkout/create a target branch (name entered by user)
#      - If left empty, stays on the current branch
#   2. Add, commit (with a message typed by the user)
#   3. Push to that branch (auto set upstream with -u)
# ==============================================

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

read -rp "Enter target branch name (leave empty to use current branch '${CURRENT_BRANCH}'): " TARGET_BRANCH

if [[ -z "${TARGET_BRANCH}" ]]; then
  TARGET_BRANCH="${CURRENT_BRANCH}"
  echo "==> No branch name entered, staying on current branch '${TARGET_BRANCH}'."
else
  echo "==> Checking out '${TARGET_BRANCH}' branch..."
  if git show-ref --verify --quiet "refs/heads/${TARGET_BRANCH}"; then
    git checkout "${TARGET_BRANCH}"
  else
    echo "Branch '${TARGET_BRANCH}' doesn't exist yet, creating it..."
    git checkout -b "${TARGET_BRANCH}"
  fi
fi

# Check if there are any changes to commit
if [[ -n "$(git status --porcelain)" ]]; then
  echo "==> Staging all changes (git add .)..."
  git add .

  read -rp "Enter commit message: " COMMIT_MSG
  if [[ -z "${COMMIT_MSG}" ]]; then
    echo "Commit message cannot be empty. Aborting."
    exit 1
  fi

  echo "==> Committing changes..."
  git commit -m "${COMMIT_MSG}"
else
  echo "No changes to commit."
fi

echo "==> Pushing to origin/${TARGET_BRANCH} (with upstream tracking)..."
git push -u origin "${TARGET_BRANCH}"

echo "==> Done! Changes have been pushed to the '${TARGET_BRANCH}' branch."
