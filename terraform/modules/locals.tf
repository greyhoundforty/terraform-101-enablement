# locals.tf
# ---------------------------------------------------------------------------
# Every local value lives here (a local is a named expression, like a Python
# variable computed once and reused). A name can only be defined ONCE per
# module, so do not add a second `locals` block elsewhere with the same names.
# ---------------------------------------------------------------------------
locals {
  # --- WORKSPACES -----------------------------------------------------------
  # terraform.workspace is the name of the active workspace ("default" until
  # you create another). It picks the region/zone from var.workspace_targets.
  # try() falls back to us-south so the provider can still start when the
  # workspace name is unknown; the precondition on ibm_is_subnet.main then
  # stops the run with a readable message.
  target = lookup(var.workspace_targets, terraform.workspace, null)
  region = try(local.target.region, "us-south")
  zone   = try(local.target.zone, "us-south-1")
  # "us-south-1" -> 1. The VPC module names zones "zone-1", "zone-2", "zone-3".
  zone_number = tonumber(element(split("-", local.zone), length(split("-", local.zone)) - 1))

  # --- NAMING ---------------------------------------------------------------
  # Use the prefix the user supplied (var.project_prefix) if there is one,
  # otherwise the random one. The random value is per workspace (each workspace
  # has its own state, so its own value). random_string.prefix only exists
  # when no prefix was supplied, which is why it is indexed with [0].
  use_random_prefix = var.project_prefix == ""
  prefix            = local.use_random_prefix ? random_string.prefix[0].result : var.project_prefix

  tags = [
    "project:${local.prefix}",
    "workspace:${terraform.workspace}",
    "region:${local.region}",
  ]

  # --- SSH KEY --------------------------------------------------------------
  # If var.existing_ssh_key names a key that already exists in IBM Cloud, look it
  # up with a data source (data.tf). Otherwise generate a new key pair: the public
  # half is uploaded to IBM Cloud and the private half is kept in state (see the
  # sensitive output ssh_private_key).
  generate_ssh_key = var.existing_ssh_key == ""
  ssh_key_ids      = local.generate_ssh_key ? [ibm_is_ssh_key.generated_key[0].id] : [data.ibm_is_ssh_key.sshkey[0].id]

  # --- UBUNTU IMAGE ---------------------------------------------------------
  # Names of matching x86 Ubuntu images, e.g. ibm-ubuntu-24-04-3-minimal-amd64-1
  ubuntu_names = sort([
    for img in data.ibm_is_images.public.images : img.name
    if startswith(img.name, "ibm-ubuntu-${var.ubuntu_version}") && strcontains(img.name, "-amd64-")
  ])

  # The newest match is the last name in sorted order. If nothing matched, this
  # is null (instead of an "Invalid index" crash) and the precondition on
  # ibm_is_subnet.main explains the problem in plain words.
  ubuntu_image_name = length(local.ubuntu_names) > 0 ? local.ubuntu_names[length(local.ubuntu_names) - 1] : null

  # name -> id lookup table, then pick the id of the newest name.
  image_ids       = { for img in data.ibm_is_images.public.images : img.name => img.id }
  ubuntu_image_id = local.ubuntu_image_name != null ? local.image_ids[local.ubuntu_image_name] : null
}
