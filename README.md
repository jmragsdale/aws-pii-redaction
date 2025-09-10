# AWS PII Redaction (Comprehend)
Uploads to S3 `incoming` trigger a Lambda that redacts PII and writes to `redacted`.
## Deploy
cd terraform && ./build.sh && terraform init && terraform apply -auto-approve
aws s3 cp ../samples/pii-sample.txt s3://<prefix>-incoming/
## Teardown
terraform destroy -auto-approve
