# Step 4 Reference Solutions — Azure Guardrails

The Azure guardrail Terraform files are already complete in `infrastructure/guardrails/azure/`. They serve as both the exercise material AND the reference solution.

Key files to study:
- `resource-locks.tf` — CanNotDelete locks on database and resource group
- `backup-policy.tf` — Immutable Recovery Services Vault
- `remote-state.tf` — Azure Blob Storage backend with lease locking

## Key Azure Concepts

### Resource Locks
```hcl
resource "azurerm_management_lock" "database_lock" {
  name       = "database-cannot-delete"
  scope      = azurerm_postgresql_flexible_server.production.id
  lock_level = "CanNotDelete"
  notes      = "Production database — deletion requires lock removal first"
}
```

### Immutable Backups
Azure Backup vault with immutability policies ensures that even if someone deletes the database, the backups survive.

### Remote State
Azure Blob Storage with lease-based locking prevents the "new laptop" problem entirely.
