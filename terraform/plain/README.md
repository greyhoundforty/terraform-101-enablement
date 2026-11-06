# Plain version (no modules)

An IBM Cloud VPC and two virtual servers, written as plain Terraform `resource` and `data`
blocks (no modules). Start with `main.tf` and read down; the other `.tf` files in this folder
hold the inputs (`variables.tf`) and the values printed afterwards (`outputs.tf`).

## What it builds

| Piece | What it does |
|-------|--------------|
| Lookups (data sources) | Finds your **existing** resource group and SSH key, the zones in the region, and the newest public Ubuntu image |
| Project name | A short random name like `tf-abcd`, unless you set `project_name` |
| VPC | One VPC with automatic address prefixes (you don't pick the IP ranges) |
| Public gateway | One gateway, in the first zone, so servers can reach the internet |
| Subnets | One subnet per zone (up to 3). Only the first zone's subnet uses the gateway |
| Security group | SSH and ping allowed in **only from your address**, everything allowed out |
| Servers | `instance_count` Ubuntu servers (default 2) in the first zone |
| Floating IPs | A public IP for each server, if `enable_floating_ip` is true (the default) |

The resource group and SSH key must **already exist** in your account. Nothing here creates them.

## Before you start

You need:

1. **Terraform 1.9 or newer.** Check with `terraform version`. To install it, see
   <https://developer.hashicorp.com/terraform/install>. On macOS with Homebrew:

   ```bash
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform
   ```

2. **An IBM Cloud account**, with permission to create VPC infrastructure in one resource group.
3. **A resource group** and **an SSH key** that already exist, with the key in the same region
   you will deploy to. With the IBM Cloud CLI you can list them:

   ```bash
   ibmcloud resource groups
   ibmcloud is keys
   ```

   (Or look in the console: *Manage > Account > Resource groups*, and *VPC infrastructure >
   Compute > SSH keys*.)

## Step 1: Set your API key

Terraform reads your IBM Cloud API key from the `IC_API_KEY` environment variable, so the key
never goes in a file. If you do not have a key yet, create one in the console
(*Manage > Access (IAM) > API keys*) or with `ibmcloud iam api-key-create`. Give it an expiry if you
can, and delete it when you are done.

macOS or Linux (the `read -s` form keeps the key out of your shell history):

```bash
read -rs IC_API_KEY && export IC_API_KEY      # paste the key, press Enter (nothing is echoed)
```

Or, if you do not mind it landing in your history:

```bash
export IC_API_KEY="your-api-key"
```

Windows PowerShell:

```powershell
$env:IC_API_KEY = "your-api-key"
```

The variable only lasts for that terminal window, so set it again in a new one.
Never put the key in a `.tf` or `.tfvars` file, and never commit it.

## Step 2: Choose your settings

Copy the example settings file and edit it. `terraform.tfvars` is git-ignored, so your values are
never committed.

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and set at least:

| Setting | What to put |
|---------|-------------|
| `ssh_allowed_cidr` | Your own public IP plus `/32`, for example `203.0.113.7/32`. The example value is a placeholder, so you cannot connect until you change it |
| `owner_tag` | Who owns this stack. It becomes a tag on every resource |
| `ssh_key_name` | The name of your existing SSH key. If you leave it out, Terraform asks for it during `plan` |
| `resource_group_name` | Your existing resource group (default `Default`) |

Other settings you may want: `region` (default `us-south`), `project_name`, `vsi_profile`
(default `bx2-2x8`), `instance_count` (default 2), `enable_floating_ip` (default `true`).

You can also set any value without editing the file, from the command line or the environment:

```bash
terraform plan -var instance_count=3 -out tfplan
export TF_VAR_instance_count=3        # same idea, for the rest of this terminal session
```

## Step 3: Run it

Run these from this folder.

```bash
terraform init                # download the IBM Cloud and random providers (first time only)
terraform validate            # check the code for mistakes (makes no cloud calls)
terraform plan -out tfplan    # show what WOULD be built, and save that plan
terraform apply tfplan        # build exactly what the plan showed
```

`plan` changes nothing, so read it before you apply. Applying creates **billable** resources
(servers, floating IPs and a public gateway).

When it finishes, see what you got:

```bash
terraform output              # everything
terraform output ssh_commands # ready-to-paste SSH commands
```

Run `terraform apply tfplan` a second time and it says "No changes": the code and the cloud
already agree.

### Change something

Edit a value, for example `vsi_profile = "bx2-4x16"` in `terraform.tfvars`, then plan and apply
again. The plan shows only the difference.

```bash
terraform plan -out tfplan
terraform apply tfplan
```

### Tear it down

Do this when you are finished. Do not leave a stack running overnight.

```bash
terraform destroy
```

Then confirm nothing is left: `ibmcloud is vpcs` should no longer list your VPC.

## Same code, second region (workspaces)

A workspace is a separate copy of the state, so the same code can be applied once per region
without the two overwriting each other.

```bash
terraform workspace new eu-de
```

Put that region's settings in a file named `eu-de.tfvars` (git-ignored like the other `.tfvars`
files). SSH keys belong to a region, so use the name of a key that exists in `eu-de`:

```hcl
region       = "eu-de"
ssh_key_name = "my-key-in-frankfurt"
```

```bash
terraform plan -var-file=eu-de.tfvars -out tfplan
terraform apply tfplan
```

Switch back with `terraform workspace select default`. List them with `terraform workspace list`.

## Files you will not see in git

These are created by Terraform or by you, and are git-ignored on purpose:

- `terraform.tfvars` and other `*.tfvars`: your settings
- `terraform.tfstate*` and `terraform.tfstate.d/`: Terraform's record of what it built. It can
  contain sensitive values, so never commit or paste it
- `tfplan`, `*.tfplan`: saved plans
- `.terraform/`: downloaded providers

## Watch it build (live viewer, optional)

The viewer draws the architecture and fills in each piece as it appears in the state file.
It only reads local files; it never talks to IBM Cloud. It needs Python 3 and `terraform` on
your PATH.

1. Open a **second terminal** in the parent `terraform/` folder (not this one):

   ```bash
   cd ..
   python3 viewer/server.py --open            # add --simple for the original fixed layout
   ```

   Your browser opens at <http://127.0.0.1:8765/>. Choose **plain** in the Version menu and the
   workspace you are applying.
2. In this folder, run `plan` then `apply`.

What you will see:

- Pieces start as dashed outlines and fill in as Terraform builds them.
- Raise `instance_count` and run `plan`: the extra servers show as outlines until applied.
- Change `vsi_profile` and run `plan`: the servers get an amber marching outline and
  `updating -> <new size>` until the apply finishes.
- Terraform saves state about every 20 seconds while applying, so pieces appear in small groups.

The size-change indicator reads the saved plan, so run `terraform plan -out tfplan` before `apply`.
The viewer looks for a plan named after the workspace (`default.tfplan`), so for the viewer use
`terraform plan -out "$(terraform workspace show).tfplan"`. Stop the viewer with Ctrl+C.
