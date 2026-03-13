import json
import os
import urllib.parse
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")
bedrock = boto3.client("bedrock-runtime")
rekognition = boto3.client("rekognition")

RESULTS_TABLE = os.environ["RESULTS_TABLE"]
REVIEW_TOPIC_ARN = os.environ["REVIEW_TOPIC_ARN"]
BEDROCK_GUARDRAIL_ID = os.environ["BEDROCK_GUARDRAIL_ID"]
BEDROCK_GUARDRAIL_VERSION = os.environ["BEDROCK_GUARDRAIL_VERSION"]
TEXT_REJECT_CONFIDENCES = set(json.loads(os.environ["TEXT_REJECT_CONFIDENCES"]))
IMAGE_REVIEW_MIN_CONFIDENCE = float(os.environ["IMAGE_REVIEW_MIN_CONFIDENCE"])
IMAGE_REJECT_MIN_CONFIDENCE = float(os.environ["IMAGE_REJECT_MIN_CONFIDENCE"])

table = dynamodb.Table(RESULTS_TABLE)

TEXT_EXTENSIONS = {".txt", ".md", ".csv", ".json", ".log"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def lambda_handler(event, context):
    bucket = event["detail"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(event["detail"]["object"]["key"])

    ext = "." + key.rsplit(".", 1)[-1].lower() if "." in key else ""
    obj = s3.get_object(Bucket=bucket, Key=key)
    content_type = (obj.get("ContentType") or "").lower()

    if content_type.startswith("text/") or ext in TEXT_EXTENSIONS:
        result = moderate_text(bucket, key, obj)
    elif content_type.startswith("image/") or ext in IMAGE_EXTENSIONS:
        result = moderate_image(bucket, key)
    else:
        result = {
            "decision": "review",
            "reason": f"Unsupported content type for automatic moderation: {content_type or ext or 'unknown'}",
            "mode": "fallback"
        }

    save_result(bucket, key, content_type, result)

    if result["decision"] in {"review", "rejected"}:
        sns.publish(
            TopicArn=REVIEW_TOPIC_ARN,
            Subject=f"Content moderation: {result['decision']}",
            Message=json.dumps(
                {
                    "bucket": bucket,
                    "key": key,
                    "decision": result["decision"],
                    "reason": result.get("reason"),
                    "details": result.get("details", {})
                },
                indent=2,
                default=str
            )
        )

    return result


def moderate_text(bucket, key, obj):
    body = obj["Body"].read().decode("utf-8", errors="replace")

    response = bedrock.apply_guardrail(
        guardrailIdentifier=BEDROCK_GUARDRAIL_ID,
        guardrailVersion=BEDROCK_GUARDRAIL_VERSION,
        source="INPUT",
        outputScope="FULL",
        content=[
            {
                "text": {
                    "text": body
                }
            }
        ]
    )

    action = response.get("action", "NONE")
    assessments = response.get("assessments", [])

    filters = []
    for assessment in assessments:
        for f in assessment.get("contentPolicy", {}).get("filters", []):
            filters.append(
                {
                    "type": f.get("type"),
                    "confidence": f.get("confidence"),
                    "action": f.get("action"),
                    "detected": f.get("detected"),
                }
            )

    if action == "NONE":
        decision = "approved"
        reason = "Guardrail did not intervene"
    else:
        reject_match = any((f.get("confidence") in TEXT_REJECT_CONFIDENCES) for f in filters)
        decision = "rejected" if reject_match else "review"
        reason = "Guardrail intervened"

    return {
        "decision": decision,
        "reason": reason,
        "mode": "text",
        "details": {
            "action": action,
            "filters": filters,
            "usage": response.get("usage", {})
        }
    }


def moderate_image(bucket, key):
    response = rekognition.detect_moderation_labels(
        Image={"S3Object": {"Bucket": bucket, "Name": key}},
        MinConfidence=IMAGE_REVIEW_MIN_CONFIDENCE
    )

    labels = response.get("ModerationLabels", [])
    max_conf = max((label.get("Confidence", 0.0) for label in labels), default=0.0)

    if not labels:
        decision = "approved"
        reason = "No moderation labels detected"
    elif max_conf >= IMAGE_REJECT_MIN_CONFIDENCE:
        decision = "rejected"
        reason = "Image moderation confidence exceeded reject threshold"
    else:
        decision = "review"
        reason = "Image moderation label detected"

    return {
        "decision": decision,
        "reason": reason,
        "mode": "image",
        "details": {
            "max_confidence": max_conf,
            "labels": labels
        }
    }


def save_result(bucket, key, content_type, result):
    table.put_item(
        Item={
            "object_key": key,
            "bucket": bucket,
            "content_type": content_type,
            "decision": result["decision"],
            "reason": result.get("reason", ""),
            "mode": result.get("mode", ""),
            "details": json.dumps(result.get("details", {}), default=str),
            "processed_at": datetime.now(timezone.utc).isoformat()
        }
    )