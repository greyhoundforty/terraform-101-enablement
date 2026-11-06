# ANALYSIS.md: Architecture review of the demo Terraform

Scope: `terraform/plain/` (hand-written resources) and `terraform/modules/` (registry modules),
read against `AGENTS.md`. No `CLAUDE.md`, `CRUSH.md` or `CONTEXT.md` exists in this repo, so
`AGENTS.md` is the guidance file. I did not review `slides/`, `terraform/viewer/`, or any
credential or state file (`auth.json`, `*.tfstate*`, `*.pem`, `terraform.tfvars`).

No code was changed. Everything under "Proposed architecture" is a sketch, not an applied edit.

---

## 1. What exists today

```
terraform/
├── plain/      ibm_is_vpc, public_gateway, subnet (for_each/zone), security_group(+rules),
│               instance (count), floating_ip (count). Flat files by concern.
├── modules/    registry modules: resource-group, landing-zone-vpc, security-group, landing-zone-vsi
│               + raw ibm_is_subnet, SSH key (tls + null_resource), workspace-driven region.
├── mise.toml / fnox.toml   tool versions, secrets
└── viewer/     live architecture viewer that reads state
```

The two variants are **sibling root modules** that share no code. They duplicate variables,
validation rules, the Ubuntu image lookup, and the CIDR and naming logic. The goal is
pedagogical: "here is the same stack without modules, and with them".

### Abstraction levels as they stand

| Level | `plain/` | `modules/` |
|---|---|---|
| L0 Provider and versions | `versions.tf`, `provider.tf` (region from a variable) | `versions.tf` (provider block inside it, region from a workspace lookup) |
| L1 Inputs and policy | `variables.tf` with validations | `variables.tf` with validations and a `workspace_targets` object map |
| L2 Derived values | `locals.tf` plus a second `locals` in `compute.tf` | single `locals.tf` (image, SSH key, naming, region all together) |
| L3 Resources | flat, one file per concern | a mix of registry modules and raw resources in one `main.tf` |
| L4 Outputs | 10 flat outputs | 3 grouped outputs |

The L2 layer is the weakest in both variants: it mixes several unrelated concerns.

---

## 2. Findings

Severity: **H** = breaks a stated rule or can fail at runtime, **M** = design smell or drift risk, **L** = polish.

### 2.1 Correctness and rule violations

| # | Sev | Finding | Where |
|---|---|---|---|
| 1 | H | `var.subnet_ip_count` is declared and validated but **never used**. The subnet hardcodes `256`, so changing the variable does nothing. | `plain/main.tf:32` vs `plain/variables.tf:64` |
| 2 | H | `random_string` is used but `hashicorp/random` is **not in `required_providers`**. This breaks AGENTS.md's "pin provider versions" rule. It works only through implicit provider resolution. | `plain/versions.tf` |
| 3 | H | `random`, `tls` and `null` are pinned `>=`, which floats to latest, not `~>`. | `modules/versions.tf:19,23,27` |
| 4 | H | Image selection indexes `[length(...) - 1]`. If no image matches (wrong `ubuntu_version`, or a region without it), the error is `Invalid index -1`, not a readable message. | `plain/compute.tf:12`, `modules/locals.tf:50` |
| 5 | M | The tag `"region:"` is empty in plain, and `"demo:delete_me_11072026"` is a hardcoded date inside `locals`. | `plain/locals.tf:19-22` |
| 6 | M | AGENTS.md says "tag every resource with `local.tags` and put it in the resource group". In plain, the **instance, floating IP, security group, subnet and public gateway are untagged**, and the gateway and subnet are missing `resource_group`. They land in the account default group. | `plain/compute.tf`, `plain/security_group.tf`, `plain/main.tf` |
| 7 | M | `terraform/modules/terraform.tfvars` is **tracked in git** although `.gitignore` ignores `*.tfvars`. The ignore comment also says "Commit terraform.tfvars", which contradicts the rule below it. I did not open the file; check it holds no real values. | `.gitignore:13-17`, `git ls-files` |
| 8 | M | The modules variant **generates an SSH key**, but AGENTS.md says "Do not create resource groups or SSH keys here". The private key is also stored in plaintext in state via `tls_private_key`. | `modules/main.tf:33-58` |
| 9 | M | The private key is written with `echo '<key>' > file` inside a `local-exec`. The key is interpolated into a shell command line, and `null_resource` is deprecated in favour of `terraform_data`. | `modules/main.tf:49-58` |
| 10 | M | The network ACL is allow-all in and out, so the ACL layer does no filtering. The security group is the only control. Fine for a demo, but it should be explicit that it is deliberate. | `modules/main.tf:86-109` |

