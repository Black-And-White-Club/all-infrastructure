resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "project-vcn"
  cidr_block     = var.vcn_cidr
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn.id
  cidr_block        = var.subnet_cidr
  display_name      = "public-subnet"
  route_table_id    = oci_core_route_table.public_rt.id
  security_list_ids = [oci_core_security_list.default.id]
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "internet-gateway"
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "default" {
  compartment_id = var.compartment_ocid
  display_name   = "default-security-list"
  vcn_id         = oci_core_vcn.vcn.id

  # SSH access - restricted to specified CIDRs for security
  dynamic "ingress_security_rules" {
    for_each = var.allowed_ssh_cidrs
    content {
      protocol = "6" # TCP
      source   = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # Allow public internet traffic to reach the OCI load balancer (ports 80/443).
  # The LB sits in this subnet, so it needs these ingress rules.
  # Backend nodes are only reached via the LB over private VCN paths.
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow HTTP from internet (OCI load balancer)"
    tcp_options {
      min = var.backend_http_port
      max = var.backend_http_port
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow HTTPS from internet (OCI load balancer)"
    tcp_options {
      min = var.backend_https_port
      max = var.backend_https_port
    }
  }

  # Kubernetes API server - internal
  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Kubernetes API server - external access
  dynamic "ingress_security_rules" {
    for_each = var.allowed_k8s_api_cidrs
    content {
      protocol = "6"
      source   = ingress_security_rules.value
      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  # etcd
  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr
    tcp_options {
      min = 2379
      max = 2380
    }
  }

  # kubelet
  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr
    tcp_options {
      min = 10250
      max = 10250
    }
  }

  # Allow all traffic within VCN
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Allow all traffic within VCN"
  }

  # NodePort range removed for security - only expose specific ports via load balancer
  # If specific NodePorts must be exposed, add individual rules for those ports only

  egress_security_rules {
    protocol    = "all"
    destination = var.vcn_cidr
    description = "Allow all traffic to VCN"
  }

  egress_security_rules {
    protocol    = "6" # TCP
    destination = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "17" # UDP
    destination = "0.0.0.0/0"
    udp_options {
      min = 53
      max = 53
    }
  }
}
