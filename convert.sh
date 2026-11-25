#!/usr/bin/env bash
#
# convert.sh — converts NUnit3 result files to JUnit XML with
#              nunit3-to-junit.xslt and validates each result against
#              junit.xsd.
#
# Usage:   ./convert.sh [file.xml ...]
# Default: TestResult.xml nunit3-example.xml
#
# Silent on success apart from one status line per file; exits non-zero
# on the first validation failure.
#
# Requires: xsltproc (libxslt), xmllint (libxml2-utils)

set -euo pipefail
cd "$(dirname "$0")"

XSLT="nunit3-to-junit.xslt"
XSD="junit.xsd"

SOURCES=("$@")
if [[ ${#SOURCES[@]} -eq 0 ]]; then
  SOURCES=(TestResult.xml nunit3-example.xml)
fi

for source in "${SOURCES[@]}"; do
  [[ -f "$source" ]] || { echo "ERROR: missing source: $source" >&2; exit 1; }

  target="junit-${source%.xml}.xml"

  xsltproc "$XSLT" "$source" > "$target"

  if ! output=$(xmllint --noout --schema "$XSD" "$target" 2>&1); then
    echo "ERROR: $target is not junit.xsd valid:" >&2
    echo "$output" >&2
    exit 1
  fi

  # The schema accepts empty tokens, so check required values explicitly.
  empty=$(xmllint --xpath \
    'count(//testcase[not(string(@name)) or not(string(@classname))])' \
    "$target" 2>/dev/null || echo "?")
  if [[ "$empty" != "0" ]]; then
    echo "ERROR: $target has $empty testcases with empty name/classname" >&2
    exit 1
  fi

  echo "OK: $source -> $target (schema valid)"
done
