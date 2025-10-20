<<<<<<< HEAD
# main.tf
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "terraform" {
  name         = "terraform"
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = var.image
=======
########################################
# Terraform práctica GCP: Seguridad
# - Jump host
# - Web privado + WAF + HTTPS LB
# - Geo-block UE + SQLi/XSS
# - Certificado autofirmado dinámico
# - Cloud NAT + Zero Trust opcional
########################################

terraform {
  required_version = ">= 1.2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

########################################
# VARIABLES
########################################
variable "project" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "allowed_admin_cidr" {
  type        = string
  description = "CIDR para acceso SSH al jump host"
  default     = "130.206.68.4/32"
}

variable "enable_jump" {
  type        = bool
  default     = true
  description = "Permitir crear jump host (true=on, false=off)"
}

########################################
# RED
########################################
resource "google_compute_network" "vpc" {
  name                    = "vpc-practica"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "subnet-public"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_compute_subnetwork" "private" {
  name                     = "subnet-private"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.1.0/24"
  private_ip_google_access = true
}

########################################
# FIREWALL (Capa 4)
########################################
resource "google_compute_firewall" "allow_ssh_jump" {
  name    = "fw-ssh-jump"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.allowed_admin_cidr]
  target_tags   = ["jump"]
  description   = "Permite SSH al jump host solo desde IP admin"
}

resource "google_compute_firewall" "allow_lb_to_backend" {
  name    = "fw-lb-to-backend"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["web-backend"]
  description   = "Permite tráfico HTTPS desde LB a backend"
}

resource "google_compute_firewall" "allow_internal" {
  name    = "fw-internal"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.10.0.0/16"]
  description   = "Permite tráfico interno VPC"
}

########################################
# JUMP HOST (opcional)
########################################
resource "google_compute_instance" "jump" {
  count        = var.enable_jump ? 1 : 0
  name         = "jump-host"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["jump"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 20
>>>>>>> upstream/main
    }
  }

  network_interface {
<<<<<<< HEAD
    network       = var.network
    access_config {}
  }
}

resource "google_compute_firewall" "allow_ssh_http" {
  name    = "allow-ssh-http"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
}
=======
    subnetwork = google_compute_subnetwork.public.id
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y htop curl
  EOF
}

########################################
# CLOUD NAT
########################################
resource "google_compute_router" "nat_router" {
  name    = "router-nat"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

########################################
# WEB SERVER PRIVADO
########################################
resource "google_compute_instance" "web" {
  name         = "web-privado"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["web-backend"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Servidor web detrás del LB</h1>" > /var/www/html/index.html
    systemctl restart nginx
  EOF
}

########################################
# CERTIFICADO AUTOFIRMADO (TLS PROVIDER)
########################################
resource "tls_private_key" "self_signed_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed_cert" {
  subject {
    common_name  = "example.local"
    organization = "Terraform Self-Signed"
  }
  validity_period_hours = 8760
  allowed_uses = ["key_encipherment","digital_signature","server_auth"]
  private_key_pem = tls_private_key.self_signed_key.private_key_pem
}

resource "google_compute_ssl_certificate" "auto_self_signed" {
  name        = "auto-self-signed-cert"
  private_key = tls_private_key.self_signed_key.private_key_pem
  certificate = tls_self_signed_cert.self_signed_cert.cert_pem
}

########################################
# GRUPO DE INSTANCIAS
########################################
resource "google_compute_instance_group" "web_group" {
  name      = "web-group"
  zone      = var.zone
  instances = [google_compute_instance.web.self_link]
}

########################################
# HEALTH CHECK
########################################
resource "google_compute_health_check" "hc_https" {
  name = "hc-https"
  https_health_check {
    port = 443
    request_path = "/"
  }
}

########################################
# CLOUD ARMOR (WAF + UE)
########################################
resource "google_compute_security_policy" "waf_policy" {
  name        = "waf-policy-practica"
  description = "Cloud Armor: bloquea SQLi/XSS, solo UE"

  rule {
    priority    = 1000
    description = "Bloquear SQLi y XSS"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 3}) || evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 3})"
      }
    }
    action = "deny(403)"
  }

  rule {
    priority    = 1100
    description = "Permitir Google LB / health checks"
    match {
      expr {
        expression = "inIpRange(origin.ip, '130.211.0.0/22') || inIpRange(origin.ip, '35.191.0.0/16')"
      }
    }
    action = "allow"
  }

  # Lista de países UE dividida en grupos ≤5 para cumplir límites
