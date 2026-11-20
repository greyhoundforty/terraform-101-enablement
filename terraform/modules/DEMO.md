# Terraform 102: live demo (modules version)

Runnable walkthrough for the `terraform/modules/` stack: the same VPC and servers as the
plain version, built from official `terraform-ibm-modules` registry modules, plus `count`,
workspaces and a generated SSH key.

Run it with [upmd](https://github.com/rezigned/upmd) from this folder:

```bash
upmd DEMO.md
```

Move with `j`/`k`, press `Enter` to run a step (its dependencies run first), `o` to see the
full output, `q` to quit. To run one step without the TUI: `upmd DEMO.md --block plan --yes`.

> [!WARNING]
> `apply` creates billable IBM Cloud resources (servers, floating IPs, a public gateway).
> Run `destroy` at the end of the demo and never leave the stack running overnight.

## 0. Before you start

Checks that Terraform is installed, your API key is set and your variables file exists.
The key itself is never printed.

```bash [name:check]
terraform version | head -1
if [ -z "${IC_API_KEY:-}" ]; then
  echo "IC_API_KEY is not set. Run: read -rs IC_API_KEY && export IC_API_KEY"
  echo "(or start upmd with: fnox exec -- upmd DEMO.md)"
  exit 1
fi
echo "IC_API_KEY is set"
if [ ! -f terraform.tfvars ]; then
  echo "terraform.tfvars is missing. Run: cp terraform.tfvars.example terraform.tfvars"
  exit 1
fi
echo "terraform.tfvars found"
```

## 1. Look at the code

Where is the registry module code? It is not in this folder: `init` downloads it.

```bash [name:files]
ls -1 *.tf
```

The registry modules used, with their pinned versions:

```bash [name:modules, deps:files]
grep -E '^module|^  (source|version) +=' main.tf
```

## 2. Workspaces: one state per region

The workspace name picks the region and zone from `var.workspace_targets`
(`default` = us-south, `eu-de`, `jp-tok`). Same code, separate state.

```bash [name:ws-show, deps:check]
terraform workspace list
```

Make sure we start in the `default` workspace (creates it if needed, never touches others):

```bash [name:ws-default, deps:check]
terraform workspace select -or-create default
```

## 3. Format, initialize and validate

`init` also downloads the four registry modules this time.

```bash [name:fmt, deps:ws-default]
terraform fmt -recursive
```

```bash [name:init, deps:ws-default]
terraform init
```

```bash [name:validate, deps:"fmt | init"]
terraform validate
```

## 4. Plan

Terraform shows what it would do. Nothing is built yet. The plan is saved so `apply` runs
exactly what you reviewed.

```bash [name:plan, deps:validate]
terraform plan -out default.tfplan
```

### Try an override (optional)

Change a value without editing a file. Watch the server count change.

```bash [name:plan-override, deps:validate]
TF_VAR_instance_count=3 terraform plan -out override.tfplan
```

### Try a bad value (optional)

The validation rule on `vsi_profile` stops the run before anything is planned.

```bash [name:plan-bad-profile, deps:validate]
TF_VAR_vsi_profile=cx2-2x4 terraform plan || echo "Stopped by the validation rule, as intended."
```

### Try another region (optional)

Switch to the `eu-de` workspace and plan there. This is a separate state, so it shows a full
create of everything in Frankfurt. Nothing is applied; the last step switches back.

```bash [name:plan-eu-de, deps:validate]
terraform workspace select -or-create eu-de
terraform plan -out eu-de.tfplan
```

```bash [name:ws-back, deps:plan-eu-de]
terraform workspace select default
rm -f eu-de.tfplan
```

## 5. Apply

Builds everything in the saved plan (default workspace, us-south). This takes a few minutes.

```bash [name:apply, deps:plan]
terraform workspace select default
terraform apply default.tfplan
```

## 6. Look at the result

What Terraform is tracking. Note the `count` indexes such as `random_string.prefix[0]`:

```bash [name:state, deps:apply]
terraform state list
```

The values printed by `outputs.tf`. `ssh_private_key` shows as `<sensitive>` on purpose.

```bash [name:outputs, deps:apply]
terraform output
```

### The generated SSH key

When `existing_ssh_key` is empty, Terraform generated a key pair. This saves the private half
to `key.pem` (git-ignored, mode 400) without printing it:

```bash [name:save-key, deps:apply]
terraform output -raw ssh_private_key > key.pem && chmod 400 key.pem
echo "Saved key.pem"
```

Public IPs for SSH (the user is `root`):

```bash [name:ssh-ips, deps:apply]
terraform output -json instances | python3 -c '
import json, sys
for name, vsi in json.load(sys.stdin).items():
    print("ssh -i key.pem root@" + str(vsi["public_ip"]) + "   # " + name)
'
```

## 7. Clean up

Deletes everything this workspace created. Terraform asks you to type `yes`.
Afterwards confirm nothing is left (`ibmcloud is vpcs`).

```bash [name:destroy]
terraform workspace select default
terraform destroy
rm -f default.tfplan override.tfplan eu-de.tfplan key.pem
```
