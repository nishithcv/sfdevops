#!/usr/bin/env bash

# Essentialy fails loudy
# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u),
# and ensure the script fails if any command in a pipeline fails (-o pipefail)
set -euo pipefail 

MANIFEST="$1"
PR_BODY_FILE="$2"

# 1️⃣ Get test classes from PR body
PR_CLASSES_RAW=$(grep -oP 'TestStart\[([^]]+)\]TestStop' "$PR_BODY_FILE" || echo "")
PR_CLASSES=${PR_CLASSES_RAW#TestStart[}
PR_CLASSES=${PR_CLASSES%]TestStop}
# Replace commas with spaces
PR_CLASSES="${PR_CLASSES//,/ }"

echo "🔍 PR body test classes: $PR_CLASSES"

# Initialize array of final classes
declare -a ALL_CLASSES=()
# Add PR classes
if [[ -n "$PR_CLASSES" ]]; then
  read -r -a pr_array <<< "$PR_CLASSES"
  ALL_CLASSES+=("${pr_array[@]}")
fi

# 2️⃣ Extract ApexClass members from package.xml
XML_CLASSES=$(xmlstarlet sel -N x="http://soap.sforce.com/2006/04/metadata" \
  -t -m "//x:types[x:name='ApexClass']/x:members" -v . -n "$MANIFEST" | tr '\n' ' ')
read -r -a xml_array <<< "$XML_CLASSES"

# 3️⃣ For each xml class not in PR, check if file contains @isTest
for cls in "${xml_array[@]}"; do
  # Skip if already in PR list
  if printf '%s\n' "${ALL_CLASSES[@]}" | grep -qx "$cls"; then
    continue
  fi

  clsfile="force-app/main/default/classes/${cls}.cls"
  if [[ -f "$clsfile" ]]; then
    if grep -Piq '^@isTest' "$clsfile"; then
      ALL_CLASSES+=("$cls")
    fi
  else
    echo "⚠️  Missing class file: $clsfile" >&2
  fi
done

# 4️⃣ Deduplicate while preserving order
# Use awk to filter unique
UNIQUE_CLASSES=$(printf "%s\n" "${ALL_CLASSES[@]}" | awk '!seen[$0]++' | tr '\n' ' ')
UNIQUE_CLASSES="${UNIQUE_CLASSES%" "}"

echo "✅ Combined test classes: $UNIQUE_CLASSES"
echo "TEST_CLASSES=$UNIQUE_CLASSES" >> "$GITHUB_OUTPUT"
