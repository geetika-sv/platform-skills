# Platform Skills

Production-grade platform engineering workflows for Claude Code: Kubernetes, GitOps with Flux CD and Argo CD, Terraform, GitHub Actions, AWS, Azure, OpenShift, secrets, policy as code, supply chain security, observability and incident practice. Every answer includes the blast radius, validation steps and a rollback plan.

## How it works

The plugin is skills, reference guides and examples. It has no hooks and no MCP servers, starts no background process and changes no Claude Code setting.

- **Router skill.** `platform-skills` activates when you work on platform infrastructure and sends Claude to the matching reference guide.
- **Slash commands.** Each command below is an interactive workflow: it asks a few questions, then diagnoses, generates or reviews.
- **Subagent.** `platform-bulk-reader` answers one read-only discovery question across many files, with the Read, Grep and Glob tools only.
- **Bundled files.** `references/` holds the guides the skills read, `examples/` the manifests, Terraform, workflows and scripts they adapt, and `assets/` the templates that `setup-agents` renders.

## What it runs, sends and fetches

- **Commands go through Claude Code's Bash tool**, so your permission settings apply to each one. Skills run the CLIs you already use, such as `kubectl`, `helm`, `flux`, `terraform`, `gh`, `aws` and `az`, against the context, profile or account you have selected.
- **`triage` runs a bundled helper**, `examples/triage/scripts/triage_helper.py`, with your `python3`.
- **Credentials stay with their own service.** The plugin never derives, prints or stores a token. A tool that needs one, such as `zizmor` or `trivy` for private GitHub repositories, reads the variable you exported for it. Where a workflow calls an API directly, such as Dynatrace or Datadog, it sends the key you exported for that service to that service only.
- **Pull request comments are posted only when you run the workflow.** `triage` and `pr-review` reply and resolve review threads with `gh`, as the account you are signed in with.
- **Installs happen only on request.** Workflows that install a tool, such as the Kubescape CLI or a Helm chart, do it when you ask, through commands you approve. Nothing is downloaded when the plugin loads.

## Configuration

All settings are optional and none is secret: the GitOps engine (`flux`, `argocd` or `none`), the primary cloud, your AWS CLI profile naming pattern, the tag keys every resource must carry, and your GitHub organisation. Skills use them to choose defaults for examples and printed commands.

## Commands

<!-- commands -->

## Source and license

Source, issues and release notes are at https://github.com/nitinjain999/platform-skills. The plugin is licensed under Apache-2.0; see `LICENSE` and `NOTICE`.
