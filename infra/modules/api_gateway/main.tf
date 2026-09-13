resource "aws_api_gateway_rest_api" "this" {
  name        = var.name
  description = "Health check endpoint for the ${var.stage_name} environment."

  # Regional rather than the default edge optimised. There is no global
  # audience to put behind CloudFront, and regional avoids the extra hop.
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "health"
}

# The same rule the Lambda enforces, declared once more at the edge so a body
# without payload is rejected before it can reach the function.
resource "aws_api_gateway_model" "request" {
  rest_api_id  = aws_api_gateway_rest_api.this.id
  name         = "HealthCheckRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema"  = "http://json-schema.org/draft-04/schema#"
    title      = "HealthCheckRequest"
    type       = "object"
    required   = ["payload"]
    properties = { payload = {} }
  })
}

resource "aws_api_gateway_request_validator" "body" {
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  name                        = "validate-body"
  validate_request_body       = true
  validate_request_parameters = false
}

# GET carries no body, so there is nothing to validate against the model.
resource "aws_api_gateway_method" "get" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.health.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "post" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.health.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true

  request_validator_id = aws_api_gateway_request_validator.body.id

  request_models = {
    "application/json" = aws_api_gateway_model.request.name
  }
}

# AWS_PROXY hands the whole request to the function and uses its response
# verbatim. integration_http_method is always POST because that is how Lambda
# is invoked, regardless of the method the caller used.
resource "aws_api_gateway_integration" "get" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.get.http_method

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.post.http_method

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.lambda_invoke_arn
}

# Scoped to this api. Without source_arn any API Gateway account could invoke
# the function.
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowInvocationFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# A deployment is an immutable snapshot of the api. The trigger forces a new
# one whenever any part of the definition changes, otherwise edits are saved
# but never go live.
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.health.id,
      aws_api_gateway_method.get.id,
      aws_api_gateway_method.post.id,
      aws_api_gateway_integration.get.id,
      aws_api_gateway_integration.post.id,
      aws_api_gateway_model.request.id,
      aws_api_gateway_request_validator.body.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}

# Stage wide throttling. This is the backstop that applies to every caller,
# including one without an api key hitting a 403.
resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }
}

resource "aws_api_gateway_api_key" "this" {
  name        = "${var.name}-key"
  description = "Caller key for the ${var.stage_name} health check endpoint."
}

resource "aws_api_gateway_usage_plan" "this" {
  name        = "${var.name}-usage-plan"
  description = "Throttles callers of the ${var.stage_name} health check endpoint."

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }
}

resource "aws_api_gateway_usage_plan_key" "this" {
  key_id        = aws_api_gateway_api_key.this.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id
}
