# Copilot CLI Custom Instructions — Infrastructure Safety

## Infrastructure Safety Rules

### Terraform Execution
For Terraform operations, NEVER execute `terraform apply`, `terraform destroy`, or `terraform import` directly. Instead, only GENERATE the commands for the human to review and run manually. Show the full command with all flags and let the human copy-paste it.

### Plan Mode
Always use plan mode when working with infrastructure changes. Create a detailed, reviewable plan before suggesting any Terraform operations. The plan should list every resource that will be created, modified, or destroyed.

### Destructive Operations
Before suggesting any destructive Terraform operation (`terraform destroy`, `terraform taint`, `terraform state rm`), ALWAYS:
1. Explain the blast radius — what resources will be affected
2. List any dependent resources that may also be destroyed
3. Warn about backup implications
4. Suggest running `terraform plan -destroy` first to preview
5. Recommend the human runs the command manually after review

### State File Protection
Never modify, move, delete, or replace Terraform state files (`*.tfstate`, `*.tfstate.backup`). If state operations are needed, explain the risks clearly and let the human handle the operation. State file corruption can lead to infrastructure loss.

### Environment Verification
Before any infrastructure change, verify:
1. Which Terraform workspace is active (`terraform workspace show`)
2. Which backend/state file is being used (local vs Azure Blob Storage)
3. Which Azure subscription is targeted (`az account show`)
4. Whether this is dev, staging, or production
Refuse to proceed if the target environment or Azure subscription is unclear.

## Comparison: What Went Wrong vs What Copilot CLI Does

| What Happened in the Incident | How Copilot CLI Handles This |
|-------------------------------|------------------------------|
| AI agent ran `terraform destroy` on Azure resources autonomously | Every command is shown to the user BEFORE execution — user must explicitly approve |
| AI agent replaced the local state file (no Azure Blob Storage backend) | All file modifications are shown before writing — user sees what will change |
| No human review of the Terraform plan for Azure PostgreSQL, VNet, etc. | Plan mode creates a reviewable plan; `/diff` shows all changes before commit |
| Auto-approve was delegated to the AI | No auto-approve capability — human always makes the final decision |
| AI agent had unrestricted file system access | Directory scoping (`/add-dir`) restricts which paths the agent can access |
