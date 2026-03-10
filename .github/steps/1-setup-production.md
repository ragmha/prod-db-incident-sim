## 🏗️ Step 1: Build Your "Production" Environment

_Welcome to the simulation! Let's build the infrastructure that's about to get destroyed._ 😈

### 📖 Background

In February 2026, an engineer was managing infrastructure for a **course management platform** that served thousands of students. The platform stored:
- **8 courses** (Data Engineering, ML, MLOps Zoomcamps and more)
- **2,000+ students** with enrollment records
- **55,000+ homework submissions** (the real incident had 1.9 million!)
- Leaderboard rankings, login providers, and more

All of this was managed with **Terraform** and running on Azure.

You're about to build an identical (simulated) environment using Docker.

### 🎯 What You'll Do

1. Clone this repo and start Docker services
2. Seed the database with 55,000+ rows of realistic course data
3. Verify everything is working
4. Understand the infrastructure that's at stake

### 📋 Instructions

**1. Clone and enter the repo:**
```bash
git clone <your-repo-url>
cd <your-repo-name>
```

**2. Start the Docker services:**
```bash
make setup
```
This starts:
- 🐘 **PostgreSQL** — Your "production" database
- 📦 **Azurite** — Simulates Azure Blob Storage

**3. Seed the database:**
```bash
make seed
```
This populates the database with 55,000+ rows of course data.

**4. Verify the data exists:**
```bash
make verify
```

You should see something like:
```
📊 Verifying production data...
  courses:              8 rows
  students:             2000 rows
  enrollments:          ~6000 rows
  homework_questions:   ~340 rows
  courses_answer:       55000+ rows  ← THE CRITICAL TABLE
  leaderboard:          ~6000 rows
  login_providers:      ~3200 rows
```

**5. (Optional) Explore the data:**
```bash
make db-shell
```
```sql
SELECT name, start_date FROM courses ORDER BY start_date;
SELECT COUNT(*) FROM courses_answer;
```

### ✅ Complete This Step

Push your verification output to prove the database is set up:

```bash
make save-evidence
git add evidence/
git commit -m "step 1: production database set up with 55K+ rows"
git push
```

> 💡 **Think about this:** You now have a production database with 55,000+ rows of student data. Homework grades, project submissions, leaderboard rankings — 2.5 years of work. What would happen if this all disappeared in an instant?
