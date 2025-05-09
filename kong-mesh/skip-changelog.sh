#!/bin/bash

# set -x
GREEN='\033[1;92m'
YELLOW='\033[0;93m'
NC='\033[0m' # No Color


PR=$1

PR_JSON=$(gh pr view $PR --json 'number,state,title,body,files' || echo '{}')
STATE=$(echo -n "$PR_JSON" | jq -r '.state //empty')
TITLE=$(echo -n "$PR_JSON" | jq -r '.title //empty')

if [[ "$STATE" != "MERGED" ]]; then
    >&2 printf "${YELLOW}[Changelog] PR $PR is not merged${NC}\n"
    exit 1
fi

NON_WF_CHANGES=$(echo -n "$PR_JSON" | jq -r '.files[] | select(.path | startswith(".github/workflows/") | not) //empty')
IS_ACTION_BUMP=1
if [[ "$TITLE" != "chore(deps):"* ]]; then
    IS_ACTION_BUMP=0
fi
if [[ ! -z "$NON_WF_CHANGES" ]]; then
    IS_ACTION_BUMP=0
fi

if [[ "$IS_ACTION_BUMP" == "0" ]]; then
    >&2 printf "${YELLOW}[Changelog] PR $PR is not bumping versions for actions${NC}\n"
    exit 1
fi

function get_change_log() {
  awk '
    BEGIN { in_comment = 0; changelog = "" }
    
    # Process each line of input
    {
      if (match($0, /<!--/)) {
        in_comment = 1
      }
      if (in_comment && match($0, /-->/)) {
        in_comment = 0
      }
      if (!in_comment && match($0, /^> Changelog: /)) {
        changelog = $0
      }
    }
    
    # After processing all lines, print the changelog
    END { print changelog }
  ' <<< "$1"
}

EXISTING_BODY=$(gh pr view $PR --json 'body' -q '.body' || echo '')
CHANGE_LOG=$(get_change_log "$EXISTING_BODY" | sed 's/\r$//' | awk '{print $3}')

if [[ "$CHANGE_LOG" == "skip" ]]; then
    printf "${GREEN}[Changelog] PR $PR is already skipped${NC}\n"
    exit 0
elif [[ "$CHANGE_LOG" != "" ]]; then
    printf "${YELLOW}[Changelog] Skipping PR $PR which has custom changelog: \n    $CHANGE_LOG ${NC}\n"
    exit 0
fi

PR_BODY=$(cat <<EOF
${EXISTING_BODY}

> Changelog: skip

EOF
)

gh pr edit $PR --body "$PR_BODY"
# echo gh pr edit $PR --body "$PR_BODY"
printf "${GREEN}[Changelog] PR $PR has been marked as skip${NC}\n"

