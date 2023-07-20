

resource "random_pet" "lambda_bucket_name" {
  prefix = "terraform-simple-study"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = random_pet.lambda_bucket_name.id
  force_destroy = true
}

/* resource "aws_s3_bucket" "lambda_demo_study" {
  bucket = aws_s3_bucket.lambda_bucket.id
  force_destroy = true
} */

data "archive_file" "lambda_demo" {
  type = "zip"

  source_dir  = "${path.module}/demo"
  output_path = "${path.module}/demo.zip"
}

resource "aws_s3_object" "lambda_demo" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "demo.zip"
  source = data.archive_file.lambda_demo.output_path

  etag = filemd5(data.archive_file.lambda_demo.output_path)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_function" "demo" {
  function_name = "Demo"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_demo.key

  runtime = "nodejs18.x"
  handler = "demo.handler"

  source_code_hash = data.archive_file.lambda_demo.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "demo" {
  name = "/aws/lambda/${aws_lambda_function.demo.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
  