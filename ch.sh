#!/usr/bin/env bash
set -euo pipefail

COUNT=16

echo "Starting realistic PR farm with $COUNT PRs..."

# Ensure folders exist for realistic edits
mkdir -p docs
mkdir -p scripts
mkdir -p config

# Define candidate files (they will be touched randomly)
FILES=(
  "README.md"
  "LICENSE"
  ".gitignore"
  "docs/overview.md"
  "docs/setup.md"
  "scripts/helper.sh"
  "config/default.cfg"
)

# Create any missing files to make edits legal
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "Auto-generated placeholder for $f" > "$f"
  fi
done

# Possible realistic line edits
CHANGES=(
  "Fix minor typo"
  "Improve formatting"
  "Add small clarification"
  "Update documentation line"
  "Refine comment"
  "Whitespace cleanup"
  "Minor fix"
  "Tiny consistency tweak"
  "Grammar improvement"
  "Add missing newline"
)

for i in $(seq 1 $COUNT); do
    BRANCH="pr-farm-$i"

    git checkout main
    git pull origin main

    git checkout -b "$BRANCH"

    # Pick random file and random change
    FILE=${FILES[$RANDOM % ${#FILES[@]}]}
    CHANGE=${CHANGES[$RANDOM % ${#CHANGES[@]}]}

    echo "$CHANGE ($i)" >> "$FILE"

    git add "$FILE"
    git commit -m "$CHANGE in $FILE (#$i)"
    git push origin "$BRANCH"

    echo ">>> Created PR branch '$BRANCH': modified $FILE"
    echo ">>> Sleeping 5 seconds..."
    sleep 5
done

echo ""
echo "All realistic PR branches created!"
echo "Go to GitHub and merge them one by one."
