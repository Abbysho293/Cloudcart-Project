# CloudCart – Scalable Web App on AWS (IaC + CI/CD)

This project is a complete, hands‑on solution for deploying a highly available web application on AWS using Terraform, Docker, and GitHub Actions.

## What you get
- **Architecture Diagram** (`architecture.png`)
- **Terraform** to provision:
  - VPC with public & private subnets across 2 AZs
  - Internet Gateway (IGW) & NAT Gateway
  - Security groups for ALB, App, and DB
  - Application Load Balancer (ALB) + Target Group + Listener (HTTP 80)
  - Launch Template + Auto Scaling Group (ASG) for EC2 instances
  - Amazon RDS (PostgreSQL) in private subnets
  - CloudWatch Log Group + CPU Alarm (>70% for 5 mins)
- **Sample Node.js app** in `app/` with a simple health endpoint
- **Dockerfile** to containerize the app
- **GitHub Actions pipeline** to build and push Docker images to Docker Hub

---

## Prerequisites
- AWS account + IAM user with permissions for VPC/EC2/ALB/IAM/CloudWatch/RDS/Autoscaling.
- Terraform v1.5+
- Docker
- GitHub repository (where you’ll push this code).
- **Docker Hub** account for storing images.

---

## Secrets & Config (GitHub Actions)
Create these GitHub **Repository Secrets** (Settings → Secrets and variables → Actions → New repository secret):

- `DOCKERHUB_USERNAME` – your Docker Hub username
- `DOCKERHUB_TOKEN` – Docker Hub access token / password
- `AWS_ACCESS_KEY_ID` – your AWS key
- `AWS_SECRET_ACCESS_KEY` – your AWS secret
- (Optional) `AWS_REGION` – defaults to `us-east-1` if not set

---

## Terraform Variables
Edit `terraform/variables.tf` or create `terraform/terraform.tfvars` file with values:

```hcl
aws_region            = "us-east-1"
project_name          = "cloudcart"
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24"]

db_username           = "cloudcart"
db_password           = "ChangeMeStrong!123"
db_instance_class     = "db.t3.micro"
db_allocated_storage  = 20
db_multi_az           = false

app_port              = 3000
desired_capacity      = 2
min_size              = 1
max_size              = 3
dockerhub_repo        = "YOUR_DOCKERHUB_USERNAME/cloudcart-app"
```

> **Note:** The EC2 user data will pull the Docker image `dockerhub_repo:latest` and run it.
> The app reads DB settings from environment variables injected by user data.

Create a `terraform/terraform.tfvars` quickly:

```hcl
dockerhub_repo = "YOUR_DOCKERHUB_USERNAME/cloudcart-app"
db_password    = "REPLACE_ME_STRONG_PASSWORD"
```

---

## Deploy Steps

1. **Build & push the image** (or let CI/CD do it on push to `main`):
   ```bash
   cd app
   docker build -t YOUR_DOCKERHUB_USERNAME/cloudcart-app:latest .
   docker login -u YOUR_DOCKERHUB_USERNAME
   docker push YOUR_DOCKERHUB_USERNAME/cloudcart-app:latest
   ```

2. **Provision infrastructure with Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform plan -out tfplan
   terraform apply tfplan
   ```

3. **Find your ALB DNS name** (output `alb_dns_name`) and open it in a browser:
   - Health endpoint: `http://ALB_DNS_NAME/health`

4. **Tear down** (when done to avoid charges):
   ```bash
   cd terraform
   terraform destroy
   ```

---

## Monitoring & Logging
- CloudWatch **Log Group**: `/cloudcart/app`
- CloudWatch **Alarm**: Average CPUUtilization of ASG > 70% for 5 minutes (sends default alarm action – you can attach SNS topic or email later).
- EC2 instances are configured to run **CloudWatch Agent** and publish system & Docker logs.

---

## Notes
- The RDS endpoint is injected into the app via environment variables in EC2 user data.
- NAT Gateway enables private instances to pull Docker images & OS updates.
- For production, consider using:
  - HTTPS on ALB with ACM certificates
  - Secrets Manager or SSM Parameter Store for DB credentials
  - Multi-AZ for RDS
  - Private Docker registry / ECR

Happy shipping 🚀
