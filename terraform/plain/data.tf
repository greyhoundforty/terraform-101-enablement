data "ibm_is_zones" "regional" {
  region = var.region
}

data "ibm_resource_group" "existing" {
  name = var.resource_group_name
}

data "ibm_is_ssh_key" "existing" {
  name = var.ssh_key_name
}

# Image IDs differ per region, so look the image up instead of hard-coding it.
data "ibm_is_images" "public" {
  visibility = "public"
  status     = "available"
}