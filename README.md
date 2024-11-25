# GCP Backend Application Deployment using Terraform
The process of deploying a Flask backend application on Google Cloud Platform (GCP) using Terraform, Docker, and Cloud Build.

## Prerequisites

- GCP Account with project ID: `eng-oven-435418-i5`
- Terraform installed
- Docker installed
- Google Cloud SDK installed
- Visual Studio Code (or any preferred code editor)
- Ubuntu WSL (for local Docker image building)

## Project Structure

```

├── Dockerfile
├── app.py
├── cloudbuild.yaml
├── index.html
├── requirements.txt
├── main.tf
├── variables.tf
└── outputs.tf
```

## Step 1: Configure the Backend Application

1. Create a `Dockerfile` for the Flask application:

```dockerfile
# Use an official Python runtime as the base image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy application code to the container
COPY app.py /app

# Install required dependencies
RUN pip install flask flask-cors

# Expose the Cloud Run default port
EXPOSE 5000

# Command to run the application
CMD ["python", "app.py"]
```

2. Create a `requirements.txt` file:

```
Flask==2.0.1
Flask-CORS==3.0.10
Werkzeug==2.0.1
```

3. Ensure your `app.py` contains the Flask application code.
```py
from flask import Flask, jsonify
from flask_cors import CORS

app =  Flask(__name__)

CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/')
def hello():
    return jsonify({"message": "Hello from the Backend!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```


## Step 2: Build and Push Docker Image

1. Open Ubuntu WSL and navigate to your project directory.
2. Build the Docker image:
   ```
   docker build -t jashan-backend:v1 .
   ```
3. Tag the image for GCP Artifact Registry:
   ```
   docker tag jashan-backend:v1 us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:v1
   ```
4. Push the image to GCP Artifact Registry:
   ```
   docker push us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:v1
   ```

## Step 3: Set Up Terraform

1. Create `main.tf`, `variables.tf`, and `outputs.tf` files in your project directory.

- **main.tf**

```tf
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Service Account
resource "google_service_account" "jashan_vm_sa" {
  account_id   = "jashan-vm-sa"
  display_name = "Service Account for Jashan Backend VM"
}

# IAM Permissions
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "secret_manager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}


resource "google_project_iam_member" "compute_os_login" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

# Logs Writer Role
resource "google_project_iam_member" "logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "iap_admin" {
  project = var.project_id
  role    = "roles/iap.admin"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "iap_tunnel_user" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}

resource "google_project_iam_member" "compute_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${google_service_account.jashan_vm_sa.email}"
}


# Network Resources
resource "google_compute_network" "jashan_vpc" {
  name = var.network_name
}

resource "google_compute_subnetwork" "jashan_public_subnet" {
  name          = var.public_subnet_name
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.jashan_vpc.id
  region        = var.region
}

resource "google_compute_subnetwork" "jashan_private_subnet" {
  name          = var.private_subnet_name
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.jashan_vpc.id
  region        = var.region
  private_ip_google_access = true
}

# Compute Instance
resource "google_compute_instance" "jashan_backend_vm" {
  name         = "jashan-backend-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.jashan_vpc.name
    subnetwork = google_compute_subnetwork.jashan_private_subnet.name
    access_config {}
  }

  metadata = {
    "startup-script" = <<-EOT
#!/usr/bin/env bash
set -e
exec > /var/log/startup-script.log 2>&1

# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $(whoami)

# Install gcloud CLI
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-412.0.0-linux-x86_64.tar.gz
tar -xzvf google-cloud-sdk-412.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh -q
echo 'export PATH=$PATH:/root/google-cloud-sdk/bin' >> /etc/profile
source /etc/profile

# Authenticate with Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

# Pull and run Docker container
docker pull us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:v1
docker run -d -p 5000:5000 us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:v1
EOT
  }

  service_account {
    email  = google_service_account.jashan_vm_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["allow-flask", "allow-ssh"]
}

# Firewall Rule to allow SSH and external access to port 5000
resource "google_compute_firewall" "allow_ssh_and_flask" {
  name    = "allow-ssh-and-flask"
  network = google_compute_network.jashan_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "5000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-flask", "allow-ssh"]
}

resource "google_compute_firewall" "allow_iap_tunneling" {
  name    = "allow-iap-tunneling"
  network = "jashan-vpc"  # Replace with your network name if different

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # IAP's IP range
}

# Internet Gateway
resource "google_compute_router" "jashan_router" {
  name    = "jashan-router"
  region  = var.region
  network = google_compute_network.jashan_vpc.name
}

resource "google_compute_router_nat" "jashan_nat" {
  name   = "jashan-nat"
  router = google_compute_router.jashan_router.name
  region = var.region

  nat_ip_allocate_option           = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

```
- **variables.tf**
```tf
# Project ID for GCP
variable "project_id" {
  description = "GCP Project ID"
  default     = "eng-oven-435418-i5"
}

# Region for the resources
variable "region" {
  description = "GCP Region"
  default     = "us-central1"
}

# Zone for the resources
variable "zone" {
  description = "GCP Zone"
  default     = "us-central1-a"
}

# Name for the VPC Network
variable "network_name" {
  description = "Name of the VPC"
  default     = "jashan-vpc"
}

# Name for the private subnet
variable "private_subnet_name" {
  description = "Name of the private subnet"
  default     = "jashan-private-subnet"
}

# Name for the public subnet
variable "public_subnet_name" {
  description = "Name of the public subnet"
  default     = "jashan-public-subnet"
}

# Docker Image name stored in Artifact Registry
variable "image_name" {
  description = "Artifact Registry Docker Image name"
  default     = "us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:v1"
}

```
- **outputs.tf**
```tf
output "instance_ip" {
  value = google_compute_instance.jashan_backend_vm.network_interface[0].access_config[0].nat_ip
}

output "vpc_name" {
  value = google_compute_network.jashan_vpc.name
}

```
3. Copy the provided Terraform configurations into these files.

