#!/bin/bash -eo pipefail

set -x 

echo "Running with: \
  k8s:kind \
  target:universal \
  parallelism:1 \
  arch:amd64 \
  legacyKDS:flannel \
  cniNetworkPlugin:flannel \
"

GH_ARTIFACT_LIST_URL=https://pipelinesghubeus8.actions.githubusercontent.com/LXXykBUvSKhGoJmm00vjx734imF5SiThwX6LaPspnGD8CkHYEm/_apis/pipelines/workflows/6981936362/artifacts?api-version=6.0-preview
GH_ACTIONS_RUNTIME_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Ikh5cTROQVRBanNucUM3bWRydEFoaHJDUjJfUSJ9.eyJuYW1laWQiOiJkZGRkZGRkZC1kZGRkLWRkZGQtZGRkZC1kZGRkZGRkZGRkZGQiLCJzY3AiOiJBY3Rpb25zLkdlbmVyaWNSZWFkOjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCBBY3Rpb25zLlJlc3VsdHM6MTI3NDhiODUtOGE2ZS00OWViLWFlZjQtNGVhYTEyZjA1ZTYzOjI4ZWM3NTc4LTBhZTktNTZhNS0zMDliLTNiYjIxYjVjNGVhOCBBY3Rpb25zLlVwbG9hZEFydGlmYWN0czowMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAvMTpCdWlsZC9CdWlsZC8yNDQgTG9jYXRpb25TZXJ2aWNlLkNvbm5lY3QgUmVhZEFuZFVwZGF0ZUJ1aWxkQnlVcmk6MDAwMDAwMDAtMDAwMC0wMDAwLTAwMDAtMDAwMDAwMDAwMDAwLzE6QnVpbGQvQnVpbGQvMjQ0IiwiSWRlbnRpdHlUeXBlQ2xhaW0iOiJTeXN0ZW06U2VydmljZUlkZW50aXR5IiwiaHR0cDovL3NjaGVtYXMueG1sc29hcC5vcmcvd3MvMjAwNS8wNS9pZGVudGl0eS9jbGFpbXMvc2lkIjoiREREREREREQtRERERC1ERERELUREREQtREREREREREREREREIiwiaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS93cy8yMDA4LzA2L2lkZW50aXR5L2NsYWltcy9wcmltYXJ5c2lkIjoiZGRkZGRkZGQtZGRkZC1kZGRkLWRkZGQtZGRkZGRkZGRkZGRkIiwiYXVpIjoiZTg2YWE2NTUtNjg5MC00YjJlLTgzYTAtOTZkZDViNGM4ZWE2Iiwic2lkIjoiZDFmMDUyMjctODM3NS00MzkwLWFmMmMtYzM5ZGJhZDVkM2IzIiwiYWMiOiJbe1wiU2NvcGVcIjpcInJlZnMvaGVhZHMvZ2gtYWN0aW9ucy1lMmVcIixcIlBlcm1pc3Npb25cIjozfSx7XCJTY29wZVwiOlwicmVmcy9oZWFkcy9tYXN0ZXJcIixcIlBlcm1pc3Npb25cIjoxfV0iLCJhY3NsIjoiMTAiLCJvcmNoaWQiOiIxMjc0OGI4NS04YTZlLTQ5ZWItYWVmNC00ZWFhMTJmMDVlNjMudGVzdF9lMmVfZW52LnVuaXZlcnNhbF9raW5kX2FtZDY0X2ZsYW4uZTJlLl9fZGVmYXVsdCIsImlzcyI6InZzdG9rZW4uYWN0aW9ucy5naXRodWJ1c2VyY29udGVudC5jb20iLCJhdWQiOiJ2c3Rva2VuLmFjdGlvbnMuZ2l0aHVidXNlcmNvbnRlbnQuY29tfHZzbzozN2Q1MTQ4Ni1hOGViLTQ1ODQtYTcyYi01MzlkMTUyNjIxMmIiLCJuYmYiOjE3MDA4MzY1NDIsImV4cCI6MTcwMDg1OTM0Mn0.KACiD5EUJl6ncmeNcibX-hzAmgTZ-t7cADx2WELdfy_oGB6EeL9kdnGtgc3ZW7hIAaufkcK_pogD2ER_5ORKKa7Sn7T2CWfhynAzXr3ZUA-6NND2i9yzzy1URVAfRJc-LUn1tkbn8cobgxGTN9JaGVYGEhZKdVkIVm-UeOSv9YXWgFJEPmMXAThnw8TjBLLvglNPmMXqKxSqieC70lmk6Dk-Ec88OEiU4cROVc5xmAlEa4w-vA7TH1JrsPlLXOlbPvgLWlzhLQ-b4YbO8T8TIAF5wzBPceCFyBLEIvLhwpaxcQOoKUf5xXQDg35bYia-pQ-jLtDwp2cM603KcoaYFg
GH_ACTIONS_BUILD_ARTIFACT_NAME=build-output
BASE_DIR=build

