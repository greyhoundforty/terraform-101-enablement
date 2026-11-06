# security_group.tf
# ---------------------------------------------------------------------------
# A stateful firewall attached to each server's network interface. "Stateful"
# means replies to allowed traffic are let back through automatically.
# ---------------------------------------------------------------------------
resource "ibm_is_security_group" "vsi" {
  name           = "${local.project_name}-vsi-sg"
  vpc            = ibm_is_vpc.main.id
  resource_group = data.ibm_resource_group.existing.id
  tags           = local.tags
}

# Allow SSH (TCP port 22) in, only from your address.
resource "ibm_is_security_group_rule" "ssh_in" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = var.ssh_allowed_cidr
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}

# Allow ping (ICMP echo request, type 8 code 0) in, only from your address.
resource "ibm_is_security_group_rule" "ping_in" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = var.ssh_allowed_cidr
  protocol  = "icmp"
  type      = 8
  code      = 0
}

# Allow everything out. Without this the server could not download updates.
resource "ibm_is_security_group_rule" "all_out" {
  group     = ibm_is_security_group.vsi.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}