### 2.2 Design and abstraction

| # | Sev | Finding |
|---|---|---|
| 11 | M | **Two `locals` blocks in plain** (`locals.tf` and `compute.tf`). The modules header comment warns against exactly this. Image logic sits beside the VSI, which is fine for reading, but it breaks the "one place for locals" convention. |
| 12 | M | **Hidden cross-file coupling in plain.** `locals.tf` references `random_string.prefix` (defined in `main.tf`), and `compute.tf` reads `data.ibm_is_images` (from `data.tf`). Readers must jump files to follow the name. |
| 13 | M | **Three subnets, one used.** Plain builds a subnet in each of up to 3 zones, but VSIs live only in `ibm_is_subnet.main[0]` and only zone 0 gets a gateway. That is more to explain on stage and more to destroy. |
| 14 | M | **`count` on VSIs.** Instances are addressed by position (`vsi[0]`, `vsi[1]`). Reducing `instance_count` always removes the last one, but removing a *specific* server reshuffles the rest. This is a good teaching moment, but it should be labelled as a trade-off. The `[0]` vs `["0"]` gotcha in AGENTS.md comes from the same index-vs-key mixing. |
| 15 | M | **Mixed abstraction in `modules/main.tf`.** It uses registry modules for VPC, SG and VSI, then drops to a raw `ibm_is_subnet` because the VPC module is given `subnets = { zone-N = null }`. The ACL is then fetched back out with `module.vpc.network_acls[0].id`. The reader sees two mental models in one file. |
| 16 | M | **Fragile module seam.** The VSI module's `subnets[].name` must be a fixed string (`"subnet"`) because the module builds `for_each` keys from it. The comment explains it well, but the workaround is a trap for the next maintainer. |
| 17 | M | **Workspaces used as a region selector.** `terraform.workspace` drives `provider.region` through `lookup()`. Workspaces are meant to isolate *state of the same config*. Using them as a region switch hides a deployment decision inside a CLI command, makes the provider block depend on a lookup with a silent `try()` fallback to `us-south`, and means a typo'd workspace still starts the provider. The precondition catches it only on the subnet, after the provider is configured. |
| 18 | L | **Name drift between variants.** `project_name` vs `project_prefix`, `ssh_key_name` vs `existing_ssh_key`, and a 4-letter vs a 6-letter random suffix. The same idea has two names. |
| 19 | L | **Provider config lives in different places.** `provider.tf` in plain, inline in `versions.tf` in modules. |
| 20 | L | **Flat vs grouped outputs.** Plain has 10 outputs, modules has 3 shaped objects. Both are valid, but it is unclear which style the deck teaches. |

### 2.3 Documentation drift (AGENTS.md vs reality)

AGENTS.md was written for an earlier layout. Several statements no longer hold:

- It says demo `*.tf` files live at the repo root with a TODO to confirm. They are in `terraform/plain/` and `terraform/modules/`.
- It says "`ibm_is_subnet.main` uses `for_each`... Only the primary zone's subnet attaches the gateway". That is true of plain only.
- It says providers are `IBM-Cloud/ibm` and `hashicorp/random`. Modules also uses `tls` and `null`, and plain does not declare `random`.
- It does not mention `modules/`, workspaces, the `viewer/`, `tests/`, or the two-variant split.
- `terraform apply` examples assume the Terraform directory is the cwd, which is now ambiguous.

---

## 3. Pros and cons of the current implementation

