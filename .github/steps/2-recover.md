## Step 2: Recover production

In the real incident, the engineer looked for the nightly snapshots and found none.
The destroy had deleted them along with the database. Support eventually found a
snapshot that was not visible in the console and restored it about 24 hours after the
deletion. Recovery depended on a backup outside the engineer's control.

Your lab has two kinds of backup. The automated backup lived on the database server and
shared the database's lifecycle. The independent export in `.lab/offsite` lives outside
both the database server and Terraform.

### Activity

1. Create a branch: `git switch -c lab/recovery`.
2. Run `make snapshots`, then read the `delete_automated_backups` setting in
   `infrastructure/lab/main.tf`. It mirrors the AWS RDS setting of the same name.
3. Run `make recover` and note how long it takes. With no automated backup left, it
   restores the independent export and compares every table with the export's manifest.
4. Run `make verify`.
5. Run `make drill`. A restore drill proves that the backup restores completely, without
   touching production: it restores into a scratch database, compares the row counts,
   and removes the copy. Untested backups are a hope, not a plan.
6. Optionally, ask the incident analyst:

   ```text
   Compare the lab's recovery with the real incident. Using docs/COMPANION-GUIDE.md
   and .lab/evidence/drill.json, explain the recovery time objective (RTO) and the
   recovery point objective (RPO) of each, and which data the lab would lose if the
   export were a day old. Say which points are inference.
   ```

7. Create `evidence/02-recovery.md` with these `##` headings: `Automated backups`,
   `Restore`, `RTO and RPO`, and `Drill`. Record what you ran, how long the restore took,
   and what the drill compared.
8. Open a pull request, wait for **CI**, and merge.

CI runs the restore drill on every commit. The coach checks that it restored every row.
