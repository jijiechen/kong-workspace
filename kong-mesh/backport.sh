#!/bin/bash

set -e
# set -x

PR=$1
TARGET_BRANCH=$2


REMOTE_UPSTREAM=origin
if [[ "$(git remote)" == *"upstream"* ]]; then
    REMOTE_UPSTREAM=upstream
fi

PR_JSON=$(gh pr view $PR --json 'number,title,mergedAt,state,mergeCommit' || echo '{}')
TITLE=$(echo -n "$PR_JSON" | jq -r '.title //empty')
STATE=$(echo -n "$PR_JSON" | jq -r '.state //empty')
COMMIT=$(echo -n "$PR_JSON" | jq -r '.mergeCommit.oid //empty')
if [[ "$STATE" != "MERGED" ]]; then
    >&2 echo "PR $PR is not merged"
    exit 1
fi


if [[ "$(git remote)" == *"upstream"* ]]; then
    REMOTE_UPSTREAM=upstream
fi

if git rev-parse --verify $TARGET_BRANCH; then
    git checkout $TARGET_BRANCH
    git pull $REMOTE_UPSTREAM $TARGET_BRANCH
else
    git checkout --track remotes/$REMOTE_UPSTREAM/$TARGET_BRANCH
fi

BACKPORT_BRANCH=backport-${PR}-to-${TARGET_BRANCH}
git checkout -b $BACKPORT_BRANCH

CONFLICTS=
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

if git cherry-pick $COMMIT --signoff -S; then
   echo "Cherry-picked without conflicts!"
else
    printf "${YELLOW}There are conflicts when cherry picking the commit,${NC}\n"
    printf "${YELLOW}A draft PR with all the conflicts will be created.${NC}\n"

DIFF_STATUS=$(git status)
CONFLICTS=$(cat <<EOF
:warning: :warning: :warning: Conflicts found when cherry-picking! :warning: :warning: :warning:
```
${DIFF_STATUS}
```
EOF
)

    git add .
    git -c core.editor=true cherry-pick --continue --signoff -S
fi

git push origin $BACKPORT_BRANCH -u


sleep 3
REPO_FULL_NAME=$(gh repo view --json 'name,owner' -t '{{ .owner.login }}/{{ .name }}')
echo "Creating new PR in repo $REPO_FULL_NAME"


PR_TITLE="$TITLE (backport of #${PR})"
PR_BODY=$(cat <<EOF
Manual cherry-pick of #${PR} to branch ${TARGET_BRANCH}

cherry-picked commit ${COMMIT}

${CONFLICTS}
EOF
)
PR_LABELS="$TARGET_BRANCH"
PR_DRAFT=
if  [[ ! -z "$CONFLICTS" ]]; then
    PR_DRAFT='--draft'
    PR_LABELS="${PR_LABELS},conflict"
fi

if [[ ! -z "$CONFLICTS" ]]; then
    printf "${YELLOW}Remember to fix the commit and change the PR to 'Ready for review'${NC}\n"
fi

echo gh pr create $PR_DRAFT --base $TARGET_BRANCH --head $BACKPORT_BRANCH  --title "$PR_TITLE" --label "$PR_LABELS" --body "$PR_BODY"


exit 0
gh pr create $PR_DRAFT \
 --base $TARGET_BRANCH --head $BACKPORT_BRANCH \
 --title "$PR_TITLE" --label "$PR_LABELS" \
 --body "$PR_BODY"