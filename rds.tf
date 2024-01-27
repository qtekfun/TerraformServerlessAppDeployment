resource "aws_db_instance" "my_db_instance" {
  identifier          = "mydbinstance"
  engine              = "mysql"
  instance_class      = "db.t2.micro"
  allocated_storage   = 20
  username            = "admin"
  password            = "mysecretpassword"
  db_name             = "mydatabase"
  publicly_accessible = true
  skip_final_snapshot = true
}