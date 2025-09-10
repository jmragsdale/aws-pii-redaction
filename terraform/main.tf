terraform { required_providers { aws = { source="hashicorp/aws", version="~>5.0" } } }
provider "aws" { region = var.region }
variable "region" { type=string, default="us-east-1" }
variable "prefix" { type=string, default="piiredact-demo" }

resource "aws_s3_bucket" "in"  { bucket = "${var.prefix}-incoming"; force_destroy = true }
resource "aws_s3_bucket" "out" { bucket = "${var.prefix}-redacted"; force_destroy = true }

data "aws_iam_policy_document" "assume" {
  statement { actions=["sts:AssumeRole"]; principals { type="Service"; identifiers=["lambda.amazonaws.com"] } }
}
resource "aws_iam_role" "lambda" { name="${var.prefix}-lambda"; assume_role_policy=data.aws_iam_policy_document.assume.json }
data "aws_iam_policy_document" "pol" {
  statement { actions = ["s3:GetObject"]; resources=["${aws_s3_bucket.in.arn}/*"] }
  statement { actions = ["s3:PutObject"]; resources=["${aws_s3_bucket.out.arn}/*"] }
  statement { actions = ["comprehend:DetectPiiEntities"]; resources=["*"] }
  statement { actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]; resources=["*"] }
}
resource "aws_iam_policy" "lambda" { name="${var.prefix}-policy"; policy=data.aws_iam_policy_document.pol.json }
resource "aws_iam_role_policy_attachment" "att" { role=aws_iam_role.lambda.name policy_arn=aws_iam_policy.lambda.arn }

resource "aws_lambda_function" "fn" {
  function_name = "${var.prefix}-fn"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = "${path.module}/../lambda.zip"
  environment { variables = { OUTPUT_BUCKET = aws_s3_bucket.out.bucket } }
}
resource "aws_s3_bucket_notification" "evt" { bucket = aws_s3_bucket.in.id eventbridge = true }
resource "aws_cloudwatch_event_rule" "obj" { name="${var.prefix}-s3"; event_pattern = jsonencode({
  "source": ["aws.s3"], "detail-type": ["Object Created"], "detail": {"bucket": {"name": [aws_s3_bucket.in.bucket]}}
})}
resource "aws_cloudwatch_event_target" "t" { rule=aws_cloudwatch_event_rule.obj.name arn=aws_lambda_function.fn.arn }
resource "aws_lambda_permission" "perm" {
  statement_id="AllowEventBridge" action="lambda:InvokeFunction"
  function_name=aws_lambda_function.fn.function_name principal="events.amazonaws.com"
  source_arn=aws_cloudwatch_event_rule.obj.arn
}
