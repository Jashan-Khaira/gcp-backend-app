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

