# AWS Multi-Tier Application
This repository contains the infrastructure and application code for a robust, multi-tier web application deployed on AWS, built with a strong emphasis on DevSecOps best practices. It serves as a comprehensive example of how to integrate security controls, automation, and observability throughout the entire software development lifecycle, from code commit to production deployment.

---

## Table of Contents

* [Overview](#overview)
* [Architecture](#architecture)
* [Key Features & Technologies](#key-features--technologies)
* [DevSecOps Philosophy](#devsecops-philosophy)
* [Project Directory Structure](#project-directory-structure)
* [Prerequisites](#prerequisites)
* [Deployment Walkthrough](#deployment-walkthrough)
  * [Part 1: Initial AWS Account Setup](#part-1-initial-aws-account-setup)
  * [Part 2: Root Module (Terraform Configuration)](#part-2-root-module-terraform-configuration)
  * [Part 3: VPC Infrastructure](#part-3-vpc-infrastructure)
  * [Part 4: AWS RDS Database Deployment](#part-4-aws-rds-database-deployment)
  * [Part 5: AWS Secrets Manager Deployment](#part-5-aws-secrets-manager-deployment)
  * [Part 6: ECS Frontend Application Deployment](#part-6-ecs-frontend-application-deployment)
  * [Part 7: ECS Backend Application Deployment](#part-7-ecs-backend-application-deployment)
  * [Part 8: Security Logging & Monitoring](#part-8-security-logging--monitoring)
  * [Part 7: Auto-Remediation with AWS Lambda](#part-7-auto-remediation-with-aws-lambda)
  * [Part 8: DevSecOps Pipeline (GitHub Actions CI/CD)](#part-8-devsecops-pipeline-github-actions-cicd)
* [Testing & Verification](#testing--verification)
  * [Verifying Frontend Access](#verifying-frontend-access)
  * [Testing Backend DB Connection via SSM Session Manager](#testing-backend-db-connection-via-ssm-session-manager)
* [Cleanup](#cleanup)
* [Further Enhancements](#further-enhancements)

---

## Overview

This project demonstrates a secure and scalable architecture for a typical web application, comprising:

* **Frontend (Flask):** A simple Python Flask application serving as the user interface.
* **Backend (Flask):** A Python Flask API service handling business logic and interacting with the database.
* **Database (AWS RDS PostgreSQL):** A managed relational database service providing persistent storage.

All infrastructure is defined and managed using Terraform, ensuring consistency, repeatability, and version control.

---

## Architecture Diagram

[![Multi-Tier-Architecture-Diagram-drawio.png](https://i.postimg.cc/X7Skv6DW/Multi-Tier-Architecture-Diagram-drawio.png)](https://postimg.cc/14BqW2Q7)

---

## Key Features & Technologies

* **Multi-Tier Architecture:** Frontend and Backend applications decoupled and deployed on separate ECS services within private subnets.
* **Containerization (Docker & Amazon ECS):** Applications are containerized and orchestrated using Amazon Elastic Container Service (ECS) with EC2 launch type.
* **Load Balancing (AWS Application Load Balancers):**
    * **Public ALB:** For external user access to the Frontend.
    * **Internal ALB:** For secure, internal communication between the Frontend and Backend.
* **Networking (AWS VPC):** Secure and isolated network environment configured with public, private application, and private database subnets, along with scoped Security Groups to enforce least-privilege access.
* **Database Management (AWS RDS PostgreSQL):** Secure and scalable managed database service.
* **Infrastructure as Code (Terraform):** Complete AWS infrastructure provisioning and management using Terraform modules.
* **DevSecOps Pipeline (GitHub Actions):** Automated CI/CD pipeline leveraging GitHub Actions for:
    * **Build:** Docker image creation.
    * **Security Scanning:**
        * **Trivy:** Container image vulnerability scanning.
        * **Bandit:** Static Application Security Testing (SAST) for Python code.
        * **Checkov:** Infrastructure as Code (IaC) static analysis for Terraform.
    * **Deployment:** Automated deployment to Amazon ECS.
* **Security & Monitoring:**
    * **AWS Secrets Manager:** Secure storage and retrieval of sensitive application credentials (e.g., database passwords).
    * **AWS GuardDuty:** Intelligent threat detection.
    * **AWS Security Hub:** Centralized security posture management and compliance checks.
    * **AWS CloudTrail:** API activity logging for auditing and governance.
    * **AWS Lambda for Auto-Remediation:** Automated response to security findings (e.g., stopping and terminating non-compliant instances).
    * **SSM Session Manager:** Secure, auditable access to EC2 instances without SSH keys or bastion hosts.

---

## DevSecOps Philosophy

This project encompasses a "security-first" mindset, integrating automated security testing and monitoring at every stage of the development and deployment pipeline. By shifting security "left," we aim to identify and remediate vulnerabilities early, reducing risk and improving the overall security posture of the application and its infrastructure.

---

## Project Directory Structure


```
├── .github/
│   └── workflows/
│       └── main.yml           # GitHub Actions workflow for CI/CD
├── app/
│   ├── frontend-app/
│   │   ├── app.py             # Flask app for presentation layer
│   │   ├── Dockerfile         # Dockerfile for frontend application
│   │   └── requirements.txt   # Python dependencies for frontend
│   ├── backend-app/
│   │   ├── app.py             # Flask app for application layer
│   │   ├── Dockerfile         # Dockerfile for backend application
│   │   └── requirements.txt   # Python dependencies for backend
├── terraform/
│   ├── root/                    # Root module for the entire infrastructure deployment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── modules/
│   │   ├── vpc/                 # VPC module for network infrastructure
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── rds/                 # RDS module for PostgreSQL database
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── secrets-manager/     # Secrets Manager module (for DB credentials)
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── ecs-frontend/        # ECS Frontend (Public) module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── user_data.sh
│   │   │   └── task-definition.json
│   │   ├── ecs-backend/         # ECS Backend (Private) module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── user_data.sh
│   │   │   └── task-definition.json
│   │   ├── cloudwatch-logs/     # CloudWatch Logs module for centralized logging
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── security-monitoring/ # Central security services module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── auto-remediation/    # Auto-remediation Lambda module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── lambda_function_code/ # Lambda function Python code
│   │   │       └── main.py
```

---

## Prerequisites

To explore or deploy this project, you will need:

* An AWS Account
* Terraform installed (v1.3+ recommended)
* Python 3.8+ with boto3 installed
* Docker Desktop installed
* Git installed
* GitHub Repository set up and linked locally
* AWS CLI configured with appropriate permissions

---

## Deployment Walkthrough

This section provides a step-by-step guide to deploying the entire AWS multi-tier application infrastructure and services using Terraform and automating the application deployment with GitHub Actions. Each part represents a logical grouping of infrastructure components.

### Part 1: Initial AWS Account Setup

**Purpose**: Before provisioning infrastructure with Terraform, it’s essential to establish a reliable and centralized mechanism for managing state. This ensures that infrastructure deployments are consistent, auditable, and safe from race conditions or conflicting changes across teams and environments.

**1. Create an S3 Bucket for Terraform State**:
- Manually create a unique S3 bucket in your AWS account.
- Enable Versioning on this bucket to keep a history of your Terraform state.
- (Optional but Recommended) Enable Server-Side Encryption (SSE-S3) for state file at rest.
- (Optional) Implement Bucket Policies to restrict access.

**2. Create a DynamoDB Table for Terraform State Locking**:
- Manually create a DynamoDB table with a primary key LockID (String type).
- This table is used by Terraform to acquire a lock on the state file during terraform apply operations, preventing multiple users or processes from concurrently modifying the state, which can lead to corruption.

---

### Part 2: Root Module (Terraform Configuration)

**Purpose**: The root module serves as the entry point for the Terraform configuration and defines the overall infrastructure layout. This is where key resources are declared, modules are called, and environment-specific variables are initialized. By configuring the root module, we establish the foundational components needed to provision and manage the infrastructure using Terraform.

- **[main.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/root/main.tf)**: The primary configuration file for the entire deployment. This is where you instantiate and configure the child modules, define any top-level resources, and set up the Terraform backend for state management.

- **[variables.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/root/variables.tf)**: Declares all input variables for the root module, allowing for flexible and parameterized deployments across environments.

- **[outputs.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/root/outputs.tf)**: Defines output values that represent important information about your deployed infrastructure, such as public load balancer DNS names or database endpoints, which can be used by other systems or for verification.

- **[versions.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/root/versions.tf)**: Specifies the required Terraform CLI version and the required versions for all AWS provider plugins used in the project. This ensures consistent behavior across different deployment environments and team members.

---

### Part 3: VPC Infrastructure

**Purpose**: To establish the secure and isolated network environment, providing a foundation for all subsequent application and service deployments.

- **[main.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/vpc/main.tf)**: Defines the core VPC, public and private subnets, NAT Gateways, Internet Gateway, route tables, and security groups that establish the network topology.

- **[variables.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/vpc/variables.tf)**: Declares input variables specific to the VPC configuration, such as CIDR blocks, availability zones, and naming conventions.

- **[outputs.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/vpc/outputs.tf)**: Exposes VPC-related outputs like VPC ID, subnet IDs, and security group IDs, which are consumed by other modules.

---

### Part 4: AWS RDS Database Deployment

**Purpose**: To provision a managed PostgreSQL database instance in private database subnets, ensuring secure and scalable storage for application data.

- **[main.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/rds/main.tf)**: Defines the database instance, database subnet group, and the necessary security group rules to control access to the database.

- **[variables.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/rds/variables.tf)**: Declares input variables for the RDS instance, such as instance type, allocated storage, database name, and master username.

-  **[outputs.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/rds/outputs.tf)**: Exports the ARN of the created secret, allowing other modules (like ECS) to grant access to it.

---

### Part 5: AWS Secrets Manager Deployment

**Purpose**: To securely manage sensitive application credentials, such as database passwords, by integrating with AWS Secrets Manager, ensuring that secrets are not hardcoded and can be rotated automatically.

- **[main.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/secrets-manager/main.tf)**: Defines the AWS Secrets Manager secret resource, which stores sensitive information like database credentials securely. It also sets up policies to allow specific IAM roles (e.g., ECS task roles) to retrieve these secrets.

- **[variables.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/secrets-manager/variables.tf)**: Declares variables for the secret's name, description, and any initial secret string.

- **[outputs.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/secrets-manager/outputs.tf)**: Exports the ARN of the created secret, allowing other modules (like ECS services) to reference and grant access to it.

---

### Part 6: ECS Frontend Application Deployment

**Purpose**: To provision the public-facing Amazon ECS service for the frontend application, including its Application Load Balancer, underlying compute capacity via EC2 instances (Auto Scaling Group), and the ECS task definition. This makes the user interface accessible to the internet.

- **[main.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-frontend/main.tf)**: Defines the ECS cluster, public Application Load Balancer (ALB), target group, ECS service, and ECS task definition for the frontend application. It also configures listener rules and health checks.

- **[variables.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-frontend/variables.tf)**: Declares input variables such as Docker image tag, desired task count, port mappings, and ALB settings.

- **[outputs.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-frontend/outputs.tf)**: Exposes frontend-related outputs like the Public ALB DNS name and the ECS cluster ARN, necessary for accessing the application.

- **[user_data.sh](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-frontend/user_data.sh)**: A shell script executed when ECS EC2 instances launch, used for installing Docker, configuring the ECS agent, and performing other necessary instance setup for the frontend.

- **[task-definition.json](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-frontend/task-definition.json)**: A template or direct definition for the ECS task definition, specifying container images, CPU, memory, environment variables, and logging configurations for the frontend.

---

### Part 7: ECS Backend Application Deployment

**Purpose**: To provision the internal-facing Amazon ECS service for the backend application, including its internal Application Load Balancer, underlying compute capacity via EC2 instances (Auto Scaling Group), and the ECS task definition. This service handles business logic and database interactions.

- **[main.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-backend/main.tf)**: Defines the internal Application Load Balancer (ALB), target group, ECS service, and ECS task definition for the backend application. It also includes necessary security group rules for database access.

- **[variables.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-backend/variables.tf)**: Declares input variables such as Docker image tag, desired task count, and references to database connection details (Sourced from Secrets Manager).

- **[outputs.tf](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-backend/outputs.tf)**: Exposes backend-related outputs like the Internal ALB DNS name and the ECS cluster ARN.

- **[user_data.sh](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-backend/user_data.sh)**: A shell script executed when ECS EC2 instances launch, similar to the frontend's, but for backend-specific setup and configuration.

- **[task-definition.json](https://github.com/monrdeme/aws-multi-tier-app/blob/main/terraform/modules/ecs-backend/task-definition.json)**: A template or direct definition for the ECS task definition, specifying backend container images, CPU, memory, environment variables (Including those passed from Secrets Manager), and logging.

### Part 8: Security Logging & Monitoring














