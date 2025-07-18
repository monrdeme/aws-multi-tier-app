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
  * [Part 3: Core VPC Infrastructure](#part-3-core-vpc-infrastructure)
  * [Part 4: AWS RDS Database Deployment](#part-4-aws-rds-database-deployment)
  * [Part 5: ECS Cluster & Application Services (Frontend & Backend)](#part-5-ecs-cluster--application-services-frontend--backend)
  * [Part 6: AWS Security Services Integration (GuardDuty, Security Hub, CloudTrail)](#part-6-aws-security-services-integration-guardduty-security-hub-cloudtrail)
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







