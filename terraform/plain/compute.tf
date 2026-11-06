# compute.tf

locals {
  # Names of matching x86 Ubuntu images, e.g. ibm-ubuntu-24-04-3-minimal-amd64-1
  ubuntu_names = sort([
    for img in data.ibm_is_images.public.images : img.name
    if startswith(img.name, "ibm-ubuntu-${var.ubuntu_version}") && strcontains(img.name, "-amd64-")
  ])

  # The newest match is the last name in sorted order. If nothing matched, this
  # is null (instead of an "Invalid index" crash) and the precondition on the
  # servers below explains the problem in plain words.
  ubuntu_image_name = length(local.ubuntu_names) > 0 ? local.ubuntu_names[length(local.ubuntu_names) - 1] : null

  # name -> id lookup table, then pick the id of the newest name.
  image_ids       = { for img in data.ibm_is_images.public.images : img.name => img.id }
  ubuntu_image_id = local.ubuntu_image_name != null ? local.image_ids[local.ubuntu_image_name] : null
}

resource "ibm_is_instance" "vsi" {
  # count = how many copies to make. Inside the block count.index is 0, 1, 2...
  # The servers are ibm_is_instance.vsi[0], ibm_is_instance.vsi[1], and so on.
  count = var.instance_count

  name           = "${local.project_name}-vsi-${count.index + 1}"
  vpc            = ibm_is_vpc.main.id
  zone           = local.primary_zone
  profile        = var.vsi_profile # the size; change it and plan shows an update
  image          = local.ubuntu_image_id
  keys           = [data.ibm_is_ssh_key.existing.id]
  resource_group = data.ibm_resource_group.existing.id
  tags           = local.tags

  primary_network_interface {
    subnet          = ibm_is_subnet.main[0].id
    security_groups = [ibm_is_security_group.vsi.id]
  }

  # cloud-init: runs on first boot. Here just a package index refresh.
  user_data = "#cloud-config\npackage_update: true\n"

  lifecycle {
    # Stops the plan with a clear message if the image lookup found nothing.
    precondition {
      condition     = local.ubuntu_image_id != null
      error_message = "No public Ubuntu ${var.ubuntu_version} (amd64) image found in ${var.region}. Try ubuntu_version = \"24-04\" or \"22-04\"."
    }
  }
}

# A public IP for each server, so you can SSH to it from your laptop.
resource "ibm_is_floating_ip" "vsi" {
  count = var.enable_floating_ip ? var.instance_count : 0

  name           = "${local.project_name}-vsi-${count.index + 1}-fip"
  resource_group = data.ibm_resource_group.existing.id
  target         = ibm_is_instance.vsi[count.index].primary_network_interface[0].id
  tags           = local.tags
}
