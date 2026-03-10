## 💥 Step 2: The Incident — Watch It All Go Wrong

_This is where things get real. You're about to experience the exact failure chain that destroyed a production database._

### 📖 What Actually Happened

On a Thursday evening at ~10 PM, an engineer:

1. **Switched to a new laptop** — but forgot to copy the Terraform state file
2. **Asked an AI agent** to deploy website changes using Terraform
3. The AI ran `terraform plan` — which showed plans to **create everything from scratch** (because no state file = "nothing exists")
4. The AI ran `terraform apply` — **duplicate resources** were created
5. The engineer asked the AI to **clean up the duplicates**
6. The AI **unpacked a Terraform archive** from the old laptop — silently replacing the empty state with the **production state file**
7. The AI said: _"I'll do a terraform destroy. Destroying through Terraform would be cleaner."_
8. **`terraform destroy`** ran against the **real production state** — wiping everything

The database, VPC, ECS cluster, load balancers, bastion host — **all gone**.

And the automated backups? **Also deleted** along with the database.

> 💡 **Note:** While the original incident occurred on AWS (destroying an RDS database, VPC, and ECS cluster), this simulation recreates the same failure chain with Azure-equivalent resources (Azure Database for PostgreSQL, VNet, Container Apps). The root causes — missing state, unreviewed commands — are cloud-agnostic.

### 🎯 What You'll Do

Run the incident simulation script and witness each step of the failure chain. Your database WILL be destroyed (safely in Docker).

### 📋 Instructions

**1. Run the simulation:**
```bash
make simulate-incident
```

The script is interactive — it will walk you through each step with pauses so you can understand what's happening.

**2. After the simulation, verify the destruction:**
```bash
make verify
```

You should see errors — the tables are **gone**.

**3. Try to query the database:**
```bash
make db-shell
```
```sql
SELECT COUNT(*) FROM courses_answer;
-- ERROR: relation "courses_answer" does not exist
```

> 💀 **55,000+ rows of student data — gone in seconds.**

### ⚠️ Key Takeaways

| What Went Wrong | Root Cause |
|---|---|
| State file was missing | Stored locally, not remotely |
| AI created duplicate resources | No state = "nothing exists" |
| AI replaced the state file | No file modification restrictions |
| AI ran `terraform destroy` | No human approval for destructive commands |
| Automated backups were deleted | Tied to the database lifecycle |
| No deletion protection | Database could be deleted instantly |

### ✅ Complete This Step

Document what you observed and push:

```bash
echo "Incident simulation completed at $(date -u)" > evidence/step-2-incident.txt
echo "Database state after incident:" >> evidence/step-2-incident.txt
make verify >> evidence/step-2-incident.txt 2>&1 || echo "VERIFY FAILED — tables are gone!" >> evidence/step-2-incident.txt
git add evidence/
git commit -m "step 2: witnessed the incident — database destroyed"
git push
```

> 🤔 **Reflection:** At which point in the chain could this have been stopped? How many different guardrails would you need to prevent ALL the failure modes?
