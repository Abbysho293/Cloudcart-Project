output "vpc_id" { value = aws_vpc.main.id }
output "alb_dns_name" { value = aws_lb.app_alb.dns_name }
output "db_endpoint" { value = aws_db_instance.app_db.address }
