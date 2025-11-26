locals {
  backend_ips = length(var.backend_ip_addresses) > 0 ? { for ip in var.backend_ip_addresses : ip => ip } : {}
}

# Data source to look up certificate by OCID (if provided)
data "oci_certificates_management_certificate" "lookup" {
  count = var.certificate_ocid != "" ? 1 : 0

  certificate_id = var.certificate_ocid
}

resource "oci_load_balancer_load_balancer" "lb" {
  compartment_id = var.compartment_ocid
  display_name   = var.name_prefix
  shape          = var.load_balancer_shape
  subnet_ids     = var.subnet_ids
  shape_details {
    minimum_bandwidth_in_mbps = var.load_balancer_min_bandwidth
    maximum_bandwidth_in_mbps = var.load_balancer_max_bandwidth
  }
}

resource "oci_load_balancer_backend_set" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  name             = "http-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = var.http_health_protocol
    port     = var.backend_http_port
    url_path = var.http_health_protocol == "HTTP" ? var.http_health_path : null
  }
}

resource "oci_load_balancer_backend_set" "tcp" {
  count            = var.enable_https_listener ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  name             = "tcp-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "TCP"
    port     = var.backend_https_port
  }
}

resource "oci_load_balancer_backend" "http" {
  for_each = local.backend_ips

  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = each.key
  port             = var.backend_http_port
}

resource "oci_load_balancer_backend" "tcp" {
  for_each = var.enable_https_listener ? local.backend_ips : {}

  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.tcp[0].name
  ip_address       = each.key
  port             = var.backend_https_port
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.http.name
  port                     = 80
  protocol                 = "HTTP"
}

resource "oci_load_balancer_listener" "https" {
  count = var.enable_https_listener ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.tcp[0].name
  port                     = 443
  protocol                 = "HTTPS"

  ssl_configuration {
    certificate_ids = [var.certificate_ocid]
    protocols       = ["TLSv1.2", "TLSv1.3"]
  }
}
