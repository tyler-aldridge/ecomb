#!/bin/bash

# Quick update script - downloads all changed files from Claude branch
# Usage: bash update-from-claude.sh   (if not executable yet)
#        ./update-from-claude.sh      (once executable)
#
# Scalability features:
# - Works with ANY file type (text, binary, .gd, .json, .png, .ogg, .tscn, etc.)
# - Handles files in any directory depth
# - Supports filenames with spaces and special characters
# - Uses byte-by-byte comparison (works for binary and text files)
# - Automatically creates nested directories as needed
# - Auto-restores executable permission on itself after updates

# Make sure this script is executable (in case it lost permission)
if [ ! -x "$0" ]; then
    echo "Making script executable..."
    chmod +x "$0"
    echo "✓ Script is now executable. Run it again: $0"
    exit 0
fi

BRANCH="claude/optimize-godot-prototype-011CURQh5Jnuij8LBS6J8y1N"
REPO="tyler-aldridge/ecomb"

echo "Checking for updates from Claude branch..."

# Fetch the branch to get latest changes
git fetch origin "$BRANCH" 2>/dev/null

# Get list of all files in the Claude branch that differ from origin/main
# (these are the files Claude has been working on)
# Using --null and read -d to handle filenames with spaces/special chars
updated_count=0
skipped_count=0
failed_count=0

# Read files one per line, properly handling spaces and special characters
while IFS= read -r file; do
    [ -z "$file" ] && continue

    # Skip deleted files
    if ! git ls-tree -r "origin/$BRANCH" --name-only | grep -Fxq "$file"; then
        continue
    fi

    url="https://raw.githubusercontent.com/$REPO/$BRANCH/$file"

    # Create directory if it doesn't exist
    dir=$(dirname "$file")
    mkdir -p "$dir"

    # Download to temp file with unique name
    temp_file="${file}.tmp.$$"
    if curl -sf "$url" -o "$temp_file" 2>/dev/null; then
        # Check if local file exists and is identical (works for binary and text)
        if [ -f "$file" ] && cmp -s "$file" "$temp_file" 2>/dev/null; then
            # Files are identical
            rm "$temp_file"
            ((skipped_count++))
        else
            # File is different or doesn't exist - update it
            mv "$temp_file" "$file"

            # If we just updated this script, restore executable permission
            if [ "$file" = "update-from-claude.sh" ]; then
                chmod +x "$file"
            fi

            echo "✓ Updated $file"
            ((updated_count++))
        fi
    else
        # Download failed
        rm -f "$temp_file"
        echo "✗ Failed to download $file"
        ((failed_count++))
    fi
done < <(git diff --name-only "origin/main...origin/$BRANCH" 2>/dev/null)

# Report results
echo ""
if [ $updated_count -eq 0 ]; then
    if [ $failed_count -eq 0 ]; then
        if [ $skipped_count -eq 0 ]; then
            echo "✓ No files to check"
        else
            echo "✓ Everything is up to date! ($skipped_count files checked)"
        fi
    else
        echo "⚠ No files updated, but $failed_count file(s) failed to download"
    fi
else
    echo "✓ Updated $updated_count file(s)! Close and reopen Godot to test."
    if [ $skipped_count -gt 0 ]; then
        echo "  ($skipped_count files were already up to date)"
    fi
fi

if [ $failed_count -gt 0 ]; then
    echo "⚠ Warning: $failed_count file(s) failed to download"
    exit 1
fi
