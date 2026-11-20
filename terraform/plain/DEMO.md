# Terraform 101: live demo (plain version)

Runnable walkthrough for the `terraform/plain/` stack: an IBM Cloud VPC, subnets, a
security group and two Ubuntu servers, all written as plain `resource` blocks.

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

The files are the story: `variables.tf` are the inputs, `main.tf` and friends are the
resources, `outputs.tf` is what you get back.

```bash [name:files]
ls -1 *.tf
```

```bash [name:variables, deps:files]
grep -E '^variable' variables.tf
```

## 2. Format, initialize and validate

`fmt` tidies the files, `init` downloads the IBM Cloud provider, `validate` checks syntax and
types without calling the cloud.

```bash [name:fmt, deps:check]
terraform fmt -recursive
```

```bash [name:init, deps:check]
terraform init
```

```bash [name:validate, deps:"fmt | init"]
terraform validate
```

## 3. Plan

Terraform compares the code with the real world and shows what it would do. Nothing is built
yet. The plan is saved to a file so `apply` runs exactly what you reviewed.

```bash [name:plan, deps:validate]
terraform plan -out demo.tfplan
```

### Try an override (optional)

Any variable can be changed without editing a file. Watch the plan grow from 2 servers to 3.

```bash [name:plan-override, deps:validate]
TF_VAR_instance_count=3 terraform plan -out override.tfplan
```

### Try a bad value (optional)

The validation rule on `vsi_profile` stops the run before anything is planned.

```bash [name:plan-bad-profile, deps:validate]
TF_VAR_vsi_profile=cx2-2x4 terraform plan || echo "Stopped by the validation rule, as intended."
```

## 4. Apply

Builds everything in the saved plan. This takes a few minutes.

```bash [name:apply, deps:plan]
terraform apply demo.tfplan
```

## 5. Look at the result

What Terraform is tracking (state addresses use `count` and `for_each` indexes):

```bash [name:state, deps:apply]
terraform state list
```

The values printed by `outputs.tf`:

```bash [name:outputs, deps:apply]
terraform output
```

Ready-to-paste SSH commands (only exist when `enable_floating_ip` is true):

```bash [name:ssh-commands, deps:apply]
terraform output -json ssh_commands | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))'
```

Details of a single server. The address is quoted because of the `[0]` index:

```bash [name:show-vsi, deps:apply]
terraform state show 'ibm_is_instance.vsi[0]'
```

## 6. Clean up

Deletes everything this configuration created. Terraform asks you to type `yes`.
Confirm afterwards that nothing is left (`ibmcloud is vpcs`).

```bash [name:destroy]
terraform destroy
rm -f demo.tfplan override.tfplan
```
