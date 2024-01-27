resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "ddb_table"
  hash_key       = "word"
  range_key      = "times"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "word"
    type = "S"
  }
  attribute {
    name = "times"
    type = "N"
  }
}