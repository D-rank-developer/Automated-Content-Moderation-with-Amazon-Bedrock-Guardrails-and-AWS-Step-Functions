#!/bin/bash

LOG_GROUP="/catnip/test-logs"
LOG_STREAM="simulation"

aws logs create-log-group --log-group-name $LOG_GROUP 2>/dev/null
aws logs create-log-stream --log-group-name $LOG_GROUP --log-stream-name $LOG_STREAM 2>/dev/null

SEQUENCE_TOKEN=""

while true
do
  while read line
  do
    TIMESTAMP=$(($(date +%s%N)/1000000))

    if [ -z "$SEQUENCE_TOKEN" ]; then
        RESPONSE=$(aws logs put-log-events \
          --log-group-name $LOG_GROUP \
          --log-stream-name $LOG_STREAM \
          --log-events timestamp=$TIMESTAMP,message="$line")
    else
        RESPONSE=$(aws logs put-log-events \
          --log-group-name $LOG_GROUP \
          --log-stream-name $LOG_STREAM \
          --log-events timestamp=$TIMESTAMP,message="$line" \
          --sequence-token $SEQUENCE_TOKEN)
    fi

    SEQUENCE_TOKEN=$(echo $RESPONSE | jq -r '.nextSequenceToken')

    echo "Sent log: $line"

    sleep 2
  done < text_message.txt
done