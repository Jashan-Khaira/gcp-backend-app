# Flask Backend and Frontend Application Deployment on GCP using Terraform

This repository contains the code and configuration files for deploying the Flask backend application and its corresponding frontend. The frontend page allows users to fetch backend data with a simple button click, displaying the data seamlessly on the frontend.

## Overview

In this lab, we use Terraform to deploy GCP infrastructure resources to support the Flask backend application. The deployment process includes the following stages:

### Pre-Deployment
- **Create a Python Docker Image**: Build a Docker image based on the Lab 4 Python backend code and store it in a registry (such as GCP Container Registry, AWS ECR, Docker Hub, etc.).

### Script Deployment
- **Create a VPC**: Set up a Virtual Private Cloud (VPC) to host the infrastructure.
- **Create Subnets**: Define and create both private and public subnets within the VPC.
- **Add a Compute Engine Instance**: Deploy a compute engine instance to host the Flask application container.
  - **Container Deployment**: Ensure the Docker container is part of the instance.
  - **Add Firewall Rules**: Configure firewall rules to allow traffic on the application port.
  - **Public IP**: Assign a public IP address to the instance for external access.

### Post-Deployment
- **Create a Cloud Build Workflow**: Configure a Cloud Build workflow to automate the building of the Python Docker image and update the container/compute engine on GCP deployment.

## Getting Started

### Prerequisites
- **GCP Account**: Ensure you have an active Google Cloud Platform account.
- **Terraform**: Install Terraform on your local machine.
- **Docker**: Install Docker to build and manage containers.

### Setup Instructions

1. **Clone the Repository**
    ```sh
    git clone https://github.com/yourusername/lab4-deployment.git
    cd lab4-deployment
    ```

2. **Pre-Deployment Steps**
    - **Build Docker Image**:
        ```sh
        docker build -t your-image-name:latest .
        docker tag your-image-name:latest your-registry-url/your-image-name:latest
        docker push your-registry-url/your-image-name:latest
        ```

3. **Deploying Infrastructure Using Terraform**
    - Initialize Terraform:
        ```sh
        terraform init
        ```
    - Apply Terraform Configuration:
        ```sh
        terraform apply
        ```

4. **Post-Deployment Setup**
    - Configure and deploy the Cloud Build workflow to automate updates.

### Usage
- Access the frontend application via the public IP assigned to your compute engine instance.
- Click the "Fetch Backend Data" button to retrieve and display data from the Flask backend.


