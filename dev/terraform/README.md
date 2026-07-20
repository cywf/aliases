# Terraform Development Server

This directory contains Terraform notes/configuration for provisioning a development server.

## Current contents

- `dev-server.md` — setup notes for the development server Terraform workflow.

## Usage

1. Review `dev-server.md` before applying any infrastructure changes.
2. Configure cloud provider credentials outside the repository using your provider's standard secure mechanism.
3. Run Terraform from this directory only after reviewing the plan:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Only run `terraform apply` after reviewing the generated plan and confirming the target account/project.

## Safety notes

- Do not commit cloud credentials, API tokens, private keys, state files, or generated plans.
- Keep Terraform state in a secure remote backend when this grows beyond local experiments.
- Treat infrastructure changes as externally visible and cost-affecting.
