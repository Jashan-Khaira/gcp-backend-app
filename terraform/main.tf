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
