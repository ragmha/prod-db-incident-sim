# AWS → Azure Service Mapping Reference

> This document maps the AWS services from the original incident to their Azure equivalents in **your** environment. Use it to understand how the original AWS failure modes translate to Azure, and what protections Azure provides natively.

---

## Table of Contents

1. [Service Mapping Table](#1-service-mapping-table)
2. [Protection Mechanism Comparison](#2-protection-mechanism-comparison)
3. [Terraform Backend Configuration Comparison](#3-terraform-backend-configuration-comparison)
4. ["What Would Have Happened in Azure?"](#4-what-would-have-happened-in-azure)
5. [Key Takeaways](#5-key-takeaways)

---

## 1. Service Mapping Table

A detailed mapping of every AWS service referenced in the incident to its Azure counterpart.

| Category | AWS Service | Azure Equivalent | Notes |
|---|---|---|---|
| **Database** | RDS (PostgreSQL) | Azure Database for PostgreSQL Flexible Server | Both support automated backups, point-in-time restore, read replicas, and high availability configurations. Azure Flexible Server is the recommended deployment option (Single Server is deprecated). |
| **Object Storage** | S3 | Azure Blob Storage | Used for Terraform state files, database backups, and static assets. Both offer tiering (S3 Standard/IA/Glacier ↔ Hot/Cool/Cold/Archive), versioning, and lifecycle policies. |
| **Compute (Containers)** | ECS (Fargate) | Azure Container Apps / AKS | Azure Container Apps is the closest Fargate analog (serverless containers). AKS provides full Kubernetes control, similar to ECS on EC2. |
| **Networking** | VPC | Azure Virtual Network (VNet) | Private network isolation. Both support subnets, route tables, and network security rules. Azure VNets are regional; AWS VPCs are also regional with AZ-scoped subnets. |
| **Load Balancing** | Application Load Balancer (ALB) | Azure Application Gateway / Azure Front Door | Layer 7 (HTTP/HTTPS) load balancing. Application Gateway is regional; Front Door is global with built-in CDN and WAF. |
| **Serverless** | Lambda | Azure Functions | Event-driven compute for backup automation and operational tasks. Both support multiple runtimes and event triggers. Azure Functions can run in a Consumption (pay-per-execution) or Premium plan. |
| **Orchestration** | Step Functions | Azure Durable Functions / Logic Apps | Backup verification workflows. Durable Functions is code-first (C#, JS, Python). Logic Apps is low-code/visual with 400+ connectors. |
| **DNS** | Route 53 | Azure DNS | Domain management and DNS resolution. Route 53 also offers domain registration; Azure DNS does not (use App Service Domains or a third-party registrar). |
| **Bastion / Jump Box** | EC2 Bastion Host | Azure Bastion | Secure RDP/SSH access without exposing VMs to the public internet. Azure Bastion is a fully managed PaaS service — no OS patching required. |
| **IaC State Storage** | S3 + DynamoDB (state locking) | Azure Blob Storage + Lease Locking | Terraform remote state backend. Azure uses native blob lease for state locking — no separate locking resource needed. |
| **Identity & Access** | IAM Roles / Policies | Azure RBAC + Managed Identities | Access control. AWS uses policy documents attached to roles; Azure uses role assignments scoped to resources/groups/subscriptions. Managed Identities eliminate credential management, analogous to IAM Roles for EC2/ECS. |
| **Support** | AWS Business Support | Azure Support Plans (Standard / Professional Direct) | Incident response and technical support. AWS Business Support starts at $100/mo or 10% of monthly bill. Azure Standard starts at $100/mo; Professional Direct at ~$1,000/mo. |
| **Infrastructure as Code** | CloudFormation (native) / Terraform | Azure Resource Manager (ARM) Templates / Bicep / Terraform | Terraform is cloud-agnostic and used in both ecosystems. Bicep is Azure's modern IaC DSL, compiling to ARM templates. |
| **Monitoring** | CloudWatch | Azure Monitor / Log Analytics | Metrics, logs, and alerting. Azure Monitor is the umbrella; Log Analytics (KQL-based) is the query engine. |
| **Secrets Management** | Secrets Manager / SSM Parameter Store | Azure Key Vault | Database credentials, API keys, certificates. Key Vault also handles HSM-backed keys and certificate lifecycle. |

---

## 2. Protection Mechanism Comparison

How each platform protects against accidental deletion — the core theme of this incident.

| Protection | AWS | Azure | Advantage |
|---|---|---|---|
| **Resource deletion protection** | RDS Deletion Protection flag (per-resource, can be toggled) | Azure Resource Locks (`CanNotDelete`, `ReadOnly`) | **Azure** — locks apply at the ARM level, _outside_ Terraform's control plane. A `CanNotDelete` lock blocks deletion even if Terraform plans a destroy. AWS Deletion Protection is a resource attribute that Terraform _can_ disable in the same apply. |
| **Backup immutability** | RDS automated snapshots (⚠️ deleted when the instance is deleted!) | Azure Backup with immutability policies (vault-based) | **Azure** — backups stored in a Recovery Services Vault are independent of the source resource. Immutability policies prevent even admins from deleting backups before retention expires. |
| **Manual snapshots** | RDS manual snapshots (survive deletion) | Azure Database manual backups / long-term retention | **Similar** — both platforms retain manual snapshots independently. The critical difference is that AWS _automated_ snapshots are lost on deletion. |
| **State locking** | DynamoDB table (separate resource to provision) | Blob lease-based locking (built into the storage account) | **Azure** — simpler setup. No additional resource needed; lease locking is native to the blob backend. |
| **Policy enforcement** | AWS Organizations SCPs (Service Control Policies) | Azure Policy (with `deny` effects) | **Similar** — both can enforce guardrails org-wide. Azure Policy can also _audit_ and _remediate_ non-compliant resources automatically. |
| **Soft delete / retention** | No native soft-delete for RDS instances; snapshots are the safety net | Azure Database soft-delete (preview for some services); Azure Backup soft-delete (14-day retention) | **Azure** — soft-delete in Azure Backup means a deleted backup item is retained for 14 additional days, recoverable at no extra cost. |
| **Cost of recovery** | AWS Business Support: $100/mo minimum + 10% of monthly bill | Azure Professional Direct: ~$1,000/mo | **AWS** — cheaper for one-off incidents or smaller accounts. Azure Standard ($100/mo) covers Sev-B; Professional Direct is needed for Sev-A (1-hour response). |
| **Terraform lifecycle protection** | `prevent_destroy` lifecycle meta-argument | Same Terraform `prevent_destroy` meta-argument | **Identical** — this is a Terraform feature, not cloud-specific. Protects only if the resource block is present in the config. |

### Key Insight

The incident exposed a fundamental gap in AWS's automated backup lifecycle: **RDS automated snapshots are deleted when the instance is deleted.** Azure Backup's vault-based architecture decouples backup lifecycle from resource lifecycle, providing a stronger safety net against `terraform destroy` disasters.

---

## 3. Terraform Backend Configuration Comparison

### AWS Backend (S3 + DynamoDB)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**Required AWS resources:**
- An S3 bucket (with versioning enabled for state history)
- A DynamoDB table (with `LockID` as the partition key)
- IAM permissions for both S3 and DynamoDB access

### Azure Backend (azurerm)

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "production.terraform.tfstate"
  }
}
```

**Required Azure resources:**
- A Resource Group
- A Storage Account (with blob versioning enabled for state history)
- A Blob Container within the Storage Account
- RBAC role assignment (e.g., `Storage Blob Data Contributor`)

### Side-by-Side Comparison

| Aspect | AWS (S3) | Azure (azurerm) |
|---|---|---|
| **State storage** | S3 bucket | Blob Storage container |
| **State locking** | Separate DynamoDB table | Built-in blob lease (no extra resource) |
| **Encryption at rest** | `encrypt = true` (SSE-S3 or SSE-KMS) | Enabled by default (Azure Storage Service Encryption) |
| **State versioning** | S3 bucket versioning | Blob versioning / snapshots |
| **Authentication** | IAM credentials / assumed role | Service principal, managed identity, or Azure CLI |
| **Setup complexity** | Moderate (2 resources + IAM) | Moderate (3 resources + RBAC) |

### Best Practice for Both Platforms

```hcl
# Add to every critical resource — platform-agnostic
resource "azurerm_postgresql_flexible_server" "main" {
  # ... configuration ...

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_db_instance" "main" {
  # ... configuration ...
  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }
}
```

---

## 4. "What Would Have Happened in Azure?"

A step-by-step walkthrough of the incident timeline, reimagined on Azure infrastructure.

### The Setup (Identical Root Cause)

The root cause — **running Terraform against production with a local/empty state file** — is entirely platform-agnostic. If the team had been using Azure and made the same mistake, Terraform would have generated the same catastrophic plan: _destroy everything it doesn't see in state._

```
# This would happen on ANY cloud:
$ terraform plan
# Terraform sees 0 resources in local state
# Terraform sees N resources in the cloud
# Plan: 0 to add, 0 to change, N to destroy.
```

### The Divergence — Where Azure's Guardrails Kick In

Here's where the timeline diverges depending on which protections were in place:

#### Scenario A: Azure with Resource Locks (Best Case)

```
$ terraform apply -auto-approve
│ Error: deleting PostgreSQL Flexible Server "prod-db":
│ ScopeLocked - The scope '/subscriptions/.../prod-db' has a
│ CanNotDelete lock. Please remove the lock and retry.
```

**Result: Destroy blocked.** Azure Resource Locks operate at the ARM (Azure Resource Manager) level, _below_ Terraform. Even `terraform destroy` cannot bypass a `CanNotDelete` lock. The operator would need to:

1. Manually remove the lock via the Azure Portal or CLI
2. Re-run the destroy

This two-step requirement creates a critical "are you sure?" moment that the AWS Deletion Protection flag does not — because Terraform can disable the AWS flag and delete the resource in the _same apply_.

#### Scenario B: Azure without Resource Locks (Same Outcome as AWS)

Without resource locks, `terraform destroy` would succeed, just as it did on AWS. The database, container apps, networking — all destroyed.

**But the recovery story is different:**

| Recovery Step | AWS (What Happened) | Azure (What Would Happen) |
|---|---|---|
| **Automated backups** | ❌ Lost — RDS automated snapshots deleted with the instance | ✅ Survived — Azure Backup vault backups are independent of the resource |
| **Point-in-time restore** | ❌ Unavailable — backup chain destroyed | ✅ Available — vault retains PITR data per retention policy |
| **Manual snapshots** | ✅ Survived (if they existed) | ✅ Survived (equivalent behavior) |
| **Soft-delete protection** | ❌ Not available for RDS | ✅ Azure Backup soft-delete retains backups for 14 days after deletion |
| **Recovery path** | Call AWS Support → hope for internal snapshot recovery | Restore from Backup vault → new Flexible Server in minutes |
| **Data loss window** | Hours to days (depends on last manual snapshot) | Minutes (depends on backup frequency, typically 5-min granularity for PITR) |

#### Scenario C: Azure with Azure Policy (Preventive)

Azure Policy could enforce rules at the subscription or management group level:

```json
{
  "if": {
    "allOf": [
      { "field": "type", "equals": "Microsoft.DBforPostgreSQL/flexibleServers" },
      { "field": "tags['environment']", "equals": "production" }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
```

This policy would **deny deletion of any production-tagged PostgreSQL server**, regardless of how the deletion was triggered — Portal, CLI, Terraform, or API.

### Timeline Comparison

| Time | AWS (Actual) | Azure (With Locks + Backup) |
|---|---|---|
| **T+0** | `terraform destroy` executes | `terraform destroy` **blocked** by resource lock |
| **T+5m** | Team discovers production is down | Team sees Terraform errors, investigates |
| **T+10m** | Panic — RDS instance gone, automated backups gone | Lock identified as blocker, team realizes state mismatch |
| **T+30m** | Searching for manual snapshots | Fix: reinitialize state from Azure, import existing resources |
| **T+1h** | Contacting AWS Support | Production never went down |
| **T+4h** | AWS Support identifies internal snapshot | N/A — incident avoided |
| **T+8h** | Restoration in progress | N/A |
| **T+12h** | Data restored with 4-hour gap | N/A |

---

## 5. Key Takeaways

### Both Platforms Need Defense-in-Depth

No single protection mechanism is sufficient. The incident proves that you need **layered defenses**:

```
Layer 1: Remote state backend (prevent the root cause)
   └─ Layer 2: State locking (prevent concurrent corruption)
       └─ Layer 3: Terraform lifecycle rules (prevent_destroy)
           └─ Layer 4: Cloud-native deletion protection (resource locks / deletion protection)
               └─ Layer 5: Immutable backups (survive even if all above fail)
                   └─ Layer 6: Policy enforcement (org-wide guardrails)
                       └─ Layer 7: Process guardrails (CI/CD, plan review, approval gates)
```

### Azure Has a Slight Advantage in Backup Immutability

Azure Backup's vault-based architecture **decouples backup lifecycle from resource lifecycle**. This is a meaningful architectural advantage:

- **AWS**: Automated RDS snapshots are tied to the instance. Delete the instance → lose the automated backups.
- **Azure**: Backup vault items are independent resources. Delete the database → backups remain in the vault, governed by their own retention policy.

This does not mean Azure is "better" — it means Azure's backup model is more resilient to this specific failure mode.

### AWS Has Cheaper Emergency Support Options

For small-to-medium accounts, AWS Business Support is significantly cheaper:

| Plan | AWS | Azure |
|---|---|---|
| Basic technical support | Business: $100/mo + 10% of bill | Standard: $100/mo |
| Fast production response (< 1 hr) | Business (included) | Professional Direct: ~$1,000/mo |

For a startup with a $1,000/mo AWS bill, Business Support costs $200/mo. The equivalent Azure Professional Direct is $1,000/mo. This price difference matters when the only path to recovery is "call support."

### The REAL Fix Is Platform-Agnostic

The protections that would have **prevented** this incident are the same on both platforms:

1. **Remote state backend** — Terraform should _never_ run with local state against cloud infrastructure in production.
2. **CI/CD-only applies** — No human should run `terraform apply` against production from their laptop.
3. **Plan review gates** — Every `terraform plan` should be reviewed before apply, especially if it shows destroys.
4. **Immutable backups** — Backups must survive the deletion of the resource they protect.
5. **Deletion protection + locks** — Belt _and_ suspenders. Use both cloud-native protection and Terraform lifecycle rules.

> **Bottom line:** The cloud provider matters less than the operational discipline. A well-operated AWS environment is safer than a poorly operated Azure environment, and vice versa. The incident simulation teaches principles that transcend any single platform.

---

_This document is part of the [Production Database Incident Simulation](../README.md) project._
