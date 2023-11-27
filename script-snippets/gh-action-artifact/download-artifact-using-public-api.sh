#!/bin/bash

# GITHUB_TOKEN=
# GITHUB_PROJECT=jijiechen/kuma
RUN_NUMBER=$1
ARTIFACT_NAME=build-output
# ARTIFACT_NAME=test-reports

if [[ "$GITHUB_TOKEN" == "" ]] || [[ "$GITHUB_PROJECT" == "" ]]; then
    echo "Please set these environment variables: GITHUB_TOKEN, GITHUB_PROJECT"
    exit 1
fi

function request(){
    METHOD=$1
    URL=$2
    DATA=$3

    if [ "$DATA" != "" ]; then
        DATA="--data $DATA"
    fi

    OUTPUT_FILE=/tmp/circleci-response-$RANDOM.json
    STATUS_CODE=
    while [[ "$STATUS_CODE" == "" ]]; do
        STATUS_CODE=$(curl -o $OUTPUT_FILE -sL -w "%{http_code}" -X $METHOD $URL \
        --header "content-type: application/json" --header "accept: application/vnd.github+json" \
        --header "Authorization: Bearer $GITHUB_TOKEN" --header "X-GitHub-Api-Version: 2022-11-28" $DATA )

        if [[ "$STATUS_CODE" == "429" ]]; then
            STATUS_CODE=
            echo '' > $OUTPUT_FILE
            sleep $((RANDOM % 3))
        fi
    done

    cat $OUTPUT_FILE
    rm $OUTPUT_FILE
    if [ $STATUS_CODE -lt 200 ] || [ $STATUS_CODE -gt 399 ] ; then
        echo "Error requesting $METHOD $URL (status $STATUS_CODE)"
        exit 1
    fi
}

PAGE_SIZE=100
CURRENT_PAGE=0
TOTAL_COUNT=0
TOTAL_PAGES=1
TARGET_ARTIFACT=

while [[ $CURRENT_PAGE -le $TOTAL_PAGES ]] && [[ "$TARGET_ARTIFACT" == "" ]]; do
    CURRENT_PAGE=$(( CURRENT_PAGE + 1 ))
    echo "request GET https://api.github.com/repos/$GITHUB_PROJECT/actions/artifacts?name=${ARTIFACT_NAME}&page=${CURRENT_PAGE}&per_page=${PAGE_SIZE}"
    PAGE_RESP=$(request GET https://api.github.com/repos/$GITHUB_PROJECT/actions/artifacts?name=${ARTIFACT_NAME}&page=${CURRENT_PAGE}&per_page=${PAGE_SIZE})
    echo "$PAGE_RESP" > all-artifacts.json

    if [[ "$CURRENT_PAGE" == "1" ]]; then
        TOTAL_COUNT=$(echo "$PAGE_RESP" | jq '.total_count')
        TOTAL_PAGES=$(( TOTAL_COUNT / PAGE_SIZE + 1 ))
    fi

    TARGET_ARTIFACT=$(echo "$PAGE_RESP" | jq -cr ".artifacts[] | select(.workflow_run.id==$RUN_NUMBER) //empty")

    echo "=============="
    echo "TARGET_ARTIFACT is:"
    echo "$TARGET_ARTIFACT"

    if [[ "$TARGET_ARTIFACT" != "" ]]; then
        EXPIRED=$(echo "$TARGET_ARTIFACT" | jq -cr '.expired')
        if [[ "$EXPIRED" == "true" ]]; then
            echo "Artifact '$ARTIFACT_NAME' in run $RUN_NUMBER has expired."
            exit 1
        fi
        break
    fi

    if [[ $CURRENT_PAGE -eq $TOTAL_PAGES ]]; then
        echo "Artifact '$ARTIFACT_NAME' not found in run $RUN_NUMBER."
        exit 1
    fi
    echo "Did not find on page $CURRENT_PAGE, trying next page..."
    sleep 0.2
done


DOWNLOAD_URL=$(echo "$TARGET_ARTIFACT" | jq -rc '.archive_download_url')
echo $DOWNLOAD_URL
# curl --fail -L -o "${ARTIFACT_NAME}-${RUN_NUMBER}.zip" --header "Authorization: Bearer $GITHUB_TOKEN" $DOWNLOAD_URL
# mkdir build
# unzip ./${ARTIFACT_NAME}-${RUN_NUMBER}.zip -d build