#!/bin/bash

set -e
  
function request(){
    METHOD=$1
    URL=$2
    DATA=$3
    
    if [ "$DATA" != "" ]; then
    DATA="--data $DATA"
    fi

    OUTPUT_FILE=/tmp/circleci-response-$RANDOM.json
    STATUS_CODE=$(curl $VERBOSE -o $OUTPUT_FILE -sL -w "%{http_code}" -X $METHOD $URL \
    --header "content-type: application/json" --header "accept: application/json" \
    --header "x-attribution-login: jijiechen" --header "x-attribution-actor-id: jijiechen" \
    --header "Circle-Token: $CIRCLE_CI_TOKEN_NEW" $DATA )

    cat $OUTPUT_FILE
    rm $OUTPUT_FILE
    if [ "$STATUS_CODE" == "429" ]; then
    # we are exceeding rate limit
    echo "{}"
    return
    fi
    if [ $STATUS_CODE -lt 200 ] || [ $STATUS_CODE -gt 399 ] ; then
    echo "Error requesting $METHOD $URL (status $STATUS_CODE)"
    exit 1
    fi
}

function check_workflow(){
    WORKFLOW_ID=$1
    STATUS=''
    echo ''
    # status could be "success" "running" "not_run" "failed" "error" "failing" "on_hold" "canceled" "unauthorized"
    while [[ "$STATUS" == "" ]] || [[ "$STATUS" == "not_run" ]] || [[ "$STATUS" == "running" ]] || [[ "$STATUS" == "on_hold" ]]; do
        sleep $((RANDOM % 3 + 5))
        STATUS=$(request GET https://circleci.com/api/v2/workflow/$WORKFLOW_ID | jq -r '.status')
        echo -n .
    done

    if [[ "$STATUS" == "success" ]]; then
        echo "CircleCI workflow has completed successfully."
    else
        echo "CircleCI workflow run '$STATUS'."
    fi
}



check_workflow 6a9f8efa-708a-4ec7-82d3-c16b9383bcf9
