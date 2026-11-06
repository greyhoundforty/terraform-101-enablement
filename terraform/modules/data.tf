# Image IDs differ per region, so look the image up instead of hard-coding it.
data "ibm_is_images" "public" {
  visibility = "public"
  status     = "available"
}


# Look up an SSH key that already exists in IBM Cloud (only when one is named).
data "ibm_is_ssh_key" "sshkey" {
  count = local.generate_ssh_key ? 0 : 1
  name  = var.existing_ssh_key
}