rule {
  priority    = 1200
  description = "Permitir UE - grupo 1"

  match {
    expr {
      expression = "origin.region_code == 'AT' || origin.region_code == 'BE' || origin.region_code == 'BG' || origin.region_code == 'HR' || origin.region_code == 'CY'"
    }
  }

  action = "allow"
}

rule {
  priority    = 1201
  description = "Permitir UE - grupo 2"

  match {
    expr {
      expression = "origin.region_code == 'CZ' || origin.region_code == 'DK' || origin.region_code == 'EE' || origin.region_code == 'FI' || origin.region_code == 'FR'"
    }
  }

  action = "allow"
}

rule {
  priority    = 1202
  description = "Permitir UE - grupo 3"

  match {
    expr {
      expression = "origin.region_code == 'DE' || origin.region_code == 'GR' || origin.region_code == 'HU' || origin.region_code == 'IE' || origin.region_code == 'IT'"
    }
  }

  action = "allow"
}

rule {
  priority    = 1203
  description = "Permitir UE - grupo 4"

  match {
    expr {
      expression = "origin.region_code == 'LV' || origin.region_code == 'LT' || origin.region_code == 'LU' || origin.region_code == 'MT' || origin.region_code == 'NL'"
    }
  }

  action = "allow"
}

rule {
  priority    = 1204
  description = "Permitir UE - grupo 5"

  match {
    expr {
      expression = "origin.region_code == 'PL' || origin.region_code == 'PT' || origin.region_code == 'RO' || origin.region_code == 'SK' || origin.region_code == 'SI'"
    }
  }

  action = "allow"
}

rule {
  priority    = 1205
  description = "Permitir UE - grupo 6"

  match {
    expr {
      expression = "origin.region_code == 'ES' || origin.region_code == 'SE'"
    }
  }

  action = "allow"
}
  # Denegar todo lo demás
  rule {
    priority    = 2147483647
    description = "Denegar resto del tráfico"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    action = "deny(403)"
  }
}

########################################
# BACKEND SERVICE + LB
########################################
resource "google_compute_backend_service" "backend" {
  name                  = "backend-web"
  protocol              = "HTTPS"
  health_checks         = [google_compute_health_check.hc_https.self_link]
  backend {
    group = google_compute_instance_group.web_group.self_link
  }
  security_policy = google_compute_security_policy.waf_policy.self_link
}

resource "google_compute_url_map" "url_map" {
  name            = "url-map-web"
  default_service = google_compute_backend_service.backend.self_link
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy"
  url_map          = google_compute_url_map.url_map.self_link
  ssl_certificates = [google_compute_ssl_certificate.auto_self_signed.self_link]
}

resource "google_compute_global_forwarding_rule" "https_forwarder" {
  name                  = "https-forwarder"
  target                = google_compute_target_https_proxy.https_proxy.self_link
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
}

########################################
# INSTRUCCIONES EVIDENCIA
########################################
/*
1️⃣ Jump host: terraform apply, SSH desde tu IP y luego desde jump a web (IP privada)
2️⃣ WAF + LB: mostrar bloqueo SQLi/XSS, GEO UE, web sin IP pública
3️⃣ Zero Trust: activar TLS backend y SSL Passthrough si se desea
*/
>>>>>>> upstream/main
