output "invoke_url" {
  description = "API Gateway HTTP API invoke URL (no custom domain in this pass)."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.api.function_name
}

output "execution_role_arn" {
  description = "Lambda execution role ARN — for sanity-checking it's under the CI deploy role's spiresen-saga-* IAM scope."
  value       = aws_iam_role.lambda_exec.arn
}
