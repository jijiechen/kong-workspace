#!/bin/bash

set -e
# set -x

PR=$1
TARGET_BRANCH=$2


GREEN='\033[1;92m'
YELLOW='\033[0;93m'
NC='\033[0m' # No Color

REMOTE_UPSTREAM=origin
if [[ "$(git remote)" == *"upstream"* ]]; then
    REMOTE_UPSTREAM=upstream
fi

PR_JSON=$(gh pr view $PR --json 'number,title,mergedAt,state,mergeCommit' || echo '{}')
TITLE=$(echo -n "$PR_JSON" | jq -r '.title //empty')
STATE=$(echo -n "$PR_JSON" | jq -r '.state //empty')
COMMIT=$(echo -n "$PR_JSON" | jq -r '.mergeCommit.oid //empty')
if [[ "$STATE" != "MERGED" ]]; then
    >&2 printf "${YELLOW}[Backport] PR $PR is not merged${NC}\n"
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

sleep 1
echo
echo
echo "[Backport] Cherry picking changes from commit $COMMIT"

if git cherry-pick $COMMIT --signoff -S >/dev/null 2>&1 ; then
   printf "${GREEN}[Backport] The operation completed without conflicts${NC}\n"
else
    printf "${YELLOW}[Backport] ==================================================${NC}\n"
    printf "${YELLOW}[Backport] There are conflicts when cherry picking the commit${NC}\n"
    printf "${YELLOW}[Backport] A draft PR with all the conflicts will be created${NC}\n"
    printf "${YELLOW}[Backport] ==================================================${NC}\n"

DIFF_STATUS=$(git status)
CONFLICTS=$(cat <<EOF
:warning: :warning: :warning: Conflicts found when cherry-picking! :warning: :warning: :warning:
\`\`\`
${DIFF_STATUS}
\`\`\`
EOF
)
    git add .
    git -c core.editor=true cherry-pick --continue -S
fi

sleep 1
echo 
echo 
echo "[Backport] pushing..."

git push origin $BACKPORT_BRANCH -u


sleep 3
REPO_FULL_NAME=$(gh repo view --json 'name,owner' -t '{{ .owner.login }}/{{ .name }}')
echo 
echo 
echo "[Backport] Creating a new PR in repo $REPO_FULL_NAME"


# todo: sync changelog
PR_TITLE="$TITLE (backport of #${PR})"
PR_BODY=$(cat <<EOF
Manual cherry-pick of #${PR} to branch \`${TARGET_BRANCH}\`

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
    printf "[Backport] ${YELLOW}Remember to fix the commit and change the PR to 'Ready for review'${NC}\n"
fi

UPSTREAM_REPO_OWNER=$(echo -n $REPO_FULL_NAME | cut -d '/' -f 1)
ORIGIN_REPO_OWNER=$(git remote -v | grep origin | head -n 1 | cut -d ':' -f 2 | cut -d '/' -f 1)

gh pr create $PR_DRAFT \
 --base "${TARGET_BRANCH}" --head "${ORIGIN_REPO_OWNER}:${BACKPORT_BRANCH}" \
 --title "$PR_TITLE" --label "$PR_LABELS" \
 --body "$PR_BODY"