#!/usr/bin/env bash

# create_loki_rule.sh
# Generate a Grafana Loki alert rule YAML file for Loki rule manager.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -n NAME            Alert name (required)
  -e EXPR            Loki query expression (required)
  -f DURATION        Duration for alert to remain firing before alerting, e.g. 5m (default: 1m)
  -g GROUP           Rule group name (default: loki-alerts)
  -o OUTPUT          Output file path (default: loki-rule.yaml)
  -l LABELS          Labels in key=value format, separated by commas
  -a ANNOTATIONS     Annotations in key=value format, separated by commas
  -s SUMMARY         Short summary annotation
  -d DESCRIPTION     Longer description annotation
  -h                Show this help message

Example:
  $0 -n HighErrorRate -e 'sum(rate({job="myjob"} |= "error"[5m])) > 0' -f 5m \
    -l severity=critical,team=backend \
    -a runbook="https://example.com/runbook" \
    -s "High error rate" -d "A high error rate has been detected."
EOF
}

if [[ ${#@} -eq 0 ]]; then
  usage
  exit 1
fi

RULE_NAME=""
EXPR=""
DURATION="1m"
GROUP_NAME="loki-alerts"
OUTPUT_FILE="loki-rule.yaml"
LABELS=""
ANNOTATIONS=""
SUMMARY=""
DESCRIPTION=""

while getopts ":n:e:f:g:o:l:a:s:d:h" opt; do
  case ${opt} in
    n) RULE_NAME=${OPTARG} ;;
    e) EXPR=${OPTARG} ;;
    f) DURATION=${OPTARG} ;;
    g) GROUP_NAME=${OPTARG} ;;
    o) OUTPUT_FILE=${OPTARG} ;;
    l) LABELS=${OPTARG} ;;
    a) ANNOTATIONS=${OPTARG} ;;
    s) SUMMARY=${OPTARG} ;;
    d) DESCRIPTION=${OPTARG} ;;
    h) usage; exit 0 ;;
    :) echo "Error: Option -${OPTARG} requires an argument." >&2; usage; exit 1 ;;
    \?) echo "Error: Invalid option -${OPTARG}" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$RULE_NAME" || -z "$EXPR" ]]; then
  echo "Error: -n and -e are required." >&2
  usage
  exit 1
fi

render_kv_block() {
  local raw="$1"
  local prefix="$2"
  if [[ -n "$raw" ]]; then
    IFS="," read -r -a pairs <<< "$raw"
    for pair in "${pairs[@]}"; do
      if [[ "$pair" =~ ^([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        printf "%s%s: \"%s\"\n" "$prefix" "$key" "${value//\"/\"\"}"
      else
        echo "Warning: skipping invalid key=value pair '$pair'" >&2
      fi
    done
  fi
}

mkdir -p "$(dirname "$OUTPUT_FILE")"

{
  echo "groups:"
  echo "- name: ${GROUP_NAME}"
  echo "  rules:"
  echo "  - alert: ${RULE_NAME}"
  echo "    expr: >"
  echo "      ${EXPR}"
  echo "    for: ${DURATION}"

  if [[ -n "$LABELS" || -n "$ANNOTATIONS" || -n "$SUMMARY" || -n "$DESCRIPTION" ]]; then
    if [[ -n "$LABELS" ]]; then
      echo "    labels:"
      render_kv_block "$LABELS" "      "
    fi

    if [[ -n "$ANNOTATIONS" || -n "$SUMMARY" || -n "$DESCRIPTION" ]]; then
      echo "    annotations:"
      if [[ -n "$SUMMARY" ]]; then
        echo "      summary: \"$SUMMARY\""
      fi
      if [[ -n "$DESCRIPTION" ]]; then
        echo "      description: \"$DESCRIPTION\""
      fi
      render_kv_block "$ANNOTATIONS" "      "
    fi
  fi
} > "$OUTPUT_FILE"

echo "Generated Loki rule file: $OUTPUT_FILE"
