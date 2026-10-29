## Finished: the incident is now a regression test

You replayed a real incident, recovered from an independent backup, wrote a blameless
postmortem, and built guardrails at every layer the failure crossed:

| Layer | What now stops the incident |
| --- | --- |
| State | A fresh clone reads shared state, so it never plans to create production again |
| Configuration | `prevent_destroy` stops a routine destroy before it starts |
| Backups | Automated backups survive deletion, and CI drills the independent restore |
| Ownership | CODEOWNERS covers infrastructure, hooks, and workflows |
| Agent | Hooks deny destructive tool calls before they run |
| Release | CI fails if the incident returns, and a human approves every production change |

That's the agentic SDLC loop: agents investigate and propose, pipelines enforce, and
humans decide. Each production failure becomes a test that keeps it from happening again.

### Clean up

Run `make teardown` to delete the lab's containers, state, and backups. Stop or delete
your Codespace. If you no longer need it, remove the `production` environment in
**Settings → Environments**.

### Take it to your platform

- Map each layer to your cloud with [the AWS and Azure mapping](https://github.com/{{repository}}/blob/{{branch}}/docs/AWS-AZURE-MAPPING.md)
  and the reference Terraform in `infrastructure/azure`: resource locks, an immutable
  backup vault, and remote state with locking.
- Start your own hook policy from the one you wrote, and replay your team's own risky
  commands through it.
- Schedule restore drills. A backup you have never restored is a hope, not a plan.

This lab is a teaching model, not a production-readiness review of your systems.
