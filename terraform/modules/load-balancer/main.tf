resource "oci_load_balancer_load_balancer" "lb" {
  compartment_id = var.compartment_ocid
  display_name   = var.name_prefix
  shape          = "100Mbps"
  subnet_ids     = var.subnet_ids
}

resource "oci_load_balancer_backend_set" "backend_set" {
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  name             = "backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    url_path = "/healthz"
    port     = var.backend_http_port
  }
}

resource "oci_load_balancer_backend" "backends" {
  for_each = toset(var.backend_instance_ocids)

  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.backend_set.name
  # TODO: This expects IP addresses, not OCIDs. Need to add data source:
  # data "oci_core_instance" "backend" {
  #   for_each = toset(var.backend_instance_ocids)
  #   instance_id = each.value
  # }
  # Then use: data.oci_core_instance.backend[each.key].private_ip
  ip_address = each.value # FIXME: Currently receives OCID, not IP
  port       = var.backend_http_port
  backup     = false
  drain      = false
  offline    = false
  weight     = 1
}

resource "oci_load_balancer_listener" "http_listener" {
  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.backend_set.name
  port                     = 80
  protocol                 = "HTTP"
}

resource "oci_load_balancer_listener" "https_listener" {
  count = length(var.ssl_certificate_ids) > 0 ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.lb.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.backend_set.name
  port                     = 443
  protocol                 = "HTTPS"

  ssl_configuration {
    certificate_ids = var.ssl_certificate_ids
  }
}
