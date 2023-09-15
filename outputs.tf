output "account_id" {
  value = local.account_id
}

output "sqs-queue_id" {
  value = module.sqs-queue.sqs_queue_id
}

output "sqs-queue_identification_name" {
  value = module.sqs-queue.sqs_queue_name
}

output "dead_letter_queue_id" {
  value = module.sqs-dlq.sqs_queue_id

}

output "deadletter_queue_name" {
  value = module.sqs-dlq.sqs_queue_name

}

output "sqs_topic_arn" {
  value = module.sns-sqs-poc.sns_topic.arn

}