## 🔧 Step 3: Recovery — Bring It Back

_Your production database is gone. 55,000+ rows of student data — vanished. Now what?_

### 📖 The Real Recovery Story

In the real incident:
- 🕐 **11 PM** — Engineer discovers the database is destroyed
- 🔍 **11:30 PM** — Checks for automated backups... **they're gone too** (deleted with the database!)
- 💰 **12 AM** — Contacts Azure Support (Standard tier) for expedited assistance
- 📞 **1 AM** — Phone call with Azure support, escalated internally
- ⏳ **All day** — Rebuilds other infrastructure while waiting
- ✅ **10 PM next day** — Azure restores a backup they found on their side. **24 hours of downtime.**

The engineer got lucky — Azure had a backup that wasn't visible in the portal. What if they hadn't?

### 🎯 What You'll Do

1. Discover that "automated backups" are gone
2. Find and use a manual backup to restore the database
3. Verify data integrity after restoration
4. Reflect on what would happen without backups

### 📋 Instructions

**1. First, confirm the database is empty:**
```bash
make verify
```
You should see errors or zero rows — the tables were dropped in Step 2.

**2. Check for "automated backups":**
```bash
# In the real incident, Azure automated backups were deleted with the server
# Let's simulate checking for backups...
ls database/backup/
```
Good news — unlike the real incident, you have a manual backup file! 📁

**3. Restore from backup:**
```bash
make recover
```
This runs `psql` with the backup file to recreate all tables and data.

**4. Verify the restoration:**
```bash
make verify
```

You should see all tables restored with their original row counts:
```
  courses_answer:       55000+ rows ✅
  students:             2000 rows ✅
  courses:              8 rows ✅
```

**5. (Optional) Compare with original:**
```bash
make db-shell
```
```sql
-- Check the critical table
SELECT COUNT(*) FROM courses_answer;

-- Verify data freshness
SELECT MAX(submitted_at) FROM courses_answer;

-- Check a specific course
SELECT c.name, COUNT(ca.id) as submissions
FROM courses c
JOIN homework_questions hq ON hq.course_id = c.id
JOIN courses_answer ca ON ca.question_id = hq.id
GROUP BY c.name
ORDER BY submissions DESC;
```

### 💡 Key Lessons

| Lesson | Detail |
|---|---|
| **Automated backups can be deleted** | Azure automated backups tied to server lifecycle were destroyed too (deletion protection wasn't enabled) |
| **Manual/independent backups are critical** | The backup file saved us because it exists outside Terraform |
| **Test your backups regularly** | A backup you haven't tested is just a hope |
| **Recovery time matters** | Real incident: 24 hours. Your simulation: minutes. The difference? Having a ready backup. |
| **Immutable backups are the gold standard** | Azure Backup vault with immutability policies can't be deleted even by admins |

### ✅ Complete This Step

Save your recovery evidence and push:

```bash
echo "Recovery completed at $(date -u)" > evidence/step-3-recovery.txt
make verify >> evidence/step-3-recovery.txt
git add evidence/
git commit -m "step 3: database recovered from backup"
git push
```

> 🤔 **Reflection:** You recovered in minutes because you had a backup file sitting right there. In the real incident, it took 24 hours and Azure Support. What backup strategy would YOU implement for production?
