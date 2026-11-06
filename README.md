# Terraform on IBM Cloud: getting started

Demo Terraform for a lunch-and-learn on Infrastructure as Code on IBM Cloud. Each version
builds a small VPC with two Ubuntu virtual servers.

| Folder | Session | What it is |
|--------|---------|------------|
| [`terraform/plain/`](terraform/plain/README.md) | 101 | Hand-written `resource` and `data` blocks, no modules. Start here |
| [`terraform/modules/`](terraform/modules/README.md) | 102 | The same idea built from official `terraform-ibm-modules` registry modules, plus `count` and existing-resource lookups |
| `terraform/viewer/` | either | Optional live picture of the architecture that fills in as Terraform builds. Reads local state only |

Each folder is its own Terraform root module with its own state, tests and README.
**Run Terraform from inside `terraform/plain/` or `terraform/modules/`**, not from `terraform/`.

## Quick start

You need Terraform 1.9 or newer, an IBM Cloud account, and an existing resource group and
SSH key. The full steps are in [`terraform/plain/README.md`](terraform/plain/README.md). In short:

```bash
export IC_API_KEY="your-api-key"        # or: read -rs IC_API_KEY && export IC_API_KEY

cd terraform/plain
cp terraform.tfvars.example terraform.tfvars    # then edit it (ssh_allowed_cidr, ssh_key_name, owner_tag)
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

When you are done, run `terraform destroy`. Applying creates **billable** resources (servers,
floating IPs and a public gateway), so do not leave a stack running.

## Run the tests

Plan-only tests with mocked providers. No credentials and no cloud calls:

```bash
cd terraform/modules && terraform init && terraform test
```

(`terraform/plain/tests/` is out of date and currently fails. See [AGENTS.md](AGENTS.md).)

## Optional: mise and fnox

If you use [mise](https://mise.jdx.dev), each version folder has shortcuts (`mise run tfvars:init`,
`plan`, `apply`, `destroy`, `ws:new`). Tool versions live in `terraform/mise.toml`. API keys can
come from [fnox](https://github.com/jdx/fnox) with `fnox exec -- mise run plan`. None of this is
required; the plain `terraform` commands above work on their own.

## Live viewer

```bash
cd terraform
python3 viewer/server.py --open
```

Then run `plan` and `apply` in a second terminal. See the plain README for what you will see.

## Files that are never committed

`terraform.tfvars` (your settings), `*.tfstate*`, `tfplan` and `*.tfplan`, `*.pem`, and
`.terraform/` are git-ignored on purpose. State can contain secrets. Never paste it anywhere.

## For AI agents and contributors

Read [AGENTS.md](AGENTS.md) first. [ANALYSIS.md](ANALYSIS.md) is an earlier architecture review,
kept for ideas and not a source of truth.
