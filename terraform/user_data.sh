#!/bin/bash
set -xe

# -------------------------------
# System Setup
# -------------------------------
yum update -y
yum install -y unzip jq awscli

# Install Docker
amazon-linux-extras install docker -y || yum install -y docker
systemctl enable docker && systemctl start docker

# Install AWS CLI v2 if not present
if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install
fi

# -------------------------------
# CloudWatch Agent Setup
# -------------------------------
rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm || true

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CFG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/cloudcart/app",
            "log_stream_name": "$${aws:InstanceId}/messages"
          },
          {
            "file_path": "/var/lib/docker/containers/*/*-json.log",
            "log_group_name": "/cloudcart/app",
            "log_stream_name": "$${aws:InstanceId}/docker",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S.%f"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "resources": ["*"],
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_nice",
          "cpu_usage_system",
          "cpu_usage_user"
        ]
      },
      "mem": {
        "resources": ["*"],
        "measurement": ["mem_used_percent"]
      }
    }
  }
}
CFG

systemctl enable amazon-cloudwatch-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# -------------------------------
# Retrieve DB Password Securely
# -------------------------------
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id $${db_secret_name} \
  --query 'SecretString' \
  --output text | jq -r '.password')

# -------------------------------
# Run Application Container
# -------------------------------
docker rm -f cloudcart || true

docker run -d --name cloudcart -p ${app_port}:${app_port} \
  -e PORT=${app_port} \
  -e DB_HOST=${db_host} \
  -e DB_USER=${db_user} \
  -e DB_PASSWORD="$${DB_PASSWORD}" \
  -e DB_NAME=${db_name} \
  -e DB_PORT=${db_port} \
  ${dockerhub_repo}:latest
