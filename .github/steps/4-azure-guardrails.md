## 🔒 Step 4: Azure Guardrails — Lock It Down

_Now that you've experienced the incident and recovery, let's make sure it can never happen again. We'll implement Azure infrastructure protections._

### 📖 Azure Infrastructure Protection

Here are the Azure guardrails that would have prevented this incident in your environment:

| Protection | Azure Feature | How It Helps |
|---|---|---|
| Deletion prevention | **Resource Locks** (CanNotDelete, ReadOnly) | Locks apply at ARM level, outside Terraform — `terraform destroy` fails |
| Backup survival | **Backup Vault** with immutability | Backups survive resource deletion — even admins can't delete them early |
| State locking | **Blob Storage** with lease-based locking | Prevents concurrent modifications and the "new laptop" problem |
| Policy enforcement | **Azure Policy** | Enforce organizational rules across all subscriptions |

### 🎯 What You'll Do

1. Study the Azure guardrail Terraform configurations
2. Understand how resource locks block `terraform destroy`
3. Learn about immutable backup vaults
4. Set up remote state to prevent the "new laptop" problem

### 📋 Instructions

**1. Study the Azure guardrail files:**

```bash
# These are already complete — study them carefully
cat infrastructure/guardrails/azure/resource-locks.tf
cat infrastructure/guardrails/azure/backup-policy.tf
cat infrastructure/guardrails/azure/remote-state.tf
```

**2. Understand Resource Locks:**

The key concept — a `CanNotDelete` lock on the database means:
```hcl
resource "azurerm_management_lock" "database_lock" {
  name       = "database-cannot-delete"
  scope      = azurerm_postgresql_flexible_server.production.id
  lock_level = "CanNotDelete"
}
```

If someone (human OR AI agent) runs `terraform destroy`:
```
Error: deleting Resource: the scope is locked with a CanNotDelete lock.
Please remove the lock and try again.
```

**The destroy FAILS.** The database survives. ✅

**3. Understand Immutable Backups:**

Azure Backup Vault with immutability:
- Backups are stored **independently** of the database
- Even if the database is deleted, backups remain
- Immutability policy means even **admins** can't delete them early
- This directly prevents the real incident's worst moment: "backups were deleted too"

**4. Understand Remote State:**

The ROOT CAUSE of the incident was local Terraform state:
```
Old laptop → has state file → knows about infrastructure
New laptop → no state file → thinks nothing exists
```

Azure Blob Storage with lease-based locking:
- State stored centrally, not on any laptop
- Lease prevents concurrent modifications
- Versioning preserves history of state changes

**5. Review the resource mapping reference:**
```bash
cat docs/AWS-AZURE-MAPPING.md
```

### ✅ Complete This Step

Document your understanding and push:

```bash
echo "Azure Guardrails Review - $(date -u)" > evidence/step-4-azure.txt
echo "" >> evidence/step-4-azure.txt
echo "Key protections that would have prevented the incident:" >> evidence/step-4-azure.txt
echo "1. Resource Locks — terraform destroy would FAIL" >> evidence/step-4-azure.txt
echo "2. Immutable Backups — backups survive resource deletion" >> evidence/step-4-azure.txt
echo "3. Remote State — no 'new laptop' problem" >> evidence/step-4-azure.txt
git add evidence/
git commit -m "step 4: Azure guardrails reviewed"
git push
```

> 🤔 **Reflection:** Resource locks add friction to destructive operations. Is there a downside to having locks on everything? When would you want to temporarily remove a lock?
