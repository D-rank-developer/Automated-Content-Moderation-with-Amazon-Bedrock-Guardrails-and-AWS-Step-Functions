# Automated Content Moderation with Amazon Bedrock Guardrails and AWS Step-Functions

* CloudWatch Logs simulation
* Alarms
* DynamoDB moderation results
* S3 uploads
* Python log generator

---

# Secure Cloud Content Moderation & Monitoring Platform

## AWS • Terraform • DevSecOps • Security and Identity

![AWS](https://img.shields.io/badge/AWS-Cloud%20Security-orange)
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)
![Python](https://img.shields.io/badge/Python-Automation-blue)
![CloudWatch](https://img.shields.io/badge/Monitoring-CloudWatch-green)
![DevSecOps](https://img.shields.io/badge/Serverless-Lambda-red)

---

# Project Overview

This project implements a **secure event-driven content moderation and monitoring platform on AWS** using **Infrastructure as Code (Terraform)**.

The system automatically:

1. Accepts uploaded content
2. Moderates text and images using AI services
3. Stores moderation results securely
4. Generates monitoring metrics
5. Triggers alarms when suspicious activity occurs
6. Simulates real system logs for security testing

The project demonstrates **cloud security architecture, serverless computing, automation, monitoring, and incident detection**.

---

# Architecture

```
![Cloudwatch](https://github.com/D-rank-developer/Automated-Content-Moderation-with-Amazon-Bedrock-Guardrails-and-AWS-Step-Functions/blob/d2daf2fa0c5d0fcc4c109bcbfb3eb01e10d61bb0/AWS.png)
```

---

# Key AWS Services Used

| Service                       | Purpose                           |
| ----------------------------- | --------------------------------- |
| **Terraform**                 | Infrastructure as Code deployment |
| **Amazon S3**                 | Content storage                   |
| **AWS Lambda**                | Moderation engine                 |
| **Amazon Bedrock Guardrails** | AI text moderation                |
| **Amazon Rekognition**        | Image moderation                  |
| **Amazon DynamoDB**           | Store moderation results          |
| **Amazon SNS**                | Notification system               |
| **CloudWatch Logs**           | Log collection                    |
| **CloudWatch Alarms**         | Security monitoring               |

---

# Infrastructure Deployment (Terraform)

All cloud infrastructure was deployed using **Terraform**, ensuring **repeatable and secure infrastructure provisioning**.

## Terraform Initialization

```bash
terraform init
```

## Terraform Plan

```bash
terraform plan
```

## Terraform Apply

```bash
terraform apply
```

---

# Terraform Example Configuration

Example provider configuration:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

Example DynamoDB table definition:

```hcl
resource "aws_dynamodb_table" "moderation_results" {
  name         = "contentmod-results-demo"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "object_key"

  attribute {
    name = "object_key"
    type = "S"
  }
}
```

Example S3 upload bucket:

```hcl
resource "aws_s3_bucket" "uploads" {
  bucket = "contentmod-uploads-demo"
}
```

Terraform outputs allow resources to be referenced by other services.

---

# Content Moderation Engine

Content moderation is handled by **AWS Lambda**.

The Lambda function processes uploaded files and decides whether the content should be:

* Approved
* Rejected
* Sent for manual review

---

# Lambda Moderation Logic

The moderation logic is implemented in:

```
moderate.py
```

Key functionality:

* Detect text content
* Apply Bedrock guardrails
* Detect image content
* Use Rekognition moderation labels
* Store moderation decision in DynamoDB
* Send alerts using SNS

Example moderation workflow:

```python
def lambda_handler(event, context):
    bucket = event["detail"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(event["detail"]["object"]["key"])

    obj = s3.get_object(Bucket=bucket, Key=key)

    if content_type.startswith("text/"):
        result = moderate_text(bucket, key, obj)
    elif content_type.startswith("image/"):
        result = moderate_image(bucket, key)

    save_result(bucket, key, content_type, result)
```

Moderation results are stored in DynamoDB:

```python
table.put_item(
    Item={
        "object_key": key,
        "bucket": bucket,
        "decision": result["decision"],
        "processed_at": datetime.now(timezone.utc).isoformat()
    }
)
```



---

# Moderation Result Storage

All moderation outcomes are stored in **Amazon DynamoDB**.

Each record contains:

* Object key
* Bucket name
* Content type
* Moderation decision
* Detailed moderation analysis
* Processing timestamp

Example entry:

```
object_key: abuse.txt
decision: rejected
mode: text
processed_at: 2026-03-12T08:23:49
```

This allows **auditability and forensic analysis** of moderation decisions.

---

# Log Simulation for Monitoring

To simulate real application activity, a **Python log generator** was created.

This script sends simulated logs to **CloudWatch Logs**.

File:

```
generate_logs.py
```

Example messages:

* Player joined lobby
* User logged in successfully
* Profanity detected in player message
* Server health check completed

Example code snippet:

```python
GOOD_MESSAGES = [
    "Player joined lobby",
    "User logged in successfully",
    "Game server started normally"
]

FLAGGED_MESSAGES = [
    "User message contains profanity",
    "Player used profanity in chat"
]
```

Logs are sent to CloudWatch using:

```python
logs.put_log_events(...)
```



---

# CloudWatch Monitoring

CloudWatch collects logs from the simulated application environment.

Example log events:

```
Player joined lobby
User message contains profanity
Chat moderation detected profanity
Game server started normally
```

These logs allow monitoring of **potential policy violations and system behavior**.

---

# Security Alarms

CloudWatch alarms were configured to detect suspicious activity.

Example alarms:

| Alarm           | Trigger                    |
| --------------- | -------------------------- |
| ProfanityCount  | ≥5 events within 5 minutes |
| RejectedContent | ≥1 rejected content        |

These alarms enable **real-time security monitoring and incident detection**.

---

# Example Monitoring Output

CloudWatch detects moderation violations such as:

```
profanity detected in player message
User message contains profanity
Chat moderation detected profanity
```

When thresholds are exceeded, alarms trigger alerts.

---

# Example Data Flow

```
User uploads file
      ↓
S3 Event Trigger
      ↓
Lambda moderation function
      ↓
AI moderation analysis
      ↓
Results stored in DynamoDB
      ↓
CloudWatch logs activity
      ↓
Alarms trigger on suspicious behavior
```

---

# Security Benefits

This system improves cloud security by:

* Automatically detecting abusive content
* Logging all moderation actions
* Creating auditable records
* Generating real-time alerts
* Preventing harmful content distribution

---

# DevSecOps Principles Applied

| Principle                 | Implementation       |
| ------------------------- | -------------------- |
| Infrastructure as Code    | Terraform            |
| Automated moderation      | Lambda + AI services |
| Continuous monitoring     | CloudWatch           |
| Incident detection        | CloudWatch alarms    |
| Event-driven architecture | S3 + EventBridge     |

---

# How to Run the System

### 1️⃣ Deploy Infrastructure

```
terraform init
terraform apply
```

---

### 2️⃣ Upload Content

Upload files to S3:

```
abuse.txt
safe.txt
alarm-test.txt
```

The Lambda function automatically moderates the files.

---

### 3️⃣ View Results

Check DynamoDB for moderation decisions.

---

### 4️⃣ Monitor Logs

Run the simulation script:

```bash
python generate_logs.py
```

This generates logs for monitoring and alarm testing.

---

### 5️⃣ View Alerts

Navigate to:

```
CloudWatch → Alarms
```

Monitor triggered moderation alerts.

---

# Example Repository Structure

```
project/
│
├── terraform/
│   ├── main.tf
│   ├── versions.tf
│   └── outputs.tf
│
├── lambda/
│   └── moderate.py
│
├── monitoring/
│   └── generate_logs.py
│
└── README.md
```

---

# Skills Demonstrated

* AWS Cloud Architecture
* Terraform Infrastructure as Code
* Serverless Development
* Cloud Security Monitoring
* AI Content Moderation
* DevSecOps Automation
* Python Cloud Automation

---

# Future Improvements

Possible extensions include:

* Real-time dashboards
* SIEM integration
* automated incident response
* threat intelligence feeds
* URL safety scanning
* machine learning moderation improvements

---

# Author

Cloud Security Engineer Portfolio Project

Demonstrating **AWS, Terraform, Serverless Security Monitoring, and AI Moderation Pipelines**.

---

If you want, I can also **upgrade this README into a very high-end GitHub portfolio version** with:

* **architecture diagrams**
* **security threat model**
* **attack simulation section**
* **CloudWatch dashboard visuals**
* **DevSecOps pipeline diagram**

This would make the project look **senior-level to employers.**

