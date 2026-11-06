# AGENTS.md

Guidance for AI coding agents (IBM Bob DevSecOps, Claude Code, etc.) working in this repository.
Read this first. Keep changes small, and ask before anything marked **Ask first**.

## What this repo is

Demo Terraform for a lunch-and-learn series on Infrastructure as Code on IBM Cloud.
Session 1 is Terraform fundamentals (a 45-minute slot with a live demo). The audience is IBM
sellers and technical sellers, so clarity beats cleverness everywhere in this repo.

The repo holds a small IBM Cloud VPC + virtual server (VSI) stack that is deployed live, in
**two versions** under `terraform/`:

- `terraform/plain/` is the session 101 version: hand-written `resource` blocks, no modules.
- `terraform/modules/` is the session 102 version: official `terraform-ibm-modules`
  registry modules, plus `count` and existing-resource lookups.

The slides are **not in this repo** (they live in a separate slides repo). Do not recreate
`slides/`, `tools/` or deck files here.

## Repository layout

```
.
├── AGENTS.md              this file
├── README.md              overview and quick start
├── terraform/
│   ├── mise.toml          shared tool versions (terraform, fnox) + viewer tasks
│   ├── fnox.toml          secrets config (IBM Cloud API key comes from here)
│   ├── plain/             101 demo: versions.tf provider.tf data.tf locals.tf variables.tf
│   │                      main.tf security_group.tf compute.tf outputs.tf, plus tests/
│   ├── modules/           102 demo: versions.tf data.tf locals.tf variables.tf main.tf
│   │                      outputs.tf, plus tests/
│   └── viewer/            live architecture viewer; reads local state + terraform.tfvars
├── ANALYSIS.md            architecture review and follow-up ideas (not a source of truth)
└── _to_delete/            files staged for human deletion. Never read from or edit.
```

Each Terraform folder is its own root module with its own `mise.toml`, README, state, tests
and `terraform.tfvars.example`. **Run Terraform commands from inside `terraform/plain/` or
`terraform/modules/`**, never from `terraform/`.

## Commands

