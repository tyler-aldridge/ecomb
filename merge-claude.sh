#!/bin/bash

# Merge script for Claude Code branches
# Usage: ./merge-claude.sh

set -e

BRANCH_NAME="claude/optimize-godot-prototype-011CURQh5Jnuij8LBS6J8y1N"

echo "======================================"
echo "Merging $BRANCH_NAME into main"
echo "======================================"

# Stash any uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Stashing uncommitted changes..."
    git stash
    STASHED=true
else
    STASHED=false
fi

# Switch to main and pull latest
echo "Switching to main branch..."
git checkout main

echo "Pulling latest changes..."
git pull origin main

# Merge the Claude branch
echo "Merging $BRANCH_NAME..."
git merge "$BRANCH_NAME" --no-ff -m "Merge $BRANCH_NAME - Data-driven level system"

# Pop stashed changes if any
if [ "$STASHED" = true ]; then
    echo "Restoring stashed changes..."
    git stash pop
fi

echo "======================================"
echo "Merge complete!"
echo "You are now on main branch with the changes merged."
echo "Test the game, then run: git push origin main"
echo "======================================"
