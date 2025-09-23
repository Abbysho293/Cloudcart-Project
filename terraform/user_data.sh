#!/bin/bash
set -xe

# Install updates, Docker, CloudWatch Agent, and SSM Agent
yum update -y
amazon-linux-extras install docker -y || yum install -y docker
systemctl enable docker && systemctl start docker

# Install AWS CLI v2 if not present
if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install
fi

# Install CloudWatch Agent
rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm || true

# Create CloudWatch Agent config
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CFG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/cloudcart/app",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/lib/docker/containers/*/*-json.log",
            "log_group_name": "/cloudcart/app",
            "log_stream_name": "{instance_id}/docker",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S.%f"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "resources": ["*"],
        "measurement": ["cpu_usage_idle", "cpu_usage_nice", "cpu_usage_system", "cpu_usage_user"]
      },
      "mem": { "resources": ["*"], "measurement": ["mem_used_percent"] }
    }
  }
}
CFG

systemctl enable amazon-cloudwatch-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Pull and run application container
DOCKER_IMAGE="${dockerhub_repo}:latest"
APP_PORT="${app_port}"
DB_HOST="${db_host}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
DB_NAME="${db_name}"
DB_PORT="${db_port}"

# Clean any previous container
docker rm -f cloudcart || true

docker run -d --name cloudcart -p ${APP_PORT}:${APP_PORT} \
  -e PORT=${APP_PORT} \
  -e DB_HOST=${DB_HOST} \
  -e DB_USER=${DB_USER} \
  -e DB_PASSWORD=${DB_PASSWORD} \
  -e DB_NAME=${DB_NAME} \
  -e DB_PORT=${DB_PORT} \
  ${DOCKER_IMAGE}
