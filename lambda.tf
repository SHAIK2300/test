module "label-lambda" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context   = module.label-new.context
  namespace = "lambda-poc"
}

module "lambdapoc" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.34.1"

  create_function                         = true
  cloudwatch_logs_retention_in_days       = 90 #var.cw_log_group_retention_period
  memory_size                             = var.lambda_memory_size
  create_package                          = false
  function_name                           = "${module.label-lambda.id}_sqs-sns" #lambda-poc-infratest-default_sqs-sns
  role_name                               = "${module.label-lambda.id}_role"    #lambda-poc-infratest-default_role
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
    key        = "Newfolder/lambda_function.zip"
    version_id = null
  }
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy",
  ]
  number_of_policies    = 2
  attach_network_policy = true

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
    #arn:aws:sqs:us-west-2:691051911399:sqs-queue-infratest-default
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
    sid    = "SNSPERMISSIN"
    effect = "Allow"
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish"
    ]
    resources = [
      "${module.sns-sqs-poc.sns_topic.arn}"
    ]
  }
}

resource "aws_lambda_event_source_mapping" "mapping_lambda_sqs" {
  event_source_arn = module.sqs-queue.sqs_queue_arn
  function_name    = module.lambdapoc.lambda_function_arn
  batch_size       = 1 # Adjust this value according to your requirements
}


