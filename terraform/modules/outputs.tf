# outputs.tf
# ---------------------------------------------------------------------------
# What Terraform prints after `terraform apply` (and on `terraform output`).
# Kept short on purpose: the VPC, and one line-block per server. Everything
# else (network interfaces, CRNs, security group IDs...) is still in the state
# and in the IBM Cloud console if you need it.
# ---------------------------------------------------------------------------

output "workspace" {
  description = "Which workspace is active and where it deploys."
  value       = "${terraform.workspace} -> ${local.region} / ${local.zone}"
}

output "vpc" {
  description = "The VPC, and the address range IBM Cloud chose for our subnet."
  value = {
    name        = module.vpc.vpc_name
    id          = module.vpc.vpc_id
    subnet_cidr = ibm_is_subnet.main.ipv4_cidr_block # we only asked for an IP count
  }
}

# One entry per server, keyed by its name. Change instance_count or vsi_profile
# in terraform.tfvars, run plan, and this is the block that grows or changes.
output "instances" {
  description = "The servers: name, ID, size, zone and IP addresses."
  value = {
    for vsi in module.vsi.list : vsi.name => {
      id         = vsi.id
      profile    = var.vsi_profile # every server uses the same size
      zone       = vsi.zone
      private_ip = vsi.ipv4_address
      public_ip  = try(vsi.floating_ip, null) # null when enable_floating_ip = false
    }
  }
}

# Only has a value when Terraform generated the key (existing_ssh_key is empty).
# sensitive = true hides it from the apply output; read it on purpose with:
#   terraform output -raw ssh_private_key > key.pem && chmod 400 key.pem
output "ssh_private_key" {
  description = "Private half of the generated SSH key (null when an existing key is used)."
  value       = try(tls_private_key.ssh[0].private_key_pem, null)
  sensitive   = true
}
