# @author Rio Astamal <rio@rioastamal.net>
# @link https://teknocerdas.com/programming/tutorial-serverless-membuat-lambda-custom-runtime-untuk-deno

# export your AWS_PROFILE and AWS_DEFAULT_REGION by yourself
provider "aws" {
  version = "~> 2.61"
}

variable "default_tags" {
  type = map
  default = {
    Env = "Demo"
    App = "TeknoCerdas"
    FromTerraform = "true"
  }
}

variable "default_bucket" {
  type = string
  default = null
}

resource "aws_iam_role" "deno" {
  name = "LambdaBasicExec"
  tags = var.default_tags
  description = "Allows Lambda functions to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "deno" {
  role = aws_iam_role.deno.id
  # AWS Managed
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# This bucket is used to store Lambda function and layer
resource "aws_s3_bucket" "deno" {
  bucket = var.default_bucket
  acl = "private"
  tags = var.default_tags
}

# Upload the layer and function
resource "aws_s3_bucket_object" "deno_layer" {
  bucket = aws_s3_bucket.deno.id
  tags = var.default_tags
  key = "deno-custom-runtime/layer.zip"
  source = "${path.module}/../build/layer.zip"
  etag = filemd5("${path.module}/../build/layer.zip")
}
resource "aws_s3_bucket_object" "deno_func" {
  bucket = aws_s3_bucket.deno.id
  tags = var.default_tags
  key = "deno-custom-runtime/function.zip"
  source = "${path.module}/../build/function.zip"
  etag = filemd5("${path.module}/../build/function.zip")
}

# Deno Layer
resource "aws_lambda_layer_version" "deno" {
  layer_name = "TeknocerdasDenoRuntime"
  s3_bucket = aws_s3_bucket.deno.id
  s3_key = aws_s3_bucket_object.deno_layer.key
  s3_object_version = aws_s3_bucket_object.deno_layer.version_id
  compatible_runtimes = ["provided"]
  description = "Custom Deno runtime by TeknoCerdas.com"
  source_code_hash = filebase64sha256("${path.module}/../build/layer.zip")
}

resource "aws_lambda_function" "deno" {
  function_name = "DenoAPI"
  handler       = "main.handler"
  role          = aws_iam_role.deno.arn
  memory_size   = 512
  runtime       = "provided"
  tags          = var.default_tags
  timeout       = 5
  layers        = [aws_lambda_layer_version.deno.arn]

  s3_bucket     = aws_s3_bucket.deno.id
  s3_key        = aws_s3_bucket_object.deno_func.key
  source_code_hash = filebase64sha256("${path.module}/../build/function.zip")
}

resource "aws_apigatewayv2_api" "deno" {
  name          = "DenoAPI"
  protocol_type = "HTTP"
  tags          = var.default_tags
}

resource "aws_apigatewayv2_integration" "deno" {
  api_id              = aws_apigatewayv2_api.deno.id
  integration_uri     = aws_lambda_function.deno.arn
  integration_type    = "AWS_PROXY"
  integration_method  = "POST"
  connection_type     = "INTERNET"
  payload_format_version = "2.0"

  # Terraform bug?
  # passthrough_behavior only valid for WEBSOCKET but it detect changes for HTTP
  lifecycle {
    ignore_changes = [passthrough_behavior]
  }
}

resource "aws_apigatewayv2_route" "deno" {
  api_id    = aws_apigatewayv2_api.deno.id
  route_key = "POST /words"
  authorization_type = "NONE"
  target    = "integrations/${aws_apigatewayv2_integration.deno.id}"
}

resource "aws_apigatewayv2_stage" "deno" {
  api_id    = aws_apigatewayv2_api.deno.id
  tags      = var.default_tags
  name      = "$default"
  auto_deploy = "true"

  # Terraform bug
  # https://github.com/terraform-providers/terraform-provider-aws/issues/12893
  lifecycle {
    ignore_changes = [deployment_id, default_route_settings]
  }
}

# By default other AWS resource can not call Lambda function
# It needs to be granted manually by giving lambda:InvokeFunction permission
resource "aws_lambda_permission" "deno" {
  statement_id  = "AllowApiGatewayToInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deno.function_name
  principal     = "apigateway.amazonaws.com"

  # /*/*/* = Any stage / any method / any path
  source_arn    = "${aws_apigatewayv2_api.deno.execution_arn}/*/*/words"
}

locals {
  api_path = split(" ", aws_apigatewayv2_route.deno.route_key)
}

output "deno_api" {
  value = {
    end_point = "POST ${aws_apigatewayv2_api.deno.api_endpoint}${local.api_path[1]}"
  }
}