| Aspect | Pros | Cons |
|---|---|---|
| **Two variants side by side** | Powerful teaching device: same outcome, hand-written vs modules. Easy to explain "what modules save you". | Zero shared code. Variables, validations and image logic are copy-pasted and already drifting (#18). Every fix is made twice. |
| **File-per-concern layout (plain)** | Matches the Terraform convention. Small files with a header comment. Easy to point at on a slide. | Locals are split across two files (#11). Naming logic is hidden across `main.tf` and `locals.tf` (#12). |
| **Variable validation** | `vsi_profile`, `ssh_allowed_cidr` and `subnet_ip_count` all fail early with a readable message. They are shown on a slide. | One validated variable is dead code (#1). `instance_count` has no bounds check, so `-1` or `500` plans fine. |
| **Data-source lookups for existing things** | Respects "don't create resource groups/SSH keys". Region-independent image lookup. | Image selection is a string-sort heuristic and fails opaquely (#4). `ibm_is_images` lists *every* public image, which is slow and noisy. |
| **Security posture** | SSH and ICMP are restricted to a CIDR with no default. The API key comes from `fnox` and the environment. `auth.json`, state and plans are gitignored. | A tracked `tfvars` (#7), a generated key in state (#8), and secret material in a shell command (#9). |
| **Registry modules (modules/)** | Less code per outcome. Pinned exact versions (`1.6.1`, `10.1.7`, `2.11.0`, `8.3.5`). Realistic to what customers do. | Mixed with raw resources (#15). The `name = "subnet"` constraint (#16). Plan time and download cost. Debugging means reading module internals. |
| **Workspaces for regions** | One config, three regions. A good demo of workspaces. | Misuses the feature (#17). Hidden fallback to `us-south`. The provider depends on a lookup. |
| **`count` / `for_each` mix** | Shows both patterns on real resources. The comments explain them in plain words. | Index-keyed instances reshuffle (#14). Subnets use string-keyed `for_each` and instances use numeric `count`, so the same stack uses two address styles. |
| **Comments and readability** | Audience-appropriate comments above each block. Plain-language headers. | Some comments are long and carry design rationale (e.g. the VSI seam) that belongs in a doc, not in HCL. |
| **Tests** | Both variants have plan-only `tftest.hcl` with mocked providers and overridden modules, so they need no credentials. | The tests mirror the structure, so a refactor breaks them in lockstep. I did not run them. |
| **Tags and governance** | A `local.tags` list exists and is applied to the VPC, gateway and subnets. | Not applied everywhere in plain (#6). Empty `region:` tag (#5). A hardcoded demo date. |
| **Tooling** | `mise` for tasks, `fnox` for secrets, and a live `viewer` for the demo. | Tool version `terraform = "1.17"` in `terraform/mise.toml` should be checked against what actually exists (per your rule to verify pinned versions). I did not verify it. |

---

## 4. Proposed architecture

The aim is to keep both teaching variants, but give them a **common spine** so they cannot
drift, and to push policy into one place. Each change is independent, so you can adopt only the ones worth the stage time.

### 4.1 Layout: shared inputs, thin stacks, local child modules

```
terraform/
├── shared/                  # not a root module: pure files symlinked or copied by a script
│   ├── variables.common.tf  # region, vsi_profile, ssh_allowed_cidr, instance_count, ...
│   └── image.tf             # one tested image lookup
├── modules/                 # LOCAL child modules (teaches "write your own module")
│   ├── network/             # vpc + gateway + subnets + acl
│   ├── firewall/            # security group + rules
│   └── compute/             # image lookup + instances + floating ips
├── plain/                   # flat, everything inline (the "before" picture)
└── registry/                # was modules/: same shape, but backed by registry modules
```

Teaching arc becomes three steps instead of two: **flat → your own modules → registry
modules**. Each step has the same inputs and outputs.

### 4.2 Fix the dead input and make tags a single source of truth

```hcl
# plain/main.tf: use the variable that already exists
resource "ibm_is_subnet" "main" {
  for_each                 = local.vpc_zones
  total_ipv4_address_count = var.subnet_ip_count   # was: 256
  # ...
}
```

```hcl
# locals.tf: one tags definition; resources never build their own
locals {
  tags = [
    "project:${local.project_name}",
    "owner:${var.owner_tag}",
    "region:${var.region}",                  # was the empty "region:"
    "expires:${var.expiry_date}",            # variable, not a hardcoded date
  ]
}
```

### 4.3 Make the image lookup safe and reusable

Replace the sort-and-index trick with a module that fails with words.

```hcl
# modules/compute/image.tf
locals {
  matches = sort([
    for img in data.ibm_is_images.public.images : img.name
    if startswith(img.name, "ibm-ubuntu-${var.ubuntu_version}") && strcontains(img.name, "-amd64-")
  ])
  image_name = try(element(local.matches, length(local.matches) - 1), null)
}

data "ibm_is_image" "ubuntu" {
  name = local.image_name

  lifecycle {
    precondition {
      condition     = local.image_name != null
      error_message = "No Ubuntu ${var.ubuntu_version} amd64 image in ${var.region}. Try 24-04 or 22-04."
    }
  }
}
# consumers use data.ibm_is_image.ubuntu.id; one place to fix, one place to test
```

### 4.4 Key instances by name, not position

```hcl
# compute: stable addresses, removing "web-2" does not touch "web-1"
locals {
  servers = { for i in range(var.instance_count) : "${local.project_name}-vsi-${i + 1}" => i }
}

resource "ibm_is_instance" "vsi" {
  for_each = local.servers
  name     = each.key
  # ...
}

resource "ibm_is_floating_ip" "vsi" {
  for_each = var.enable_floating_ip ? local.servers : {}
  target   = ibm_is_instance.vsi[each.key].primary_network_interface[0].id
  # ...
}
```

State addresses become `ibm_is_instance.vsi["…-vsi-1"]`. Keep `count` in the slide version if
index-vs-key is the point of that slide, and say so in a comment.

### 4.5 Region as an explicit input, not a workspace side effect

```hcl
# variables.tf
variable "region" {
  type    = string
  default = "us-south"
  validation {
    condition     = contains(["us-south", "eu-de", "jp-tok"], var.region)
    error_message = "region must be one of us-south, eu-de, jp-tok."
  }
}

# provider.tf: no lookup, no try() fallback, no surprise default
provider "ibm" { region = var.region }
```

```bash
# one folder of per-region var files; workspaces remain available for *environments*
terraform plan -var-file=regions/eu-de.tfvars
```

The error for a bad region is then raised at variable time, before the provider starts.

### 4.6 Remove the generated-key machinery

Pick one of these and say it in AGENTS.md:

```hcl
# Option A: follow the rule: require an existing key (plain already does this)
variable "ssh_key_name" { type = string }   # no default, no generation

# Option B: keep generation, but write the file safely and keep the key out of the shell
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh[0].private_key_openssh
  filename        = "${path.module}/${local.prefix}.pem"
  file_permission = "0400"
}
```

Option A matches your rules and removes `tls`, `null` and the key-in-state problem. Option B is
better than today, but it still stores the key in state.

### 4.7 Use `check` and `postcondition` for the demo guardrails

```hcl
# Warn (do not fail) when the stack would be left exposed
check "floating_ip_is_deliberate" {
  assert {
    condition     = !var.enable_floating_ip || var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "Floating IPs are on and SSH is open to the world. Narrow ssh_allowed_cidr."
  }
}

# Fail the plan if the ACL is meant to be allow-all but the SG is not narrow
resource "ibm_is_security_group_rule" "ssh_in" {
  # ...
  lifecycle {
    precondition {
      condition     = var.ssh_allowed_cidr != "0.0.0.0/0"
      error_message = "Refusing to open SSH to 0.0.0.0/0."
    }
  }
}
```

This turns the prose security rules in AGENTS.md into things Terraform enforces.

### 4.8 Pin everything consistently

```hcl
required_providers {
  ibm    = { source = "IBM-Cloud/ibm",       version = "~> 2.8" }
  random = { source = "hashicorp/random",    version = "~> 3.6" }  # was missing in plain, >= in modules
}
```

Verify each version exists on the registry before pinning, as your own rules require.

---

## 5. Suggested order of work

| Priority | Change | Effort | Why first |
|---|---|---|---|
| 1 | Use `var.subnet_ip_count` (#1) and declare `random` (#2, #3) | Minutes | These are plain bugs and rule breaks |
| 2 | Tag and resource-group everything in plain (#5, #6) | Small | Satisfies AGENTS.md as written |
| 3 | Safe image lookup (§4.3) | Small | Removes the one opaque runtime failure |
| 4 | Decide on the SSH key (§4.6), then check the tracked `tfvars` (#7) | Small, needs a decision | Security posture |
| 5 | Update AGENTS.md to match the real layout (§2.3) | Small | Agents read it first, so stale guidance causes wrong edits |
| 6 | Region as input (§4.5) | Medium, touches the deck | Changes what you say on stage |
| 7 | Shared spine and local child modules (§4.1) | Large | Only worth it if you will keep both variants long term |

Items 5 to 7 need your sign-off under AGENTS.md ("Ask first": anything that changes slide
content, Terraform addresses, or adds dependencies). §4.4 changes state addresses and forces
replacement of existing instances.

## 6. Limits of this review

- I read the `.tf` files, both `mise.toml`/README entry points, `.gitignore` and the start of
  `modules/tests/main.tftest.hcl`. I did **not** run `terraform validate`, `plan`, the tests, or a
  scanner (`trivy`/`checkov`), so nothing here is verified against provider behaviour.
- The claim that the `landing-zone-vpc` module creates no subnets for `zone-N = null` is inferred
  from how `main.tf` is written, not from reading the module source.
- `terraform/viewer/` parses state by resource address, so renames in §4 would need to be checked
  against it. I did not read it.
