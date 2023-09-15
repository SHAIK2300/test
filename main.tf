data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "sqs-queue" {
  statement {
    sid    = "Allow-SNS-SendMessage"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage"
    ]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sqs-queue-${var.environment}-${terraform.workspace}",
    ]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.sns-sqs-poc.sns_topic.arn]
    }
  }
}

module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = var.namespace
  stage       = terraform.workspace
  environment = var.environment
  name        = var.name
  label_order = ["environment", "stage", "namespace", "name", "attributes"]
  tags = {
    "Workspace" = terraform.workspace
  }
}

module "label-new" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = "lms"
  stage       = "nonprod"
  environment = "infratest"
  name        = terraform.workspace
  label_order = ["namespace", "environment", "name", "attributes"]
  tags = {
    "Workspace" = terraform.workspace
  }
}

##################################################################################################################
module "label-sqs" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  namespace   = var.namespace
  label_order = ["namespace", "environment", "stage", "attributes"]
}

module "sqs-queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "3.4.0"

  name = "sqs-queue-${var.environment}-${terraform.workspace}"
  tags = {
    Environment = var.environment
    Workspace   = terraform.workspace
  }
  create                     = true
  fifo_queue                 = false
  max_message_size           = 262144 #256 KB
  visibility_timeout_seconds = 3600
  message_retention_seconds  = 86400 #1 day 345600= 4days
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = module.sqs-dlq.sqs_queue_arn
    maxReceiveCount     = 4
  })
  policy = data.aws_iam_policy_document.sqs-queue.json
}


module "sqs-dlq" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "3.4.0"

  name = "sqs-dlq-${var.environment}-${terraform.workspace}"
  tags = {
    Environment = var.environment
    Workspace   = terraform.workspace
  }
  create                    = true
  fifo_queue                = false
  message_retention_seconds = 86400
}

##################################################################################################################
module "sns-sqs-poc" {
  source  = "cloudposse/sns-topic/aws"
  version = "0.20.2"

  context = module.label-sqs.context
  # kms_master_key_id = "alias/aws/sns"
  sqs_dlq_enabled = false
  #allowed_aws_services_for_sns_published = ["arn:aws:sns:us-west-2:691051911399:lms-infratest-default"]
  #  allowed_iam_arns_for_sns_publish = ["arn:aws:sns:us-west-2:691051911399:lms-infratest-default"]
  subscribers = {
    sqs-dlq = {
      protocol               = "sqs"
      endpoint               = "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.sqs-dlq.sqs_queue_name}"
      endpoint_auto_confirms = true
      raw_message_delivery   = false
    }
  }
  allowed_iam_arns_for_sns_publish = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.sqs-queue.sqs_queue_name}", #THIS IS CREATED OUTSIDE OF TERRAFORM
  ]
}
data "aws_iam_policy_document" "aws_sns_topic_policy" {
  statement {
    sid = "AllowSQSPermissions"
    actions = [
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:ListQueues"
    ]
    effect    = "Allow"
    resources = ["arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.sqs-queue.sqs_queue_name}"]
    #arn:aws:sqs:us-west-2:691051911399:sqs-queue-infratest-default
  }
  statement {
    actions = [
      "sns:Subscribe"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.sns-sqs-poc.sns_topic_name}"
    ]
    # principal {
    #   "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    #   # identifiers = toset([for i in local.account_id : "arn:aws:iam::${i}:root"])
    #   # type        = "AWS"
    # }
  }
}



resource "aws_sqs_queue_policy" "sqs-queue-policy" {
  queue_url = module.sqs-queue.sqs_queue_id

  policy = <<EOF
  {
    "Version": "2008-10-17",
    "Id": " policy",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": [
          "SQS:SendMessage",
          "SQS:ReceiveMessage"
        ],
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_sns_topic_policy" "access" {
  #count  = length(local.accounts) == 0 ? 0 : 1
  arn    = module.sns-sqs-poc.sns_topic_arn
  policy = data.aws_iam_policy_document.aws_sns_topic_policy.json
}