locals {
  # Use up to 3 zones. min() protects us in a region that has fewer.
  zone_count = min(3, length(data.ibm_is_zones.regional.zones))

  vpc_zones = {
    for i in range(local.zone_count) : i => {
      name    = data.ibm_is_zones.regional.zones[i]
      primary = i == 0 # only the first zone gets the public gateway
    }
  }

  primary_zone = local.vpc_zones[0].name

  project_name_input = trimspace(var.project_name)
  project_name       = local.project_name_input != "" ? local.project_name_input : "tf-${random_string.prefix.result}"

  tags = [
    "project:${local.project_name}",
    "project_owner:${var.owner_tag}",
    "demo:delete_me_11072026",
    "region:${var.region}"
  ]

}