mise is optional (a new user may not have it); plain `terraform` commands always work.
Secrets come from the `IC_API_KEY` environment variable or [fnox](https://github.com/jdx/fnox),
never from files in the repo.

Run from `terraform/plain/` or `terraform/modules/`; both have the same tasks:

```bash
mise run tfvars:init        # first time only: copy terraform.tfvars.example to terraform.tfvars
mise run fmt                # terraform fmt -recursive
mise run validate           # init + terraform validate
terraform test              # plan-only tests with mocked providers, no credentials needed
fnox exec -- mise run plan  # saves <workspace>.tfplan
fnox exec -- mise run apply # Ask first (creates billable resources)
fnox exec -- mise run destroy  # Ask first
```

Any variable can be overridden without editing a file: `TF_VAR_instance_count=3 mise run plan`.

## Demo Terraform: `terraform/plain/`

- Providers (both pinned in `versions.tf`): `IBM-Cloud/ibm` `~> 2.8` and `hashicorp/random` `~> 3.6`.
- `random_string.prefix` generates a short suffix. `local.project_name` is the user's
  `var.project_name` if non-empty, otherwise `tf-<random>`. Use `local.project_name` for
  every resource name; do not reintroduce `var.name_prefix`.
- Region comes from `var.region`. Zones are discovered from `data.ibm_is_zones.regional`.
  `local.vpc_zones` holds up to 3 zones (`min(3, length(...))`). `local.primary_zone` is the first one.
- `ibm_is_subnet.main` uses `for_each` over `local.vpc_zones`: one subnet per zone.
  Only the primary zone's subnet attaches the single `ibm_is_public_gateway.primary`.
- `ibm_is_instance.vsi` uses `count = var.instance_count` and lives in the primary zone,
  on `ibm_is_subnet.main[0]`. Image is the newest matching `ibm-ubuntu-<ubuntu_version>*-amd64-*`.
  If no image matches, `local.ubuntu_image_id` is `null` and a `precondition` on the instance
  stops the plan with a readable message. Keep that guard.
- `ibm_is_floating_ip.vsi` is created only when `var.enable_floating_ip` is true.
- `var.vsi_profile` has validation (must start with `bx2-`). Keep that rule; it is shown in the (separate) slides.
- **`var.subnet_ip_count` is intentionally not wired in.** The subnet hardcodes
  `total_ipv4_address_count = 256`. The variable (and its validation) stay as they are: the
  maintainer keeps it for demonstrating `TF_VAR_` overrides. Do not "fix" this without asking.
  Note that overriding it has no effect on the plan in `plain/`; `instance_count` does.
- `vsi_private_ips` wraps its lookup in `try(..., null)` so mocked-provider tests can plan (mocks
  cannot fill the nested `primary_ip` block). Real runs are unaffected. Keep it.
- Outputs are lists/maps because of `count`/`for_each`. Use splats (`[*]`) and `for` expressions.
- Pre-existing resources are looked up with data sources (`ibm_resource_group.existing`,
  `ibm_is_ssh_key.existing`). Do not create resource groups or SSH keys here.

## Demo Terraform: `terraform/modules/`

- Providers (all pinned in `versions.tf`): `IBM-Cloud/ibm` `~> 2.8`, `hashicorp/random` `~> 3.6`,
  `hashicorp/tls` `~> 4.0`. There is no `null` provider any more.
- Registry modules are pinned to exact versions: `resource-group`, `landing-zone-vpc`,
  `security-group`, `landing-zone-vsi`. Bump them deliberately and re-run `terraform test`.
- The region and zone come from the **workspace** via `var.workspace_targets` (see `locals.tf`).
  `default` = us-south, `eu-de`, `jp-tok`. A workspace missing from the map fails a
  `precondition` on `ibm_is_subnet.main`.
- Naming uses `local.prefix`: `var.project_prefix` if set, otherwise `random_string.prefix[0]`
  (created with `count`, so it only exists when no prefix was given).
- **SSH key (by design, for the 102 session):** `var.existing_ssh_key` set means look up that key
  (`data.ibm_is_ssh_key.sshkey`); empty means generate one with `tls_private_key.ssh` and upload
  the public half. Both branches use `count` to show conditional resources. **No file is written
  to disk.** The generated private key is the sensitive output `ssh_private_key`.
  Keep this `count` pattern; it is the point of the example.
- `ibm_is_subnet.main` carries two pre-flight `precondition`s: the workspace exists in
  `workspace_targets`, and an Ubuntu image was found. Keep both.
- The VSI module's `subnets[].name` must be a fixed string (`"subnet"`), because the module builds
  `for_each` keys from it. See the comment in `main.tf` before touching it.

## Conventions

- Terraform: `terraform fmt` clean, one concern per file, a comment above each block
  explaining the idea in plain words (the audience and the maintainer are learning).
  Prefer boring, readable HCL over clever expressions.
- When you add a resource: tag it with `local.tags`, put it in the resource group
  (`data.ibm_resource_group.existing.id`), and add or update an output if a person would need
  that value during the demo.
- Variables and validation rules are duplicated across the two versions. If you change one
  (name, default, validation), check the other and say in your summary whether they now differ.
- Python (if you add scripts): simple and well commented, with docstrings that explain the logic.
  The maintainer is learning, so favour clarity over brevity.
- Prefer CLI tools over GUIs in instructions and docs.

## Security rules (DevSecOps)

These are hard rules. A change that breaks one should be refused or flagged.

- **Never commit secrets**: API keys, tokens, `*.tfvars` with real values,
  `.env*`, `terraform.tfstate*`, `.terraform/`, `tfplan`, `*.tfplan`, `*.pem`. `.gitignore`
  covers all of these; confirm it still does. `terraform/modules/eutnau.pem` is a private key on
  disk (ignored); never read or print it.
- **`terraform.tfvars` is never committed.** Only `terraform.tfvars.example` is. A new user copies it with
  `cp terraform.tfvars.example terraform.tfvars` (or `mise run tfvars:init`). Ignoring a file does not untrack one that is already
  committed: use `git rm --cached <file>`. Do not read or print a real `terraform.tfvars`.
- **Do not read or print** any credential file. Do not paste secret values
  into slides, notes, logs or commit messages.
- Terraform state can contain sensitive values (the generated SSH private key is one). Do not
  display whole state files; use `terraform state list` and `terraform state show` on single
  resources. Never print the `ssh_private_key` output unless the maintainer asks.
- Use short-lived credentials. Test API keys must be created with an expiry
  (`ibmcloud iam api-key-create <name> -e <UTC timestamp>`) and deleted afterwards.
- Least privilege: the demo only needs VPC infrastructure permissions in one resource group.
- Security group rules must stay narrow. Never open `0.0.0.0/0` on anything but what the demo
  requires (SSH only, and prefer restricting to the presenter's IP). The example tfvars files use
  the documentation address `203.0.113.7/32` on purpose, so nobody gets an open SSH rule by default.
- The modules version uses an allow-all network ACL and relies on the security group. That is
  deliberate for the demo; do not copy it into anything long-lived.
- Floating IPs expose servers to the internet. Keep `enable_floating_ip` defaulting to a
  deliberate, documented value and destroy the stack after the demo.
- Pin provider versions in `required_providers` with `~>`; do not float to latest (`>=`).
  Verify a version exists on the registry before pinning it.
- Run `terraform validate`, and a scanner such as `trivy config .` or `checkov -d .` if
  available, before proposing a Terraform change.

## Known issues and stale files

- `terraform/modules/terraform.tfvars` is still tracked in git. The maintainer must run
  `git rm --cached terraform/modules/terraform.tfvars` (do not read it).
- `ANALYSIS.md` predates several fixes (tracked tfvars, null provider, unpinned providers).

## Cost and cleanup

Applying creates billable IBM Cloud resources (VSI, floating IP, public gateway).
After a demo or test, run `terraform destroy` and confirm in the console or with
`ibmcloud is vpcs` that nothing is left. Never leave a stack running overnight.

## Ask first

Stop and ask the maintainer before you:

- run `terraform apply` or `terraform destroy`, or any `ibmcloud` command that creates or deletes things
- rename resources in a way that changes Terraform addresses (it forces replacement), for
  example switching `count` to `for_each`. The viewer in `terraform/viewer/` also reads these addresses.
- change which resources use `count` vs `for_each`; the difference is taught in the (separate) slides
- touch `_to_delete/`, state files or any credential file
- add a dependency
- change the SSH key behaviour in `terraform/modules/` (existing key vs generated key)

## Definition of done

- `terraform fmt -check -recursive`, `terraform validate` and `terraform test` pass in every
  Terraform folder you touched; `plan` reads cleanly (no surprise replacements).
- No secrets, state, plan or `terraform.tfvars` files are staged (`git status` and
  `git diff --staged` reviewed).
- The change is described in plain language, including anything that will look different on stage.

## Known gotchas

- Because `vsi` uses `count`, state addresses are `ibm_is_instance.vsi[0]`. In a shell, quote them:
  `terraform state show 'ibm_is_instance.vsi[0]'`.
- `for_each` keys are strings (`"0"`, `"1"`, `"2"`). If `ibm_is_subnet.main[0]` errors, use `["0"]`.
- Adding `resource_group` to an existing subnet or public gateway forces replacement. Expect a
  destroy/create in the plan if a stack from an older version of this code is still applied.
- Mocked-provider tests need every data source and computed nested block the code reads.
  An empty mocked `ibm_is_zones` list makes `local.vpc_zones[0]` fail, and nested blocks such as
  `primary_network_interface[0].primary_ip` need an explicit mock.
- macOS `date` is BSD: use `date -u -v+6H` rather than GNU `date -d`.
