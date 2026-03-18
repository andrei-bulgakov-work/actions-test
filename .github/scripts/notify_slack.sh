#!/usr/bin/env bash

set -euo pipefail

# Send a Slack notification about a failed workflow
# Usage: ./notify-slack.sh <webhook_url> <workflow_name> <workflow_conclusion> <triggered_workflow_run_id> [pr_number] [branch_name]

if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <webhook_url> <workflow_name> <workflow_conclusion> <triggered_workflow_run_id> [pr_number] [branch_name]"
    exit 1
fi

WEBHOOK_URL="$1"
WORKFLOW_NAME="$2"
CONCLUSION="$3"
TRIGGERED_WORKFLOW_RUN_ID="$4"
PR_NUMBER="${5:-}"
BRANCH_NAME="${6:-}"

# Validate webhook URL
if [[ -z "$WEBHOOK_URL" ]]; then
    echo "Error: Webhook URL is empty"
    exit 1
fi

# Determine title and icon based on conclusion
case "${CONCLUSION,,}" in
failure)
    TITLE="Workflow failed: ${WORKFLOW_NAME}"
    ICON="❌"
    ;;
timed_out)
    TITLE="Workflow timed out: ${WORKFLOW_NAME}"
    ICON="⌛"
    ;;
cancelled)
    TITLE="Workflow cancelled: ${WORKFLOW_NAME}"
    ICON="🚫"
    ;;
*)
    TITLE="Workflow failed (${CONCLUSION}): ${WORKFLOW_NAME}"
    ICON="🔴"
    ;;
esac

# Extract repository name from GITHUB_REPOSITORY (format: owner/repo)
REPO_NAME="${GITHUB_REPOSITORY#*/}"
REPO_URL="https://github.com/${GITHUB_REPOSITORY}"

# Construct workflow run URL
# Format: https://github.com/{owner}/{repo}/actions/runs/{run_id}
WORKFLOW_RUN_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${TRIGGERED_WORKFLOW_RUN_ID}"
WORKFLOW_RUN_ID="$TRIGGERED_WORKFLOW_RUN_ID"

# Build the message text with repository and workflow run info
MESSAGE_TEXT="${ICON} *${TITLE}*\nRepository: <${REPO_URL}|${REPO_NAME}>\nWorkflow Run: <${WORKFLOW_RUN_URL}|${WORKFLOW_RUN_ID}>"

# Add PR or Branch information if available
if [[ -n "$PR_NUMBER" ]]; then
    PR_URL="https://github.com/${GITHUB_REPOSITORY}/pull/${PR_NUMBER}"
    MESSAGE_TEXT="${MESSAGE_TEXT}\nPull Request: <${PR_URL}|#${PR_NUMBER}>"
elif [[ -n "$BRANCH_NAME" ]]; then
    BRANCH_URL="https://github.com/${GITHUB_REPOSITORY}/tree/${BRANCH_NAME}"
    MESSAGE_TEXT="${MESSAGE_TEXT}\nBranch: <${BRANCH_URL}|${BRANCH_NAME}>"
fi

# Create Slack message payload with blocks
# Using mrkdwn format for markdown support
MESSAGE_PAYLOAD=$(
    cat <<EOF
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "${MESSAGE_TEXT}"
      }
    }
  ]
}
EOF
)

# Send the notification to Slack
HTTP_STATUS=$(curl \
    -w "\n%{http_code}" \
    -X POST \
    -H 'Content-type: application/json' \
    --data "$MESSAGE_PAYLOAD" \
    "$WEBHOOK_URL" \
    -s -o /tmp/slack_response.txt)

RESPONSE_CODE=$(echo "$HTTP_STATUS" | tail -1)
RESPONSE_BODY=$(cat /tmp/slack_response.txt)

if [[ "$RESPONSE_CODE" == "200" ]]; then
    echo "✓ Slack notification sent successfully"
    exit 0
else
    echo "✗ Failed to send Slack notification"
    echo "HTTP Status: $RESPONSE_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi
