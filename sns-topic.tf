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
    sqs-queue = {
      protocol               = "sqs"
      endpoint               = "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.sqs-queue.sqs_queue_name}"
      endpoint_auto_confirms = true
      raw_message_delivery   = false
      #queue_url = 
    }
  }
  allowed_iam_arns_for_sns_publish = []
  #   "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.sqs-dlq.sqs_queue_name}", #THIS IS CREATED OUTSIDE OF TERRAFORM 
  #   #replaced with "*" from module.sqswith star to check
  #   #replaced with ${module.sqs-dlq.sqs_queue_name}
  # ]
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
  # statement {
  #   actions = [
  #     "sns:Subscribe"
  #   ]
  #   effect = "Allow"
  #   resources = [
  #     "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.sns-sqs-poc.sns_topic_name}"
  #   ]
  #   # principal {
  #   #   "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  #   #   # identifiers = toset([for i in local.account_id : "arn:aws:iam::${i}:root"])
  #   #   # type        = "AWS"
  #   # }
  # }
}
