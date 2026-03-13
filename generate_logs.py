import time
import random
import boto3
from datetime import datetime, timezone

REGION = "us-east-1"
LOG_GROUP = "/catnip/test-logs"
LOG_STREAM = "simulation"
SLEEP_SECONDS = 2

GOOD_MESSAGES = [
    "Hello player welcome to the server",
    "Matchmaking completed successfully",
    "Player joined lobby",
    "User logged in successfully",
    "Game server started normally",
    "Connection established between nodes",
    "Match finished with no errors",
    "Player earned new achievement",
    "Server health check completed",
    "Leaderboard updated successfully"
]

FLAGGED_MESSAGES = [
    "User message contains profanity",
    "Player used profanity in chat",
    "Chat moderation detected profanity",
    "profanity detected in player message",
    "A player sent profanity in the lobby"
]

logs = boto3.client("logs", region_name=REGION)

def ensure_resources():
    try:
        logs.create_log_group(logGroupName=LOG_GROUP)
        print(f"Created log group: {LOG_GROUP}")
    except logs.exceptions.ResourceAlreadyExistsException:
        print(f"Log group exists: {LOG_GROUP}")

    try:
        logs.create_log_stream(logGroupName=LOG_GROUP, logStreamName=LOG_STREAM)
        print(f"Created log stream: {LOG_STREAM}")
    except logs.exceptions.ResourceAlreadyExistsException:
        print(f"Log stream exists: {LOG_STREAM}")

def get_sequence_token():
    streams = logs.describe_log_streams(
        logGroupName=LOG_GROUP,
        logStreamNamePrefix=LOG_STREAM
    )["logStreams"]

    if not streams:
        return None

    token = streams[0].get("uploadSequenceToken")
    return token

def send_log(message, sequence_token):
    event = {
        "timestamp": int(datetime.now(timezone.utc).timestamp() * 1000),
        "message": message
    }

    kwargs = {
        "logGroupName": LOG_GROUP,
        "logStreamName": LOG_STREAM,
        "logEvents": [event]
    }

    if sequence_token:
        kwargs["sequenceToken"] = sequence_token

    response = logs.put_log_events(**kwargs)
    next_token = response.get("nextSequenceToken")
    return next_token

def main():
    ensure_resources()
    sequence_token = get_sequence_token()

    print("Sending test logs. Press Ctrl+C to stop.")
    while True:
        # 70% normal, 30% flagged
        if random.random() < 0.30:
            message = random.choice(FLAGGED_MESSAGES)
        else:
            message = random.choice(GOOD_MESSAGES)

        try:
            sequence_token = send_log(message, sequence_token)
            print(f"Sent: {message}")
        except logs.exceptions.InvalidSequenceTokenException:
            sequence_token = get_sequence_token()
            sequence_token = send_log(message, sequence_token)
            print(f"Sent after token refresh: {message}")

        time.sleep(SLEEP_SECONDS)

if __name__ == "__main__":
    main()