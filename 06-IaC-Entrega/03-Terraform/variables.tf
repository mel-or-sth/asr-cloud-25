variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default     = "europe-west1-d"
}

variable "machine_type" {
  description = "Type of GCE machine"
  type        = string
  default     = "e2-micro"
}

variable "image" {
  description = "GCE boot disk image"
  type        = string
  default     = "projects/centos-cloud/global/images/centos-stream-9-v20240919"
}

variable "network" {
  description = "Network name"
  type        = string
  default     = "default"
}