#!/bin/bash


while true; do
    RANDOM_ID="trial-$RANDOM"
    HTTP_STATUS=$(curl -s -o /dev/null --connect-timeout 10 -w "%{http_code}" -H "X-RANDOM-ID: $RANDOM_ID" "$@")
    if [[ "$HTTP_STATUS" -ge 200 ]] && [[ "$HTTP_STATUS" -lt 400 ]]; then
        echo -n "."
    else
        echo ""
        echo "$RANDOM_ID: $HTTP_STATUS"
    fi

    RANDOM_MS=$((100 + RANDOM % 100))
    sleep "0.${RANDOM_MS}"
done
