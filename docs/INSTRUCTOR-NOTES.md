# 👩‍🏫 Instructor Notes

## Workshop Overview

**Title:** Preventing Production Database Disasters — A Hands-On Exercise
**Duration:** 1.5–2 hours (instructor-led) or 2–3 hours (self-paced)
**Audience:** Azure engineers, DevOps engineers, platform engineers, SREs, and developers working with IaC on Azure
**Prerequisites:** Docker, basic Terraform knowledge, Git

## Suggested Timeline

| Time | Activity | Step |
|---|---|---|
| 0:00–0:10 | Introduction and incident overview | Slides / discussion |
| 0:10–0:25 | Step 1: Build production environment | Hands-on |
| 0:25–0:45 | Step 2: Simulate the incident | Hands-on + discussion |
| 0:45–0:55 | Step 3: Recovery | Hands-on |
| 0:55–1:05 | Break | — |
| 1:05–1:20 | Step 4: Azure guardrails | Review + discussion |
| 1:20–1:40 | Step 5: GitHub guardrails | Hands-on |
| 1:40–1:55 | Step 6: Copilot CLI guardrails | Hands-on + reflection |
| 1:55–2:00 | Wrap-up and key takeaways | Discussion |

## Discussion Prompts by Step

### After Step 2 (The Incident)
- "At which exact point could this have been prevented?"
- "Who has had a 'close call' with production infrastructure?"
- "Should AI agents ever be allowed to run `terraform destroy`?"

### After Step 3 (Recovery)
- "What would happen if there were no backups at all?"
- "How long would recovery take in YOUR infrastructure?"
- "How often do you TEST your backups?"

### After Step 4 (Azure Guardrails)
- "Are resource locks a silver bullet? What are the downsides?"
- "How do immutable backups differ from automated snapshots?"
- "Who in your org would need to approve lock removal?"

### After Step 5 (GitHub Guardrails)
- "Do you have CODEOWNERS for infrastructure files today?"
- "What does your IaC deployment pipeline look like?"
- "How would you handle emergency changes that bypass the pipeline?"

### After Step 6 (Copilot CLI)
- "How do you balance AI productivity with safety?"
- "What custom instructions would you write for your infrastructure?"
- "Is 'human-in-the-loop' enough, or do we need 'human-in-command'?"

## Common Questions

**Q: Can this really happen with proper CI/CD?**
A: Yes — the article describes a case where infrastructure was managed locally, bypassing CI/CD. The exercise demonstrates why enforcing CI/CD for IaC is critical.

**Q: Isn't this just a Terraform problem?**
A: No. The root causes (local state, unrestricted AI access, no deletion protection) apply to any IaC tool. Pulumi, CloudFormation, Bicep — all need similar guardrails.

**Q: What if learners don't have Copilot CLI for Step 6?**
A: Step 6 can be completed without Copilot CLI installed. The custom instructions file and reflection can be written based on the documentation provided.

**Q: Is the local simulation good enough?**
A: For this exercise, yes. The key lesson is about the failure chain and guardrails, not about specific cloud API behavior. The local simulation (Azurite for state backend, PostgreSQL for the database) provides enough realism. The original incident was on AWS, but the same failure chain applies to Azure — replace RDS with PostgreSQL Flexible Server, S3 with Blob Storage, ECS with Container Apps.

## Setup Requirements

- Each learner needs: Docker Desktop, Terraform CLI, Git
- The GitHub template repo should be accessible (public or org-internal)
- Internet access needed for: Docker image pulls, exercise-toolkit workflows
- ~2GB disk space for Docker images
- Copilot CLI optional but recommended for Step 6

## Tips for Facilitators

1. **Let Step 2 sink in** — the simulation is intentionally dramatic. Give learners time to process.
2. **Encourage discussion** — the best learning comes from sharing real-world experiences.
3. **Don't rush Steps 5-6** — these are the actionable takeaways learners will apply at work.
4. **Share the original article** — reading the author's perspective adds empathy and realism.
5. **Customize for your org** — the exercise defaults to Azure. If your org uses AWS, refer to the AWS-AZURE-MAPPING.md for the original AWS context.