## Step 4: Deploy Infrastructure

1. Initialize Terraform:
   ```
   terraform init
   ```
2. Plan the deployment:
   ```
   terraform plan
   ```
3. Apply the configuration:
   ```
   terraform apply --auto-approve
   ```

 ## Step 5: Create Secrets in Secret Manager
 1. Navigate to the Secret Manager in the GCP Console.
 2. Click "Create Secret".
 3. Provide a name for the secret, such as `SSH_Private_KEY` and `SSH_Public_KEY`.
 4. Add the SSH private key.
 5. Click "Create".  

## Step 5: Set Up Cloud Build

1. Create a `cloudbuild.yaml` file in your GitHub repository:

```yaml
steps:
  # Step 0: Configure docker to use gcloud credentials
  - name: 'gcr.io/cloud-builders/gcloud'
    args: ['auth', 'configure-docker', 'us-central1-docker.pkg.dev']

  # Step 1: Build the container image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:${SHORT_SHA}', '.']

  # Step 2: Push the container image to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:${SHORT_SHA}']

   # Step 3: SSH into Compute Engine and update the container
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    secretEnv: ['PRIVATE_KEY', 'PUBLIC_KEY']
    args:
      - '-c'
      - |
        # Setup SSH keys
        echo "$$PRIVATE_KEY" | base64 -d > /workspace/id_rsa
        echo "$$PUBLIC_KEY" | base64 -d > /workspace/id_rsa.pub
        chmod 600 /workspace/id_rsa
        chmod 644 /workspace/id_rsa.pub
        
        # Setup SSH configuration
        mkdir -p ~/.ssh
        
        # Add VM to known hosts using hostname
        ssh-keyscan -H 34.170.177.119 >> ~/.ssh/known_hosts
        
        echo "Updating backend container on Compute Engine..."
        gcloud compute ssh cybersamurai0627@jashan-backend-vm \
          --zone=us-central1-a \
          --ssh-key-file=/workspace/id_rsa \
          --strict-host-key-checking=no \
          --project=eng-oven-435418-i5 \
          --tunnel-through-iap \
          --command="sudo gcloud auth configure-docker us-central1-docker.pkg.dev && \
                     sudo docker stop recursing_kalam || true && \
                     sudo docker rm recursing_kalam || true && \
                     sudo docker pull us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:${SHORT_SHA} && \
                     sudo docker run -d -p 5000:5000 --name jashan-backend us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:${SHORT_SHA}"

availableSecrets:
  secretManager:
    - versionName: projects/851164891096/secrets/my-ssh-private-key/versions/1
      env: 'PRIVATE_KEY'
    - versionName: projects/851164891096/secrets/my-public-ssh-key/versions/1
      env: 'PUBLIC_KEY'

images:
  - 'us-central1-docker.pkg.dev/eng-oven-435418-i5/jashan-backend-repo/jashan-backend:${SHORT_SHA}'

options:
  logging: CLOUD_LOGGING_ONLY
```

2. Set up a Cloud Build trigger connected to your GitHub repository.

## Step 6: Verify Deployment

1. Access the deployed application using the instance IP output by Terraform.
2. Verify that the Flask application is running and accessible.

## Continuous Deployment

Any changes pushed to the GitHub repository will automatically trigger Cloud Build, updating the container image running on the `jashan-backend-vm`.

## Troubleshooting

- If you encounter issues accessing the VM, ensure that the IAP tunneling firewall rule is correctly configured.
- Check the VM's startup script logs for any errors during container deployment.

## Security Considerations

- The current setup allows external access to port 5000. Consider restricting this in production environments.
- Ensure that all sensitive information is stored securely, preferably using GCP Secret Manager.

By following these steps, you should have a fully functional Flask backend application deployed on GCP, with automatic updates triggered by changes to your GitHub repository.



