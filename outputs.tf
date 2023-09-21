output "sqs_queue_arn" {
  description = "sqs queue arn of main queue"
  value       = module.sqs-queue.sqs_queue_arn
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