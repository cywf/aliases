# Testing

This repository is mostly shell scripts, Python utilities, and operational documentation. The validation baseline is intentionally non-destructive: it checks syntax only and does not run installers, provision cloud infrastructure, format disks, change firewall rules, or call Docker.

## Local validation

Run the repository validation script from the repo root:

```bash
bash scripts/validate.sh
```

The script currently verifies:

- every committed `*.sh` file parses with `bash -n`
- every committed `*.py` file compiles with `python3 -m py_compile` semantics

## CI validation

GitHub Actions runs the same validation on every pull request and push to `main` via `.github/workflows/validation.yml`.

## Manual testing expectations

For scripts with external side effects, test in a disposable VM or lab machine first:

- install scripts may change packages and services
- USB helpers may format or write block devices
- stack scripts may create billable cloud resources
- network scripts may alter routes, firewall rules, or VPN membership

Record the test host, command, and observable result in the pull request body before merging behavior-changing changes.
