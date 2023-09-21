data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

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

#################################### L a m b d a ####################################################

module "label-lambda" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context   = module.label-new.context
  namespace = "lambda"
}

module "lambdapoc" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.34.1"

  create_function                         = true
  cloudwatch_logs_retention_in_days       = 90
  memory_size                             = var.lambda_memory_size
  create_package                          = false
  function_name                           = "${module.label-lambda.id}-poc"  #lambda-infratest-default-poc
  role_name                               = "${module.label-lambda.id}_role1" #lambda-infratest-default_role
  handler                                 = "lambda_function.lambda_handler"
  runtime                                 = "python3.9"
  publish                                 = true
  timeout                                 = var.lambda_timeout
  attach_policy_json                      = true
  policy_json                             = data.aws_iam_policy_document.lambdapoc.json
  attach_policies                         = true
  create_current_version_allowed_triggers = true

  s3_existing_package = {
    bucket     = "sqslambdapoc"
    key        = "lambda1/lambda_function.zip" #lambda_fucniton.zip for lambda1 to be added.
    version_id = null
  }
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy",
  ]
  number_of_policies    = 2
  attach_network_policy = false

  tags = {
    Environment = var.environment
    Workspace   = terraform.workspace
  }
}

data "aws_iam_policy_document" "lambdapoc" {
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
  }
  statement {
    sid    = "S3BucketPermissions"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetBucketPolicy"
    ]
    resources = [
      "arn:aws:s3:::sqslambdapoc"
    ]
  }
  statement {
    sid = "snspermissinlambdapoc"
    effect = "Allow"
    actions = [ 
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic"
     ]
     resources = [ 
      "arn:aws:sns:us-west-2:691051911399:sns-infratest-default"
     ]
  }
}


#################################### L a m b d a - 2 ####################################################
module "lambdapoc2" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.34.1"

  create_function                         = true
  cloudwatch_logs_retention_in_days       = 90
  memory_size                             = var.lambda_memory_size
  create_package                          = false
  function_name                           = "${module.label-lambda.id}-sns-poc" #lambda-infratest-default-sns-poc
  role_name                               = "${module.label-lambda.id}_role2"    #lambda-infratest-default_role
  handler                                 = "lambda_function.lambda_handler"
  runtime                                 = "python3.9"
  publish                                 = true
  timeout                                 = var.lambda_timeout
  attach_policy_json                      = true
  policy_json                             = data.aws_iam_policy_document.lambdapoc.json
  attach_policies                         = true
  create_current_version_allowed_triggers = true

  s3_existing_package = {
    bucket     = "sqslambdapoc"
    key        = "lambda2/lambda_function.zip" #lambda_fucniton.zip for lambda1 to be added.
    version_id = null
  }
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy",
  ]
  number_of_policies    = 2
  attach_network_policy = false

  tags = {
    Environment = var.environment
    Workspace   = terraform.workspace
  }
}

resource "aws_lambda_event_source_mapping" "mapping_lambda_sqs" {
  event_source_arn = module.sqs-queue.sqs_queue_arn
  function_name    = module.lambdapoc2.lambda_function_arn
  batch_size       = 1 # Adjust this value according to requirements
}

#################################### S Q S - T O P I C ####################################################

data "aws_iam_policy_document" "sqs-queue" {
  statement {
    sid    = "Allow-SNS-SendMessage"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage"
    ]
    principals {
            type        = "AWS"
            identifiers = ["*"]
               }
    # principals = {
    #     "AWS": "123456789012" 
    # }
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.label-sqs.id}-main-poc",
    ]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.sns-sqs-poc.sns_topic_arn]
    }
  }
}
     # "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.label-sqs.id}-main-poc",


module "label-sqs" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  namespace   = "sqs"
  label_order = ["namespace", "environment", "stage", "attributes"]
}


module "sqs-queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "3.4.0"

  name = "${module.label-sqs.id}-main-poc"
  tags = {
    Environment = var.environment
    Workspace   = terraform.workspace
  }
  create                     = true
  fifo_queue                 = false
  max_message_size           = 262144 #256 KB
  visibility_timeout_seconds = 1800
  message_retention_seconds  = 86400 #1 day, 345600= 4days
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

  name = "${module.label-sqs.id}-dlq-poc"
  tags = {
    Environment = var.environment
    Workspace   = terraform.workspace
  }
  create                    = true
  fifo_queue                = false
  message_retention_seconds = 86400 #1day
}

#################################### S N S - T O P I C ####################################################
module "label-sns" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  namespace   = "sns"
  label_order = ["namespace", "environment", "stage", "attributes"]
}

resource "aws_sns_topic_policy" "default" {
  arn = module.sns-sqs-poc.sns_topic_arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "${module.sqs-queue.sqs_queue_arn}",
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      module.sns-sqs-poc.sns_topic_arn
    ]

    sid = "created for sns"
  }
}

module "sns-sqs-poc" {
  source  = "cloudposse/sns-topic/aws"
  version = "0.20.2"

  context           = module.label-sns.context
  kms_master_key_id = "alias/aws/sns"
  name = "${module.label-sns.id}-poc"
  sqs_dlq_enabled   = false
  subscribers = {
    sqs = {
      protocol               = "sqs"
      endpoint               = "${module.sqs-queue.sqs_queue_arn}"
      endpoint_auto_confirms = true
      raw_message_delivery   = false
    }
  }
  #allowed_aws_services_for_sns_published = ["*"]
  allowed_iam_arns_for_sns_publish = []
   # "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.sqs-queue.sqs_queue_name}", #THIS IS CREATED OUTSIDE OF TERRAFORM
}


data "aws_iam_policy_document" "sns-sqs" {
  statement {
    sid    = "SNS to publish mesage to sqs"
    effect = "Allow"
    actions = [
      "SNS:Publish",
      "sns:AddPermission"
    ]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    resources = [
      "${module.sns-sqs-poc.sns_topic_arn}", #snstopicarn
    ]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.sqs-queue.sqs_queue_arn]
    }
  }
}