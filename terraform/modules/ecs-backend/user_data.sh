#!/bin/bash

# Write the ECS config file
cat << EOF |sudo tee "etc/ecs/ecs.config" > /dev/null
ECS_CLUSTER=${ecs_cluster_name}
ECS_ENABLE_CONTAINER_METADATA=true
ECS_CONTAINER_STOP_TIMEOUT=1m
ECS_AVAILABLE_LOGGING_DRIVERS='["json-file","awslogs"]'
EOF

# Update instance and install necessary packages
yum update -y
yum install -y aws-cli

# Enable and start the ECS agent
sudo systemctl enable --now --no-block ecs

# Optionally, for debugging, you might want to log user data execution
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1