# Plan-only tests: every run uses command = plan and every provider is mocked,
# so no credentials are needed and nothing is created in IBM Cloud.
# Run from this folder: terraform init && terraform test

mock_provider "ibm" {
  # main.tf builds one subnet per zone (up to 3), so the mock offers three.
  mock_data "ibm_is_zones" {
    defaults = {
      zones = ["us-south-1", "us-south-2", "us-south-3"]
    }
  }

  mock_data "ibm_resource_group" {
    defaults = {
      id = "mock-resource-group-id"
    }
  }

  mock_data "ibm_is_ssh_key" {
    defaults = {
      id = "mock-ssh-key-id"
    }
  }

  # compute.tf picks the newest image whose name starts with
  # ibm-ubuntu-<ubuntu_version> and contains -amd64-, so the mock must offer one.
  mock_data "ibm_is_images" {
    defaults = {
      images = [
        {
          name = "ibm-ubuntu-24-04-3-minimal-amd64-1"
          id   = "mock-ubuntu-24-image-id"
        },
        {
          name = "ibm-ubuntu-22-04-5-minimal-amd64-1"
          id   = "mock-ubuntu-22-image-id"
        },
      ]
    }
  }
}

variables {
  region           = "us-south"
  project_name     = "test"
  vsi_profile      = "bx2-2x8"
  ssh_key_name     = "test-key"
  ssh_allowed_cidr = "203.0.113.7/32"
  owner_tag        = "tester"
  instance_count   = 2
  ubuntu_version   = "24-04"
}

run "names_use_project_name" {
  command = plan

  assert {
    condition     = ibm_is_vpc.main.name == "test-vpc"
    error_message = "VPC name must be <project_name>-vpc."
  }

  assert {
    condition     = ibm_is_security_group.vsi.name == "test-vsi-sg"
    error_message = "Security group name must be <project_name>-vsi-sg."
  }

  assert {
    condition     = ibm_is_public_gateway.primary.name == "test-pgw"
    error_message = "Gateway name must be <project_name>-pgw."
  }
}

run "generated_name_when_project_name_empty" {
  command = plan

  variables {
    project_name = ""
  }

  assert {
    condition     = startswith(local.project_name, "tf-")
    error_message = "An empty project_name must give a generated tf-xxxx name."
  }
}

run "vpc_uses_auto_address_prefixes" {
  command = plan

  assert {
    condition     = ibm_is_vpc.main.address_prefix_management == "auto"
    error_message = "VPC must use automatic address prefix management."
  }
}

run "one_subnet_per_zone" {
  command = plan

  assert {
    condition     = length(ibm_is_subnet.main) == 3
    error_message = "Expected one subnet per zone (three in the mock region)."
  }

  assert {
    condition     = ibm_is_subnet.main[1].zone == "us-south-2"
    error_message = "Subnet 1 must be in the second zone."
  }
}

run "only_primary_subnet_has_gateway" {
  command = plan

  assert {
    condition     = ibm_is_subnet.main[0].zone == local.primary_zone
    error_message = "Subnet 0 must be in the primary zone."
  }

  # The gateway id is only known after apply, so check the rule that decides it.
  assert {
    condition     = local.vpc_zones[0].primary && !local.vpc_zones[1].primary && !local.vpc_zones[2].primary
    error_message = "Only the primary zone may be marked to attach the public gateway."
  }
}

run "instances_follow_count_and_profile" {
  command = plan

  variables {
    instance_count = 3
    vsi_profile    = "bx2-4x16"
  }

  assert {
    condition     = length(ibm_is_instance.vsi) == 3
    error_message = "Expected one instance per instance_count."
  }

  assert {
    condition     = ibm_is_instance.vsi[0].name == "test-vsi-1" && ibm_is_instance.vsi[2].name == "test-vsi-3"
    error_message = "Instance names must be <project_name>-vsi-<n> starting at 1."
  }

  assert {
    condition     = alltrue([for i in ibm_is_instance.vsi : i.profile == "bx2-4x16"])
    error_message = "Every instance must use var.vsi_profile."
  }

  assert {
    condition     = alltrue([for i in ibm_is_instance.vsi : i.zone == local.primary_zone])
    error_message = "Every instance must be in the primary zone."
  }
}

run "ubuntu_image_selected_by_version" {
  command = plan

  assert {
    condition     = local.ubuntu_image_id == "mock-ubuntu-24-image-id"
    error_message = "ubuntu_version 24-04 must select the 24.04 amd64 image."
  }

  assert {
    condition     = ibm_is_instance.vsi[0].image == "mock-ubuntu-24-image-id"
    error_message = "Instances must boot the selected image."
  }
}

run "ubuntu_22_04_selected" {
  command = plan

  variables {
    ubuntu_version = "22-04"
  }

  assert {
    condition     = local.ubuntu_image_id == "mock-ubuntu-22-image-id"
    error_message = "ubuntu_version 22-04 must select the 22.04 amd64 image."
  }
}

# The precondition on the instances turns "no image found" into a readable error.
run "unknown_ubuntu_version_is_rejected" {
  command = plan

  variables {
    ubuntu_version = "99-99"
  }

  expect_failures = [ibm_is_instance.vsi]
}

run "floating_ips_enabled" {
  command = plan

  variables {
    enable_floating_ip = true
    instance_count     = 2
  }

  assert {
    condition     = length(ibm_is_floating_ip.vsi) == 2
    error_message = "One floating IP per instance when enable_floating_ip is true."
  }

  assert {
    condition     = ibm_is_floating_ip.vsi[1].name == "test-vsi-2-fip"
    error_message = "Floating IP names must be <project_name>-vsi-<n>-fip."
  }
}

run "floating_ips_disabled" {
  command = plan

  variables {
    enable_floating_ip = false
  }

  assert {
    condition     = length(ibm_is_floating_ip.vsi) == 0
    error_message = "No floating IPs when enable_floating_ip is false."
  }
}

run "inbound_rules_limited_to_allowed_cidr" {
  command = plan

  assert {
    condition = (
      ibm_is_security_group_rule.ssh_in.direction == "inbound" &&
      ibm_is_security_group_rule.ssh_in.remote == "203.0.113.7/32" &&
      ibm_is_security_group_rule.ssh_in.port_min == 22 &&
      ibm_is_security_group_rule.ssh_in.port_max == 22
    )
    error_message = "SSH rule must be inbound TCP 22 from ssh_allowed_cidr only."
  }

  assert {
    condition = (
      ibm_is_security_group_rule.ping_in.direction == "inbound" &&
      ibm_is_security_group_rule.ping_in.remote == "203.0.113.7/32"
    )
    error_message = "Ping rule must be inbound from ssh_allowed_cidr only."
  }
}

run "resources_are_tagged" {
  command = plan

  assert {
    condition     = contains(ibm_is_vpc.main.tags, "project_owner:tester") && contains(ibm_is_vpc.main.tags, "region:us-south")
    error_message = "Resources must carry the owner and region tags."
  }
}

# --- variable validation -----------------------------------------------------

run "rejects_non_bx2_profile" {
  command = plan

  variables {
    vsi_profile = "cx2-2x4"
  }

  expect_failures = [var.vsi_profile]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    ssh_allowed_cidr = "not-a-cidr"
  }

  expect_failures = [var.ssh_allowed_cidr]
}

run "rejects_non_power_of_two_subnet_size" {
  command = plan

  variables {
    subnet_ip_count = 100
  }

  expect_failures = [var.subnet_ip_count]
}
