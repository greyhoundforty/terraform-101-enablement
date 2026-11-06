# Plan-only tests: every run uses command = plan, every provider is mocked and
# the four Registry modules are overridden, so no credentials are needed and
# nothing is created in IBM Cloud.

mock_provider "ibm" {
  mock_data "ibm_is_ssh_key" {
    defaults = {
      id = "mock-ssh-key-id"
    }
  }

  # locals.tf picks the newest image whose name starts with
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

mock_provider "random" {}
mock_provider "tls" {}

override_module {
  target = module.resource_group
  outputs = {
    resource_group_id = "mock-resource-group-id"
  }
}

override_module {
  target = module.vpc
  outputs = {
    vpc_id       = "mock-vpc-id"
    vpc_name     = "demo-vpc"
    network_acls = [{ id = "mock-acl-id" }]
    public_gateways = {
      zone-1 = "mock-pgw-1"
      zone-2 = null
      zone-3 = null
    }
  }
}

override_module {
  target = module.vsi_security_group
  outputs = {
    security_group_id_for_ref = "mock-sg-id"
  }
}

override_module {
  target = module.vsi
  outputs = {
    list = []
  }
}

variables {
  project_prefix   = "demo"
  ssh_allowed_cidr = "203.0.113.7/32"
}

run "default_workspace_targets_us_south" {
  command = plan

  assert {
    condition     = output.workspace == "default -> us-south / us-south-1"
    error_message = "The default workspace must deploy to us-south / us-south-1."
  }

  assert {
    condition     = local.zone_number == 1
    error_message = "zone us-south-1 must give zone_number 1."
  }
}

run "tags_and_prefix_from_project_prefix" {
  command = plan

  assert {
    condition     = local.prefix == "demo"
    error_message = "A supplied project_prefix must be used as the prefix."
  }

  assert {
    condition     = length(random_string.prefix) == 0
    error_message = "No random prefix must be created when project_prefix is set."
  }

  assert {
    condition     = contains(local.tags, "project:demo") && contains(local.tags, "workspace:default") && contains(local.tags, "region:us-south")
    error_message = "Tags must carry project, workspace and region."
  }
}

run "random_prefix_when_project_prefix_empty" {
  command = plan

  variables {
    project_prefix = ""
  }

  assert {
    condition     = length(random_string.prefix) == 1
    error_message = "A random prefix must be created when project_prefix is empty."
  }
}

run "generates_ssh_key_when_none_given" {
  command = plan

  assert {
    condition     = length(tls_private_key.ssh) == 1 && length(ibm_is_ssh_key.generated_key) == 1
    error_message = "An SSH key pair must be generated when existing_ssh_key is empty."
  }

  assert {
    condition     = length(data.ibm_is_ssh_key.sshkey) == 0
    error_message = "No SSH key lookup must happen when a key is generated."
  }

  assert {
    condition     = ibm_is_ssh_key.generated_key[0].name == "demo-us-south-key"
    error_message = "Generated key must be named <prefix>-<region>-key."
  }
}

run "uses_existing_ssh_key_when_given" {
  command = plan

  variables {
    existing_ssh_key = "my-key"
  }

  assert {
    condition     = length(tls_private_key.ssh) == 0 && length(ibm_is_ssh_key.generated_key) == 0
    error_message = "No key must be generated when existing_ssh_key is set."
  }

  assert {
    condition     = length(data.ibm_is_ssh_key.sshkey) == 1
    error_message = "The existing SSH key must be looked up."
  }
}

run "subnet_settings" {
  command = plan

  variables {
    subnet_ip_count = 128
  }

  assert {
    condition     = ibm_is_subnet.main.name == "demo-subnet"
    error_message = "Subnet name must be <prefix>-subnet."
  }

  assert {
    condition     = ibm_is_subnet.main.total_ipv4_address_count == 128 && ibm_is_subnet.main.zone == "us-south-1"
    error_message = "Subnet must use subnet_ip_count and the workspace zone."
  }
}

run "picks_newest_matching_ubuntu_image" {
  command = plan

  assert {
    condition     = local.ubuntu_image_id == "mock-ubuntu-24-image-id"
    error_message = "ubuntu_version 24-04 must select the 24.04 amd64 image."
  }
}

run "picks_other_ubuntu_version" {
  command = plan

  variables {
    ubuntu_version = "22-04"
  }

  assert {
    condition     = local.ubuntu_image_id == "mock-ubuntu-22-image-id"
    error_message = "ubuntu_version 22-04 must select the 22.04 amd64 image."
  }
}

run "unknown_workspace_is_rejected" {
  command = plan

  variables {
    workspace_targets = {
      other = { region = "eu-de", zone = "eu-de-1" }
    }
  }

  expect_failures = [ibm_is_subnet.main]
}

run "rejects_non_bx2_profile" {
  command = plan

  variables {
    vsi_profile = "cx2-2x4"
  }

  expect_failures = [var.vsi_profile]
}

run "rejects_non_power_of_two_subnet_size" {
  command = plan

  variables {
    subnet_ip_count = 100
  }

  expect_failures = [var.subnet_ip_count]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    ssh_allowed_cidr = "not-a-cidr"
  }

  expect_failures = [var.ssh_allowed_cidr]
}

run "rejects_invalid_project_prefix" {
  command = plan

  variables {
    project_prefix = "Bad_Prefix"
  }

  expect_failures = [var.project_prefix]
}

run "unknown_ubuntu_version_is_rejected" {
  command = plan

  variables {
    ubuntu_version = "99-99"
  }

  expect_failures = [ibm_is_subnet.main]
}
