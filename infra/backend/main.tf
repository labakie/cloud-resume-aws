# create dynamodb table
resource "aws_dynamodb_table" "visitor_counter" {
  name         = "VisitorCounterTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# create dynamodb table item
resource "aws_dynamodb_table_item" "table_item" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = <<ITEM
{
  "id": {"S": "counter"},
  "visitor": {"N": "1"}
}
ITEM

  # enable after initial apply to prevent visitor counts going back to 1
  # lifecycle {
  #   ignore_changes = [
  #     item
  #   ]
  # }
}

# get current aws region
data "aws_region" "current" {}

# get current account id
data "aws_caller_identity" "current" {}

# create policy
resource "aws_iam_policy" "custom_policy" {
  name        = "LambdaAccessVisitorCounterTable"
  description = "Policy for get, put, update item in visitor counter table at DynamoDB and enable log."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Statement1",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Resource" : [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.visitor_counter.name}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/VisitorCounterFunction:*"
        ]
      }
    ]
  })
}

# create role
resource "aws_iam_role" "custom_role" {
  name        = "VisitorCounterRole"
  description = "Allows Lambda functions to call DynamoDB on your behalf."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# assign created policy to role
resource "aws_iam_role_policy_attachment" "custom_attachment" {
  role       = aws_iam_role.custom_role.name
  policy_arn = aws_iam_policy.custom_policy.arn
}

# archive python file to zip
data "archive_file" "python" {
  type        = "zip"
  source_file = "../../function/lambda_function.py"
  output_path = "../../function/lambda_function.zip"
}

# create lambda function
resource "aws_lambda_function" "python_lambda" {
  filename      = "../../function/lambda_function.zip"
  function_name = "VisitorCounterFunction"
  role          = aws_iam_role.custom_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
}

# create HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "VisitorCounterAPI"
  protocol_type = "HTTP"
}

# integrate lambda function with HTTP API
resource "aws_apigatewayv2_integration" "lambda_apigateway" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  description      = "Lambda integration with HTTP API"
  integration_uri  = aws_lambda_function.python_lambda.invoke_arn
}

# create auto deploy dev stage 
resource "aws_apigatewayv2_stage" "prod_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "prod"
  auto_deploy = true
}

# set route with GET method
resource "aws_apigatewayv2_route" "custom_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /visitor-counter"
  target = "integrations/${aws_apigatewayv2_integration.lambda_apigateway.id}"
}

# attach permission for HTTP API to execute lambda function
resource "aws_lambda_permission" "lambda_apigateway_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.python_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowExecuteLambda"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# show API Gateway invoke URL in terminal
output "api_invoke_url" {
  value = "${aws_apigatewayv2_stage.dev_stage.invoke_url}/visitor-counter"
}
