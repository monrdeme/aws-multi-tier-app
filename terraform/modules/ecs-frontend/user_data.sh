# user_data.sh - Frontend ECS EC2 instance user data script

echo ECS_CLUSTER=${ecs_cluster_name} >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config # Enable metadata for task identification
echo ECS_CONTAINER_STOP_TIMEOUT=1m >> /etc/ecs/ecs.config # Give containers 1 minute to stop cleanly
echo ECS_AVAILABLE_LOGGING_DRIVERS='["json-file","awslogs"]' >> /etc/ecs/ecs.config # Enable common log drivers

# Update instance and install necessary packages (like aws-cli if not present, though ECS AMIs usually have it)
yum update -y
yum install -y aws-cli # Ensure AWS CLI is installed for potential future commands

# Start the ECS agent
sudo sysetmctl start ecs
sudo systemctl enable ecs

# Optionally, for debugging, you might want to log user data execution
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1