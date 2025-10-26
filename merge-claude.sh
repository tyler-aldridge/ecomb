#!/bin/bash

# One-command merge script for Claude Code branches
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

# Switch to main
echo "Switching to main branch..."
git checkout main 2>/dev/null || echo "Already on main"

# Fetch latest from remote
echo "Fetching latest changes..."
git fetch origin

# Pull latest from main
echo "Updating main branch..."
git pull origin main --no-rebase 2>/dev/null || echo "Main already up to date"

# Merge the Claude branch with all latest changes from remote
echo "Merging origin/$BRANCH_NAME..."
git merge "origin/$BRANCH_NAME" --no-ff -m "Merge $BRANCH_NAME - Data-driven level system"

# Pop stashed changes if any
if [ "$STASHED" = true ]; then
    echo "Restoring stashed changes..."
    git stash pop
fi

echo ""
echo "======================================"
echo "✅ Merge complete!"
echo "======================================"
echo "You are now on main with all changes merged."
echo ""
echo "Next steps:"
echo "1. Test the game in Godot"
echo "2. If everything works: git push origin main"
echo "======================================"
