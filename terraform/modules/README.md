# Modules version (official IBM Cloud modules)

The same VPC build as `../plain`, but using the official `terraform-ibm-modules` registry
modules instead of hand-written resources. Compare the two to see what modules save you.

## What it builds

| Piece | How |
|-------|-----|
| Resource group | `terraform-ibm-modules/resource-group/ibm` (looks up an existing group) |
| VPC, public gateway, ACL | `terraform-ibm-modules/landing-zone-vpc/ibm` |
| Subnet | `ibm_is_subnet` with `total_ipv4_address_count`, so IBM picks the range (auto address prefixes) |
| Security group + rules | `terraform-ibm-modules/security-group/ibm` |
| Servers + public IPs | `terraform-ibm-modules/landing-zone-vsi/ibm` (`instance_count`, default 2) |
| SSH key | Existing key looked up, **or** a new key pair generated for you (see below) |

There is no official SSH key module, so that part uses plain resources.

## Settings (`terraform.tfvars`)

First time: copy the example file to `terraform.tfvars` (git-ignored) and edit it, at least
`ssh_allowed_cidr`. The example value is a documentation address, so replace it or you
cannot connect.

```bash
cp terraform.tfvars.example terraform.tfvars      # or: mise run tfvars:init
```

| Setting | Meaning |
|---------|---------|
| `resource_group_name` | An existing resource group (default `Default`) |
| `vsi_profile` | Server size, `bx2-*` only (default `bx2-2x8`; the demo bumps to `bx2-4x16`) |
| `instance_count` | Number of servers (default 2) |
| `ssh_allowed_cidr` | Your public IP plus `/32`. **Required**, no default |
| `ubuntu_version` | Optional. Ubuntu release, `24-04` (default) or `22-04` |
| `project_prefix` | Optional. Your own name prefix for every resource. Empty = a random prefix |
| `existing_ssh_key` | Optional. Name of an existing key in the same region. Empty = generate a key |

SSH key behavior:

- `existing_ssh_key` set: that key is looked up and used.
- `existing_ssh_key` empty: Terraform generates a key pair and uploads the public half. Nothing is
  written to disk. The private half is a sensitive output; save it yourself when you need it:
  `terraform output -raw ssh_private_key > key.pem && chmod 400 key.pem` (keep it private).

## Regions with workspaces

`workspace_targets` in `variables.tf` maps each workspace name to a region and zone
(`default` = us-south, `eu-de` = Frankfurt, `jp-tok` = Tokyo). The workspace name picks the region.
A workspace name that is not in the map stops the plan with a clear message.

```bash
terraform workspace new eu-de       # create and switch to the eu-de workspace
terraform workspace list
terraform workspace select default
```

(With mise: `mise run ws:new eu-de`, `ws:list`, `ws:select default`.)

## Run it

From this folder. Terraform reads your IBM Cloud API key from `IC_API_KEY`.

```bash
export IC_API_KEY="your-api-key"      # or: read -rs IC_API_KEY && export IC_API_KEY

terraform init                # download providers and modules
terraform validate
terraform plan -out tfplan    # read it before you apply
terraform apply tfplan
terraform destroy             # when you are finished
```

Applying creates **billable** resources. Destroy them when you are done.

With mise and fnox installed, the same steps are tasks, and `fnox exec --` supplies the key:

```bash
fnox exec -- mise run init
fnox exec -- mise run plan       # saves <workspace>.tfplan
fnox exec -- mise run apply
fnox exec -- mise run destroy
```

Other mise tasks: `validate`, `fmt`, `state-list`, `tfvars:init`, `ws:new`, `ws:select`, `ws:list`.

## Tests

Plan-only tests with mocked providers. No credentials needed and nothing is created:

```bash
terraform init && terraform test
```

## Watch it build (live viewer)

The viewer draws the architecture and fills in each piece as it appears in the state file.
It only reads local files; it never talks to IBM Cloud.

1. Open a **second terminal** in the parent `terraform/` folder (not this one):

   ```bash
   cd ..
   python3 viewer/server.py --open            # add --simple for the original fixed layout
   ```

   Your browser opens at http://127.0.0.1:8765/. Choose **modules** in the Version menu and
   the workspace you are applying.
2. In this folder, run `plan` then `apply`.

What you will see:

- Pieces start as dashed outlines and fill in as Terraform builds them.
- Raise `instance_count` and run `plan`: the extra servers show as outlines until applied.
- Change `vsi_profile` and run `plan`: the servers get an amber marching outline and
  `updating → <new size>` until the apply finishes.
- Terraform saves state about every 20 seconds while applying, so pieces appear in small groups.

The size-change indicator comes from the saved plan, so run `plan` before `apply`. The viewer
needs `terraform` on your PATH. The module state lists the VPC twice
(built and looked up); the viewer counts only what Terraform built.

The default view shows a box per subnet; `--simple` is the original fixed layout (with mise:
`mise run viewer` or `mise run viewer:simple`). Stop the viewer with Ctrl+C.
