# Launch Copy

Ready-to-post social content for platform-skills. Each blurb links to a specific asset. Edit names and handles before posting.

---

## Launch Checklist

- [ ] Confirm `bash tests/release-consistency.sh` passes
- [ ] Confirm `bash tests/validate-ci.sh` passes
- [ ] Tag and publish the GitHub release
- [ ] Pin the release announcement to the repository discussion or README issue
- [ ] Post the LinkedIn copy with a link to [BEFORE_AFTER.md](BEFORE_AFTER.md)
- [ ] Post the X/Twitter copy with one demo GIF from [examples/demo/](examples/demo/)
- [ ] Submit the Show HN draft after the release is live
- [ ] Share the Reddit draft in r/devops with a clear maintainer disclosure
- [ ] Share the internal Slack copy with [docs/TEAM_ROLLOUT.md](docs/TEAM_ROLLOUT.md)
- [ ] Submit to relevant awesome lists using [docs/AWESOME_LIST_SUBMISSIONS.md](docs/AWESOME_LIST_SUBMISSIONS.md)
- [ ] Open follow-up issues for requested domains and label them `domain-request`
- [ ] Review stars, issues, and feedback after 24 hours, 7 days, and 30 days

## Weekly Content Ideas

- Before/after: Kubernetes production review
- Before/after: Terraform wildcard IAM policy
- Before/after: Flux HelmRelease stuck or unsafe upgrade
- Before/after: GitHub Actions supply chain hardening
- Team rollout story: one platform baseline across Claude, Codex, Cursor, and Copilot
- Maintainer note: how blast radius, validation, and rollback change AI-assisted reviews

---

## LinkedIn (150 words — professional framing)

> We built platform-skills: a free, open-source field handbook for platform engineers, DevOps, and SRE teams that works inside Claude, Codex, Cursor, and GitHub Copilot.
>
> It catches the things code review misses:
> - Kubernetes containers running as root with no resource limits
> - Terraform IAM policies granting `Action: "*"` to a production role
> - Flux HelmReleases that silently upgrade to a breaking chart version
> - GitHub Actions workflows with unpinned actions and long-lived AWS keys
>
> Every finding comes with blast radius, validation steps, and a rollback plan — the same mental model a senior platform engineer brings to every review.
>
> We've got 48 reference guides, 55 example sets, demo GIFs, and prompts for platform, DevOps, SRE, security, and app teams.
>
> See it in action → https://github.com/nitinjain999/platform-skills/blob/main/BEFORE_AFTER.md
>
> Star it if it's useful: https://github.com/nitinjain999/platform-skills
>
> #platformengineering #devops #SRE #kubernetes #terraform #cloud

---

## X / Twitter (280 chars)

> We open-sourced platform-skills — a field handbook for platform engineers that works in Claude, Codex, Cursor & Copilot.
>
> It catches root containers, wildcard IAM, unpinned Flux charts, and unsecured GitHub Actions — with blast radius + rollback built in.
>
> Before/after → https://github.com/nitinjain999/platform-skills/blob/main/BEFORE_AFTER.md

---

## Reddit — r/devops

**Title:** We open-sourced a platform engineering handbook that works inside your AI coding tool

**Body:**

We've been building platform-skills for a while now and just reached a point where it feels ready for a wider audience.

**What it is:** A free, open-source field handbook for platform, DevOps, SRE, and cloud engineers. It works on GitHub as a reference, or as a plugin/skill inside Claude, Codex, Cursor, and GitHub Copilot for interactive guidance.

**What it catches:** The things that slip through code review — containers running as root, IAM policies with `Action: "*"`, Flux HelmReleases without `dependsOn` or `remediation`, GitHub Actions workflows with unpinned action SHAs and `permissions: write-all`. Every finding includes blast radius, validation commands, and rollback steps.

**What's inside:** 48 reference guides, 55 example sets, slash commands for Kubernetes, Terraform, GitOps, GitHub Actions, AWS, Linkerd, OPA, KEDA, supply chain, and more.

**Before/after examples:** https://github.com/nitinjain999/platform-skills/blob/main/BEFORE_AFTER.md
**Repo:** https://github.com/nitinjain999/platform-skills

Curious what gaps you'd want filled — happy to add domain guides for things we're missing.

---

## Hacker News — Show HN

**Title:** Show HN: Platform Skills – open-source field handbook for platform/DevOps/SRE engineers

**Body:**

platform-skills is a free, open-source field handbook for platform engineers covering Kubernetes, Terraform, Flux CD, GitHub Actions, AWS, Linkerd, OPA, and 30+ more domains. It works as a GitHub reference or as a plugin inside Claude, Codex, Cursor, and Copilot.

The model: every section starts with the problem (not the tool), includes evidence collection commands, fixes, blast radius, and a rollback plan. Before/after examples here: https://github.com/nitinjain999/platform-skills/blob/main/BEFORE_AFTER.md

Repo: https://github.com/nitinjain999/platform-skills

---

## Internal Slack

> **platform-skills is now available for our team**
>
> It's a platform engineering handbook that works inside Claude, Codex, Cursor, and Copilot — covering Kubernetes, Terraform, Flux, GitHub Actions, and AWS with blast radius, validation, and rollback guidance built in.
>
> **Rolling it out across our repos:** https://github.com/nitinjain999/platform-skills/blob/main/docs/TEAM_ROLLOUT.md
> **Prompts to try today:** https://github.com/nitinjain999/platform-skills/blob/main/PROMPTS.md
>
> If you hit a gap or find guidance that's wrong, open an issue: https://github.com/nitinjain999/platform-skills/issues
