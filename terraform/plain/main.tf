# Random project name if none provided
resource "random_string" "prefix" {
  length  = 4
  upper   = false
  special = false
  numeric = false
}

# Our virtual private cloud
resource "ibm_is_vpc" "main" {
  name                      = "${local.project_name}-vpc"
  resource_group            = data.ibm_resource_group.existing.id
  address_prefix_management = "auto"
  tags                      = local.tags
}

# One public gateway, in the first zone only.
resource "ibm_is_public_gateway" "primary" {
  name           = "${local.project_name}-pgw"
  vpc            = ibm_is_vpc.main.id
  zone           = local.primary_zone
  resource_group = data.ibm_resource_group.existing.id
  tags           = local.tags
}

# for_each creates a separate subnet for each zone map entry.
# Only the primary zone's subnet attaches the gateway. null means "no gateway".
resource "ibm_is_subnet" "main" {
  for_each                 = local.vpc_zones
  name                     = "${local.project_name}-subnet-${each.value.name}"
  vpc                      = ibm_is_vpc.main.id
  zone                     = each.value.name
  total_ipv4_address_count = 256
  public_gateway           = each.value.primary ? ibm_is_public_gateway.primary.id : null
  resource_group           = data.ibm_resource_group.existing.id
  tags                     = local.tags
}
