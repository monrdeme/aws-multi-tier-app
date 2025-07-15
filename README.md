# Building a Multi-Tier Architecture Containerized Web Application on AWS with CI/CD pipeline
This repository contains the infrastructure and application code for a robust, multi-tier web application deployed on AWS, built with a strong emphasis on DevSecOps best practices. It serves as a comprehensive example of how to integrate security controls, automation, and observability throughout the entire software development lifecycle, from code commit to production deployment.

---

## Overview

This project demonstrates a secure and scalable architecture for a typical web application, comprising:

* **Frontend (Flask):** A simple Python Flask application serving as the user interface.
* **Backend (Flask):** A Python Flask API service handling business logic and interacting with the database.
* **Database (AWS RDS PostgreSQL):** A managed relational database service providing persistent storage.

All infrastructure is defined and managed using Terraform, ensuring consistency, repeatability, and version control.

---

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
    * **AWS Lambda for Auto-Remediation:** Automated response to security findings (e.g., stopping non-compliant instances).
    * **SSM Session Manager:** Secure, auditable access to EC2 instances without SSH keys or bastion hosts.

## DevSecOps Philosophy

This project champions a "security-first" mindset, integrating automated security testing and monitoring at every stage of the development and deployment pipeline. By shifting security "left," we aim to identify and remediate vulnerabilities early, reducing risk and improving the overall security posture of the application and its infrastructure.

## Getting Started

To explore or deploy this project, you will need:

* An AWS Account
* A GitHub Account
* Terraform CLI installed
* Docker Desktop installed
* AWS CLI configured with appropriate permissions
