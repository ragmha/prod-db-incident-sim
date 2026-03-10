## 🛡️ Step 5: GitHub Guardrails — Gate Your Deployments

_No one should be able to `terraform destroy` production without a PR review, an environment approval, and a linked incident issue._

### 📖 What This Fixes

In the real incident:
- ❌ No code review before infrastructure changes
- ❌ No approval gate before `terraform apply` or `terraform destroy`
- ❌ No audit trail of who authorized what
- ❌ Infrastructure code for multiple projects was co-located

GitHub provides built-in features that create **human checkpoints** at every critical stage.

### 🎯 What You'll Do

Complete 4 template files that implement GitHub-native guardrails:

1. **CODEOWNERS** — Require infrastructure team review for Terraform changes
2. **terraform-plan.yml** — Run `terraform plan` on every PR (read-only)
3. **terraform-apply.yml** — Apply only after merge + environment approval
4. **terraform-destroy.yml** — Manual-only destroy with maximum friction

### 📋 Instructions

**1. Complete CODEOWNERS:**

Open `infrastructure/guardrails/templates/CODEOWNERS.template` and fill in the TODO sections.

When done, copy it to the right location:
```bash
cp infrastructure/guardrails/templates/CODEOWNERS.template CODEOWNERS
# Edit to fill in the TODOs
```

**2. Complete the Terraform Plan workflow:**

Open `infrastructure/guardrails/templates/terraform-plan.yml.template` and fill in the TODO sections.

```bash
cp infrastructure/guardrails/templates/terraform-plan.yml.template .github/workflows/terraform-plan.yml
# Edit to fill in the TODOs
```

**3. Complete the Terraform Apply workflow:**

Open `infrastructure/guardrails/templates/terraform-apply.yml.template` and fill in the TODOs.

```bash
cp infrastructure/guardrails/templates/terraform-apply.yml.template .github/workflows/terraform-apply.yml
```

**4. Complete the Terraform Destroy workflow:**

This is the most important one. Open `infrastructure/guardrails/templates/terraform-destroy.yml.template`.

```bash
cp infrastructure/guardrails/templates/terraform-destroy.yml.template .github/workflows/terraform-destroy.yml
```

**5. Open a PR to see your guardrails in action:**

```bash
git checkout -b add-github-guardrails
git add CODEOWNERS .github/workflows/terraform-*.yml
git commit -m "feat: add GitHub guardrails for infrastructure protection"
git push -u origin add-github-guardrails
```

Then open a PR from your branch → you should see the plan workflow trigger!

### 🛡️ How Each Guardrail Prevents the Incident

| Incident Step | Guardrail | How It Helps |
|---|---|---|
| AI modifies Terraform files | **CODEOWNERS** | Changes require team review |
| AI runs `terraform apply` | **Plan workflow** | Plan is visible in PR before any apply |
| Apply without approval | **Environment** | Required reviewers must approve |
| AI runs `terraform destroy` | **Destroy workflow** | Manual trigger + confirmation + issue link |
| No audit trail | **GitHub Actions log** | Every action is logged and attributable |

### 💡 Stuck?

Check `solutions/step-5-github/` for reference implementations.

### ✅ Complete This Step

Push your completed guardrail files:

```bash
git add CODEOWNERS .github/workflows/terraform-*.yml
git commit -m "step 5: GitHub guardrails implemented"
git push
```
