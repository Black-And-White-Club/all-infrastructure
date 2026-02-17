locals {
  # Use numeric indices as keys (known at plan time), IP addresses as values (can be unknown)
  backend_targets = { for idx, ip in var.backend_ip_addresses : tostring(idx) => ip }
  certificate_ids = length(var.ssl_certificate_ids) > 0 ? var.ssl_certificate_ids : (var.certificate_ocid != "" ? [var.certificate_ocid] : [])

  # Determine if we should use TLS termination at LB (requires cert) or TCP passthrough
  use_tls_termination = var.enable_https_listener && length(local.certificate_ids) > 0
  use_tls_passthrough = var.enable_https_listener && !local.use_tls_termination
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

# HTTP backend set - used for:
# - HTTP listener (port 80)
# - HTTPS listener with TLS termination (LB decrypts, sends HTTP to backend)
resource "oci_load_balancer_backend_set" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  name             = "http-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = upper(var.health_check_protocol)
    port     = var.backend_http_port
    url_path = upper(var.health_check_protocol) == "HTTP" ? var.http_health_path : null
  }
}

# TCP/TLS passthrough backend set - only for when nginx-ingress handles TLS (cert-manager)
resource "oci_load_balancer_backend_set" "tcp_passthrough" {
  count            = local.use_tls_passthrough ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  name             = "tcp-passthrough-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    # TCP health check - simple connection test, increased timeout for TLS
    protocol          = "TCP"
    port              = var.backend_https_port
    timeout_in_millis = 10000 # 10 seconds for TLS handshake
    interval_ms       = 30000 # Check every 30 seconds
    retries           = 3     # Allow 3 retries before marking unhealthy
  }
}

# HTTP backends - always created
resource "oci_load_balancer_backend" "http" {
  for_each = local.backend_targets

  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = each.value
  port             = var.backend_http_port
}

# TCP passthrough backends - only for TLS passthrough mode
resource "oci_load_balancer_backend" "tcp_passthrough" {
  for_each = local.use_tls_passthrough ? local.backend_targets : {}

  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.tcp_passthrough[0].name
  ip_address       = each.value
  port             = var.backend_https_port
}

# HTTP listener (port 80)
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.http.name
  port                     = 80
  protocol                 = "HTTP"
}

# HTTPS listener with TLS termination at LB
# Routes to HTTP backend since LB already decrypted the traffic
resource "oci_load_balancer_listener" "https_terminated" {
  count = local.use_tls_termination ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.http.name # Same backend as HTTP!
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_ids         = local.certificate_ids
    verify_peer_certificate = false
  }
}

# HTTPS listener with TLS passthrough (let nginx/ingress handle TLS with cert-manager)
resource "oci_load_balancer_listener" "https_passthrough" {
  count = local.use_tls_passthrough ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.tcp_passthrough[0].name
  port                     = 443
  protocol                 = "TCP"
}
