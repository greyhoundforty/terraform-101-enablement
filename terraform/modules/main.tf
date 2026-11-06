# main.tf
# ---------------------------------------------------------------------------
# Builds: random prefix -> resource group lookup -> SSH key -> VPC (auto address
# prefixes) -> subnet -> security group -> Ubuntu nano servers.
# Locals live in locals.tf; data sources in data.tf.
# Official terraform-ibm-modules are used wherever one fits. Terraform works
# out the order from references between blocks (e.g. module.vpc.vpc_id), so
# the order of blocks in this file does not matter.
# ---------------------------------------------------------------------------

# 0. NAME PREFIX -------------------------------------------------------------
# A short random string used in every resource name (local.prefix). Letters
# only, because IBM Cloud names must start with a letter. It is stored in the
# state, so it stays the same between runs and differs per workspace.
resource "random_string" "prefix" {
  count   = local.use_random_prefix ? 1 : 0 # skipped when var.project_prefix is set
  length  = 6
  special = false
  upper   = false
  numeric = false
}

# 1. RESOURCE GROUP ----------------------------------------------------------
# Official module. With existing_resource_group_name it only LOOKS UP the group.
module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.6.1"

  existing_resource_group_name = var.resource_group_name
}

# 2. SSH KEY ------------------------------------------------------------------
# count = 1 builds the resource, count = 0 skips it. Here it is the switch between
# "generate a new key pair" and "look up the key that already exists" (data.tf).
# Nothing is written to disk: the private half lives in state and is shown by the
# sensitive output ssh_private_key (see outputs.tf).
resource "tls_private_key" "ssh" {
  count     = local.generate_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Add a new SSH key to the region if one was created
resource "ibm_is_ssh_key" "generated_key" {
  count          = local.generate_ssh_key ? 1 : 0
  name           = "${local.prefix}-${local.region}-key"
  public_key     = tls_private_key.ssh[0].public_key_openssh
  resource_group = module.resource_group.resource_group_id
  tags           = local.tags
}

# 3. NETWORKING ---------------------------------------------------------------
module "vpc" {
  source  = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version = "10.1.7"

  resource_group_id = module.resource_group.resource_group_id
  region            = local.region
  prefix            = local.prefix
  name              = "vpc" # final VPC name: <prefix>-vpc

  subnets = {
    zone-1 = null
    zone-2 = null
    zone-3 = null
  }

  # Public gateway only in the zone we use (lets servers reach the internet outbound).
  use_public_gateways = {
    zone-1 = local.zone_number == 1
    zone-2 = local.zone_number == 2
    zone-3 = local.zone_number == 3
  }

  # Network ACLs are stateless subnet-level filters. We allow everything and
  # do the real filtering with the security group below.
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      add_deny_all_rule            = false
      rules = [
        {
          name        = "allow-all-inbound"
          action      = "allow"
          direction   = "inbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
        },
        {
          name        = "allow-all-outbound"
          action      = "allow"
          direction   = "outbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
        }
      ]
    }
  ]
}

resource "ibm_is_subnet" "main" {
  name                     = "${local.prefix}-subnet"
  vpc                      = module.vpc.vpc_id
  zone                     = local.zone
  resource_group           = module.resource_group.resource_group_id
  total_ipv4_address_count = var.subnet_ip_count # <- no ipv4_cidr_block on purpose
  network_acl              = module.vpc.network_acls[0].id
  tags                     = local.tags
  public_gateway           = module.vpc.public_gateways["zone-${local.zone_number}"]

  # Pre-flight checks: stop early, with a clear message, before anything is built.
  lifecycle {
    precondition {
      condition     = local.target != null
      error_message = "Workspace '${terraform.workspace}' is not a key of var.workspace_targets. Add it in variables.tf, or switch workspace."
    }

    precondition {
      condition     = local.ubuntu_image_id != null
      error_message = "No public Ubuntu ${var.ubuntu_version} (amd64) image found in ${local.region}. Try ubuntu_version = \"24-04\" or \"22-04\"."
    }
  }
}

# 4. SECURITY GROUP -----------------------------------------------------------
# A stateful firewall attached to the server's network interface.
module "vsi_security_group" {
  source  = "terraform-ibm-modules/security-group/ibm"
  version = "2.11.0"

  security_group_name = "${local.prefix}-vsi-sg"
  vpc_id              = module.vpc.vpc_id
  resource_group      = module.resource_group.resource_group_id

  security_group_rules = [
    {
      name      = "allow-ssh-in"
      direction = "inbound"
      remote    = var.ssh_allowed_cidr
      protocol  = "tcp"
      port_min  = 22
      port_max  = 22
    },
    {
      name      = "allow-ping-in"
      direction = "inbound"
      remote    = var.ssh_allowed_cidr
      protocol  = "icmp"
      type      = 8
      code      = 0
    },
    {
      # Without an outbound rule the server could not download updates.
      name      = "allow-all-out"
      direction = "outbound"
      remote    = "0.0.0.0/0"
    }
  ]
}


# 7. NANO UBUNTU SERVERS ----------------------------------------------------------
module "vsi" {
  source  = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version = "8.3.5"

  resource_group_id  = module.resource_group.resource_group_id
  prefix             = local.prefix
  vpc_id             = module.vpc.vpc_id
  image_id           = local.ubuntu_image_id
  machine_type       = var.vsi_profile
  vsi_per_subnet     = var.instance_count
  ssh_key_ids        = local.ssh_key_ids
  enable_floating_ip = var.enable_floating_ip

  # The module wants a list of subnets (name, id, zone); ours is a single one.
  # The name is a FIXED label on purpose: the module builds its for_each keys
  # from it, and Terraform needs those keys at plan time. ibm_is_subnet.main.name
  # contains the random prefix, which is unknown until apply, so using it here
  # fails with "Invalid for_each argument". (id and zone are only values, so
  # they may be unknown.) The real subnet name in IBM Cloud is unchanged.
  subnets = [
    {
      name = "subnet"
      id   = ibm_is_subnet.main.id
      zone = ibm_is_subnet.main.zone
    }
  ]

  # Use OUR security group above instead of letting this module create one.
  create_security_group = false
  security_group_ids    = [module.vsi_security_group.security_group_id_for_ref]

  # cloud-init: runs on first boot. Here just a package index refresh.
  user_data = "#cloud-config\npackage_update: true\n"
}
