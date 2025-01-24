# Alloy Infra Project - README

## Overview
This project demonstrates an infrastructure setup using Terraform and Terragrunt. The infrastructure showcases scalability through an Auto Scaling Group (ASG), an Application Load Balancer (ALB), Amazon RDS, and Amazon SQS. Additionally, it includes a Node.js API that interacts with these AWS services to demonstrate scalability.

## Prerequisites

1. **Terragrunt and Terraform**:
   - Ensure that `terragrunt` and `terraform` are installed on your system.
   - Change the /infra/account.hcl account ID to the root terragrunt.hcl validation pass in different account.

2. **AWS Credentials**:
   - Export valid AWS credentials in your environment.
   - Example:
     ```bash
     export AWS_ACCESS_KEY_ID="your-access-key-id"
     export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
     ```

3. **Node.js**:
   - The API requires Node.js and npm installed for development or troubleshooting purposes.

## Directory Structure

The project follows a modular approach, and the directory structure is as follows:

```
alloy-infra-live/
|└── infra/
    |└── production/
        |└── env.hcl
        |└── us-east-1/
            |├── region.hcl
            |└── services/
                |├── service.hcl
                |└── alloy/
                    |├── terragrunt.hcl
|└── modules/
    |├── aws/
        |└── backend-asg/
            | └── user-data/
    |├── rds/
    |└── sqs/
```

### Key Components
- **`infra/production/us-east-1/services/alloy/terragrunt.hcl`**:
  - This is the main entry point to apply the infrastructure.

- **`modules/aws/backend-asg`**:
  - Contains the logic for the Auto Scaling Group and associated configurations like Launch Templates.

- **`modules/aws/rds`**:
  - Defines the RDS database instance configuration.

- **`modules/aws/sqs`**:
  - Manages the Amazon SQS queue setup.

## How to Apply the Infrastructure

Navigate to the service folder and run Terragrunt:

```bash
cd infra/production/us-east-1/services/alloy/
terragrunt apply
```

This command initializes and applies the Terraform configurations defined for the Alloy service.

## Node.js API

### Purpose
The API demonstrates the scalability of the infrastructure by interacting with AWS services (SQS and RDS).

### Routes
1. **`/`**:
   - Displays an HTML page with three buttons for interacting with SQS and RDS.

2. **`/send`**:
   - Sends a message to the SQS queue to simulate scaling out.

3. **`/consume`**:
   - Consumes a message from the SQS queue to simulate scaling in.

4. **`/dbtest`**:
   - Tests connectivity to the RDS instance and ensures the database is operational by creating a simple table.

### API Deployment

The API is configured using a systemd service for persistent execution:

```bash
sudo systemctl start demoapp.service
sudo systemctl enable demoapp.service
```

The API listens on port 80 and can be accessed via the Load Balancer URL.

### Environment Variables
Environment variables are set dynamically during deployment:

- **`SQS_URL`**: The URL of the Amazon SQS queue.
- **`DB_HOST`**: The endpoint of the RDS instance.

These variables are exported in `/etc/environment` for use by the API.

## Modules Overview

1. **Auto Scaling Group (ASG)**:
   - Automatically scales the EC2 instances based on load.
   - Integrated with ALB for load balancing and SQS for scaling triggers.

2. **Application Load Balancer (ALB)**:
   - Distributes traffic to the ASG instances.

3. **RDS Module**:
   - Provisions a PostgreSQL database instance.

4. **SQS Module**:
   - Sets up an SQS queue for managing workload distribution.

5. **User Data**:
   - Configures EC2 instances with necessary software and the Node.js application during launch.

## Testing the API

1. **Access the API**:
   - Use the Load Balancer DNS to access the API, e.g., `http://<load-balancer-dns>/`.

2. **Simulate Scaling**:
   - **Send Message**:
     ```bash
     curl http://<load-balancer-dns>/send
     ```
   - **Consume Message**:
     ```bash
     curl http://<load-balancer-dns>/consume
     ```

3. **Test RDS**:
   - Validate database connectivity:
     ```bash
     curl http://<load-balancer-dns>/dbtest
     ```

## Notes
- The project uses Terragrunt to manage Terraform configurations, enabling efficient multi-environment and modular deployments.
- The Node.js API demonstrates how a scalable architecture integrates with AWS services.
- Ensure proper IAM permissions are in place for the API to interact with SQS and RDS.
- Change the /infra/account.hcl account ID to the root terragrunt.hcl validation pass in different account.
