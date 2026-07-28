#!/usr/bin/env bash
set -euo pipefail

# ==============================================
# Script: git-sync-inout.sh
# What it does:
#   1. Checkout to "main" branch & pull latest changes
#   2. Checkout/create a target branch (name entered by user)
#   3. (Optional) merge latest changes from main into that branch
#   4. Add, commit (with a message typed by the user), then push to the target branch
# ==============================================

MAIN_BRANCH="main"

echo "==> Checking out '${MAIN_BRANCH}' branch..."
git checkout "${MAIN_BRANCH}"

echo "==> Pulling latest '${MAIN_BRANCH}' from origin..."
git pull origin "${MAIN_BRANCH}"

read -rp "Enter target branch name (e.g. inout): " TARGET_BRANCH
if [[ -z "${TARGET_BRANCH}" ]]; then
  echo "Branch name cannot be empty. Aborting."
  exit 1
fi

echo "==> Checking out '${TARGET_BRANCH}' branch..."
if git show-ref --verify --quiet "refs/heads/${TARGET_BRANCH}"; then
  git checkout "${TARGET_BRANCH}"
else
  echo "Branch '${TARGET_BRANCH}' doesn't exist yet, creating it from ${MAIN_BRANCH}..."
  git checkout -b "${TARGET_BRANCH}"
fi

# Optional: sync target branch with main before pushing
read -rp "Merge latest changes from '${MAIN_BRANCH}' into '${TARGET_BRANCH}'? (y/n): " DO_MERGE
if [[ "${DO_MERGE}" =~ ^[Yy]$ ]]; then
  echo "==> Merging '${MAIN_BRANCH}' into '${TARGET_BRANCH}'..."
  git merge "${MAIN_BRANCH}"
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

echo "==> Pushing to origin/${TARGET_BRANCH}..."
git push origin "${TARGET_BRANCH}"

echo "==> Done! Changes have been pushed to the '${TARGET_BRANCH}' branch."
