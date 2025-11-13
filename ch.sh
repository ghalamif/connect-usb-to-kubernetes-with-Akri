#!/usr/bin/env bash
set -euo pipefail

COUNT=16
echo "==== FULL PR FARM STARTED ===="
echo "Repo: $(basename $(pwd))"
sleep 2

# ------------------------------------------------------------
# Cleanup old/broken branches
# ------------------------------------------------------------

echo "Cleaning up broken branches..."

for b in pr-farm- pr-farm-1 pr-farm-2; do
  if git show-ref --verify --quiet refs/heads/$b; then
    git branch -D "$b" || true
  fi
  if git ls-remote --exit-code --heads origin $b >/dev/null 2>&1; then
    git push origin --delete "$b" || true
  fi
done

echo "Cleanup done."
sleep 1

# ------------------------------------------------------------
# Create realistic file structure
# ------------------------------------------------------------

mkdir -p docs scripts config

FILES=(
  "README.md"
  "LICENSE"
  ".gitignore"
  "docs/overview.md"
  "docs/setup.md"
  "scripts/helper.sh"
  "config/default.cfg"
)

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "Placeholder for $f" > "$f"
  fi
done

CHANGES=(
  "Fix typo"
  "Improve formatting"
  "Add clarification"
  "Update docs"
  "Refine comment"
  "Whitespace cleanup"
  "Minor tweak"
  "Grammar improvement"
  "Add newline"
  "Small refactor"
)

echo "Realistic files prepared."
sleep 1

# ------------------------------------------------------------
# Generate branches + commits + push
# ------------------------------------------------------------

echo "Creating and pushing $COUNT branches..."

for i in $(seq 1 $COUNT); do
  BRANCH="pr-farm-$i"
  FILE=${FILES[$RANDOM % ${#FILES[@]}]}
  CHANGE=${CHANGES[$RANDOM % ${#CHANGES[@]}]}

  git checkout main
  git pull origin main
  git checkout -b "$BRANCH"

  echo "$CHANGE ($i)" >> "$FILE"

  git add "$FILE"
  git commit -m "$CHANGE in $FILE (#$i)"
  git push origin "$BRANCH"

  echo "✓ Branch '$BRANCH' pushed. Waiting 5 seconds..."
  sleep 5
done

echo "All branches created and pushed."
sleep 2

# ------------------------------------------------------------
# Open PRs
# ------------------------------------------------------------

echo "Creating PRs via GitHub CLI..."

for i in $(seq 1 $COUNT); do
  BRANCH="pr-farm-$i"

  gh pr create \
    --base main \
    --head "$BRANCH" \
    --title "PR farm $i" \
    --body "Automated realistic update $i"

  echo "✓ PR for '$BRANCH' created. Waiting 3 seconds..."
  sleep 3
done

echo "All PRs created."
sleep 2

# ------------------------------------------------------------
# Merge PRs
# ------------------------------------------------------------

echo "Merging PRs..."

for i in $(seq 1 $COUNT); do
  BRANCH="pr-farm-$i"
  gh pr merge "$BRANCH" --merge --delete-branch
  echo "✓ Merged '$BRANCH'"
  sleep 2
done

echo ""
echo "==== ALL PRs MERGED SUCCESSFULLY ===="
echo "You should now receive Pull Shark (Silver) 🦈"
echo "======================================"