if [[ "$GH_ACTIONS_RUNTIME_TOKEN" == "" ]]; then
    echo "Please set these environment variables: GH_ACTIONS_RUNTIME_TOKEN"
    exit 1
fi

if [[ "$BASE_DIR" == "" ]]; then
    BASE_DIR="."
fi

function request(){
    METHOD=$1
    URL=$2
    IS_STREAM=$3

    if [[ "$URL" == "" ]]; then
        echo "Unknown URL"
        exit 1
    fi

    ACCEPT=application/json
    if [[ "$IS_STREAM" == "1" ]]; then
        ACCEPT="*/*"
    fi

    OUTPUT_FILE=/tmp/gh-response-$RANDOM
    STATUS_CODE=
    while [[ "$STATUS_CODE" == "" ]]; do
        STATUS_CODE=$(curl -o $OUTPUT_FILE -sL -w "%{http_code}" -X $METHOD $URL \
        --header "accept: $ACCEPT" --header "Authorization: Bearer $GH_ACTIONS_RUNTIME_TOKEN")

        if [[ "$STATUS_CODE" == "429" ]]; then
            STATUS_CODE=
            echo '' > $OUTPUT_FILE
            sleep $((RANDOM % 3))
        fi
    done

    if [ $STATUS_CODE -lt 200 ] || [ $STATUS_CODE -gt 399 ] ; then
        echo "Error requesting $METHOD $URL (status $STATUS_CODE)"
        exit 1
    fi
    if [[ "$IS_STREAM" != "1" ]]; then
        cat $OUTPUT_FILE
        rm $OUTPUT_FILE
    else
        echo "$OUTPUT_FILE"
    fi
}

FILE_LIST_URL=$(request GET "$GH_ARTIFACT_LIST_URL" | jq -rc '.value[0].fileContainerResourceUrl //empty')
LIST_JSON_FILE=$(request GET "$FILE_LIST_URL" 1)
while read FILE_PATH; do
  DOWNLOAD_URL=$(cat $LIST_JSON_FILE | jq -rc ".value[] | select(.path==\"$FILE_PATH\") | .contentLocation")
  FILE_SIZE=$(cat $LIST_JSON_FILE | jq -rc ".value[] | select(.path==\"$FILE_PATH\") | .fileLength")

  FILE_PATH=${FILE_PATH#*/}
  echo "Downloading $FILE_PATH (size: $FILE_SIZE)"
  mkdir -p $(dirname $BASE_DIR/$FILE_PATH)
  FILE_SAVED=$(request GET "$DOWNLOAD_URL" 1)
  mv $FILE_SAVED $BASE_DIR/$FILE_PATH
done < <(cat $LIST_JSON_FILE | jq -rc ".value[] | select((.itemType==\"file\") and (.path|startswith(\"$GH_ACTIONS_BUILD_ARTIFACT_NAME/\"))) | .path")

echo "Downloading complete."
while read FILE_PATH; do
  chmod +x $FILE_PATH
done < <(find $BASE_DIR/artifacts-*/* -type f)