# outputs.tf
# Outputs are the values Terraform prints after apply (and on `terraform output`).
# They are read back from state, so they only show real values once resources exist.

output "project_name" {
  description = "The project name in use: yours, or the generated tf-xxxx one."
  value       = local.project_name
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = ibm_is_vpc.main.id
}

output "zones_used" {
  description = "Zones that got a subnet, in order. The first one hosts the servers."
  value       = [for z in local.vpc_zones : z.name]
}

output "primary_zone" {
  description = "Zone the servers and the public gateway live in."
  value       = local.primary_zone
}

output "public_gateway_id" {
  description = "The single public gateway (first zone only)."
  value       = ibm_is_public_gateway.primary.id
}

# for_each gave us one subnet per zone, so this is a map: zone name -> subnet details.
# A `for` expression loops over the map and builds a new one.
output "subnets" {
  description = "Subnets by zone, with their CIDR and whether they have the public gateway."
  value = {
    for key, subnet in ibm_is_subnet.main : subnet.zone => {
      id             = subnet.id
      cidr           = subnet.ipv4_cidr_block
      public_gateway = subnet.public_gateway != null
    }
  }
}

# count gave us a list of servers. The [*] "splat" collects one attribute from each.
output "vsi_ids" {
  description = "IDs of the servers."
  value       = ibm_is_instance.vsi[*].id
}

output "vsi_names" {
  description = "Names of the servers."
  value       = ibm_is_instance.vsi[*].name
}

output "vsi_private_ips" {
  description = "Private IP of each server."
  value       = [for vsi in ibm_is_instance.vsi : try(vsi.primary_network_interface[0].primary_ip[0].address, null)]
}

# When enable_floating_ip is false, count is 0, so this is simply an empty list.
output "vsi_floating_ips" {
  description = "Public IP of each server (empty if enable_floating_ip is false)."
  value       = ibm_is_floating_ip.vsi[*].address
}

output "ssh_commands" {
  description = "Ready-to-paste SSH commands (empty if there are no floating IPs)."
  value       = [for ip in ibm_is_floating_ip.vsi[*].address : "ssh root@${ip}"]
}

output "ubuntu_image" {
  description = "The Ubuntu image the lookup picked."
  value       = local.ubuntu_image_name
}
