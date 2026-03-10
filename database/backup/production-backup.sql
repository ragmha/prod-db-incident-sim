-- =============================================================================
-- Production Database Backup
-- =============================================================================
-- Backup of the course_platform database
-- Created: 2024-02-26 02:00:00 UTC (automated nightly backup)
--
-- This backup was created BEFORE the incident occurred.
-- It contains all course data, student submissions, and leaderboard entries.
--
-- In the real incident, automated RDS snapshots were deleted along with
-- the database. This manual backup is what saved the data.
-- =============================================================================

-- Clean slate (drop existing tables if restoring to a non-empty database)
DROP TABLE IF EXISTS login_providers CASCADE;
DROP TABLE IF EXISTS leaderboard CASCADE;
DROP TABLE IF EXISTS courses_answer CASCADE;
DROP TABLE IF EXISTS homework_questions CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS courses CASCADE;

BEGIN;

-- ─────────────────────────────────────────────
-- 1. SCHEMA
-- ─────────────────────────────────────────────

-- courses — each Zoomcamp cohort is a separate course
CREATE TABLE courses (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    slug        VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    start_date  DATE,
    end_date    DATE,
    is_active   BOOLEAN   DEFAULT true,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- students — anyone who signs up on the platform
CREATE TABLE students (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    full_name       VARCHAR(255) NOT NULL,
    github_username VARCHAR(100),
    enrolled_at     TIMESTAMP DEFAULT NOW()
);

-- enrollments — many-to-many between students and courses
CREATE TABLE enrollments (
    id          SERIAL PRIMARY KEY,
    student_id  INT NOT NULL REFERENCES students(id),
    course_id   INT NOT NULL REFERENCES courses(id),
    enrolled_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (student_id, course_id)
);

-- homework_questions — each course has modules with graded questions
CREATE TABLE homework_questions (
    id              SERIAL PRIMARY KEY,
    course_id       INT NOT NULL REFERENCES courses(id),
    module_number   INT NOT NULL,
    question_number INT NOT NULL,
    question_text   TEXT NOT NULL,
    correct_answer  VARCHAR(500) NOT NULL,
    points          INT DEFAULT 1
);

-- courses_answer — THE critical table
-- Named "courses_answer" to match the real platform schema referenced in the
-- incident article.  In production this table held ~1.9 million rows of student
-- homework submissions.  We generate 50,000+ rows here for the simulation.
CREATE TABLE courses_answer (
    id            SERIAL PRIMARY KEY,
    student_id    INT NOT NULL REFERENCES students(id),
    question_id   INT NOT NULL REFERENCES homework_questions(id),
    answer_text   VARCHAR(500),
    is_correct    BOOLEAN,
    submitted_at  TIMESTAMP DEFAULT NOW(),
    points_earned INT DEFAULT 0
);

-- leaderboard — precomputed rankings per course
CREATE TABLE leaderboard (
    id            SERIAL PRIMARY KEY,
    student_id    INT NOT NULL REFERENCES students(id),
    course_id     INT NOT NULL REFERENCES courses(id),
    total_points  INT DEFAULT 0,
    rank          INT,
    last_updated  TIMESTAMP DEFAULT NOW()
);

-- login_providers — OAuth identities (GitHub, Google)
CREATE TABLE login_providers (
    id           SERIAL PRIMARY KEY,
    student_id   INT NOT NULL REFERENCES students(id),
    provider     VARCHAR(50) NOT NULL,
    provider_uid VARCHAR(255) NOT NULL,
    created_at   TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- 2. SEED DATA
-- =============================================================================

-- ─────────────────────────────────────────────
-- 2a. Courses — 8 Zoomcamp / Analytics cohorts
-- ─────────────────────────────────────────────
INSERT INTO courses (name, slug, description, start_date, end_date, is_active) VALUES
    ('Data Engineering Zoomcamp 2024',
     'de-zoomcamp-2024',
     'Learn data engineering end-to-end: Docker, Terraform, GCP, BigQuery, Spark, Kafka, dbt, and more.',
     '2024-01-15', '2024-04-15', false),

    ('Data Engineering Zoomcamp 2025',
     'de-zoomcamp-2025',
     'Updated 2025 cohort covering data engineering fundamentals with hands-on projects.',
     '2025-01-13', '2025-04-14', true),

    ('Data Engineering Zoomcamp 2026',
     'de-zoomcamp-2026',
     'Upcoming 2026 cohort — registrations open soon.',
     '2026-01-12', '2026-04-13', false),

    ('ML Zoomcamp 2024',
     'ml-zoomcamp-2024',
     'Machine learning from regression to deployment: scikit-learn, TensorFlow, Kubernetes.',
     '2024-09-09', '2024-12-16', false),

    ('ML Zoomcamp 2025',
     'ml-zoomcamp-2025',
     '2025 machine learning cohort with updated curriculum and capstone projects.',
     '2025-09-08', '2025-12-15', true),

    ('MLOps Zoomcamp 2024',
     'mlops-zoomcamp-2024',
     'MLOps practices: MLflow, Prefect, deployment pipelines, monitoring, and best practices.',
     '2024-05-13', '2024-08-12', false),

    ('MLOps Zoomcamp 2025',
     'mlops-zoomcamp-2025',
     '2025 MLOps cohort — experiment tracking, orchestration, CI/CD for ML.',
     '2025-05-12', '2025-08-11', true),

    ('Stock Market Analytics Zoomcamp 2024',
     'stock-analytics-2024',
     'Quantitative finance with Python: market data APIs, technical indicators, backtesting, dashboards.',
     '2024-02-12', '2024-05-13', false);

-- ─────────────────────────────────────────────
-- 2b. Students — 2,000 realistic accounts
-- Uses first/last name arrays combined with generate_series to create
-- unique, realistic-looking student records.
-- ─────────────────────────────────────────────
INSERT INTO students (email, full_name, github_username, enrolled_at)
SELECT
    -- email: deterministic but unique per student
    format('student%s@%s',
        s.id,
        (ARRAY['gmail.com','yahoo.com','outlook.com','protonmail.com','university.edu',
               'mail.com','fastmail.com','icloud.com','hotmail.com','zoho.com']
        )[1 + (s.id % 10)]
    ),
    -- full_name: mix of realistic first + last names
    format('%s %s',
        (ARRAY['Emma','Liam','Olivia','Noah','Ava','Ethan','Sophia','Mason',
               'Isabella','James','Mia','Alexander','Charlotte','William','Amelia',
               'Benjamin','Harper','Lucas','Evelyn','Henry','Aria','Sebastian',
               'Ella','Jack','Scarlett','Aiden','Grace','Owen','Lily','Samuel',
               'Chloe','Ryan','Zoey','Nathan','Penelope','Caleb','Layla','Christian',
               'Riley','Landon','Nora','Adrian','Hannah','Mateo','Emilia','Diego',
               'Abigail','Kai','Elena','Priya','Wei','Yuki','Fatima','Omar',
               'Anya','Dmitri','Chen','Sakura','Aisha','Raj','Mei','Tariq',
               'Ingrid','Pavel','Leila','Kofi','Sven','Yara','Jin','Amara']
        )[1 + (s.id % 70)],
        (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller',
               'Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez',
               'Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin',
               'Lee','Perez','Thompson','White','Harris','Sanchez','Clark',
               'Ramirez','Lewis','Robinson','Walker','Young','Allen','King',
               'Wright','Scott','Torres','Nguyen','Hill','Flores','Green',
               'Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell',
               'Carter','Roberts','Kim','Park','Tanaka','Müller','Schmidt',
               'Patel','Singh','Chen','Wang','Nakamura','Ivanov','Petrov',
               'Silva','Santos','Johansson','Nielsen','Kowalski','Novak',
               'Eriksson','Berg']
        )[1 + ((s.id * 7) % 70)]
    ),
    -- github_username: slug-style handle
    format('%s%s',
        (ARRAY['dev','code','data','ml','eng','hack','byte','algo',
               'cloud','tech','deep','net','node','rust','py','go']
        )[1 + (s.id % 16)],
        (ARRAY['ninja','wizard','smith','craft','guru','mind','flow','hub',
               'ops','lab','fox','wolf','bear','hawk','dart','bolt']
        )[1 + ((s.id * 3) % 16)]
    ) || s.id::text,
    -- enrolled_at: spread across 2023-2025
    '2023-06-01'::timestamp + (random() * (interval '730 days'))
FROM generate_series(1, 2000) AS s(id);

-- ─────────────────────────────────────────────
-- 2c. Enrollments — each student in 2-4 random courses
-- We assign each student to 2, 3, or 4 courses depending on their id.
-- ─────────────────────────────────────────────
INSERT INTO enrollments (student_id, course_id, enrolled_at)
SELECT DISTINCT ON (sub.student_id, sub.course_id)
    sub.student_id,
    sub.course_id,
    '2023-09-01'::timestamp + (random() * (interval '500 days'))
FROM (
    -- Each student gets 2-4 enrollments by generating multiple random course picks
    SELECT
        s.id AS student_id,
        1 + (floor(random() * 8))::int AS course_id
    FROM generate_series(1, 2000) AS s(id),
         generate_series(1, 4) AS pick(n)
    WHERE pick.n <= 2 + (s.id % 3)  -- yields 2, 3, or 4 picks per student
) sub
ORDER BY sub.student_id, sub.course_id;

-- ─────────────────────────────────────────────
-- 2d. Homework Questions — 10 questions per module, 3-5 modules per course
-- Total: ~300+ questions across all courses
-- ─────────────────────────────────────────────

-- Module counts per course (mirrors real Zoomcamp structure):
--   DE Zoomcamp courses  → 5 modules (docker, terraform, bigquery, spark, kafka)
--   ML Zoomcamp courses  → 4 modules (regression, classification, trees, deep-learning)
--   MLOps courses        → 4 modules (mlflow, orchestration, deployment, monitoring)
--   Stock Analytics      → 3 modules (data-collection, indicators, backtesting)

INSERT INTO homework_questions (course_id, module_number, question_number, question_text, correct_answer, points)
SELECT
    c.course_id,
    m.module_num,
    q.question_num,
    format('Module %s — Question %s: %s for the %s course.',
        m.module_num, q.question_num,
        (ARRAY[
            'What is the correct Docker command to build the image',
            'Which Terraform resource provisions the data lake',
            'How do you partition a BigQuery table by date',
            'What Spark transformation converts an RDD to a DataFrame',
            'Which Kafka configuration controls consumer offset behavior',
            'What is the learning rate parameter in gradient descent',
            'How do you evaluate a classification model using AUC-ROC',
            'Which regularization technique adds L1 penalty',
            'What command deploys a model to Kubernetes',
            'How do you calculate the moving average of stock prices'
        ])[1 + ((q.question_num + m.module_num) % 10)],
        c.course_name
    ),
    (ARRAY[
        'docker build -t myimage .',
        'google_storage_bucket',
        'PARTITION BY DATE(timestamp_column)',
        'spark.createDataFrame(rdd, schema)',
        'auto.offset.reset=earliest',
        '0.01',
        'from sklearn.metrics import roc_auc_score',
        'Lasso regression',
        'kubectl apply -f deployment.yaml',
        'df["close"].rolling(window=20).mean()'
    ])[1 + ((q.question_num + m.module_num) % 10)],
    CASE WHEN q.question_num <= 7 THEN 1 ELSE 2 END  -- last 3 questions are worth 2 points
FROM (
    -- Course id + module count mapping
    VALUES
        (1, 'Data Engineering Zoomcamp 2024', 5),
        (2, 'Data Engineering Zoomcamp 2025', 5),
        (3, 'Data Engineering Zoomcamp 2026', 5),
        (4, 'ML Zoomcamp 2024', 4),
        (5, 'ML Zoomcamp 2025', 4),
        (6, 'MLOps Zoomcamp 2024', 4),
        (7, 'MLOps Zoomcamp 2025', 4),
        (8, 'Stock Market Analytics 2024', 3)
) AS c(course_id, course_name, num_modules),
generate_series(1, c.num_modules) AS m(module_num),
generate_series(1, 10) AS q(question_num);

-- ─────────────────────────────────────────────
-- 2e. Courses Answer — 50,000+ student homework submissions
-- This is the CRITICAL table.  The real platform had ~1.9 million rows here.
-- We generate 50,000+ rows using cross joins of enrolled students × questions
-- for their courses, with random correctness and timestamps.
-- ─────────────────────────────────────────────
INSERT INTO courses_answer (student_id, question_id, answer_text, is_correct, submitted_at, points_earned)
SELECT
    e.student_id,
    hq.id AS question_id,
    -- Simulate a plausible answer string
    CASE
        WHEN random() < 0.65 THEN hq.correct_answer              -- 65% submit correct answer
        WHEN random() < 0.50 THEN 'Option ' || chr(65 + (floor(random() * 4))::int)  -- wrong multiple-choice
        ELSE md5(random()::text)                                   -- freeform wrong answer
    END,
    -- is_correct matches the 65% probability above (re-rolled independently for slight variance)
    random() < 0.65,
    -- submitted_at: spread across the course window
    '2024-01-15'::timestamp + (random() * (interval '365 days')),
    -- points_earned: correct answers earn the question's point value
    CASE WHEN random() < 0.65 THEN hq.points ELSE 0 END
FROM enrollments e
JOIN homework_questions hq ON hq.course_id = e.course_id
-- Limit so each student answers a random ~60-80% of available questions per course
WHERE random() < 0.75
-- Safety cap: keep output manageable but above 50K
LIMIT 55000;

-- ─────────────────────────────────────────────
-- 2f. Leaderboard — aggregate points per student per course
-- Computed from courses_answer so rankings are consistent.
-- ─────────────────────────────────────────────
INSERT INTO leaderboard (student_id, course_id, total_points, rank, last_updated)
SELECT
    sub.student_id,
    sub.course_id,
    sub.total_points,
    ROW_NUMBER() OVER (PARTITION BY sub.course_id ORDER BY sub.total_points DESC)::int AS rank,
    NOW()
FROM (
    SELECT
        ca.student_id,
        hq.course_id,
        SUM(ca.points_earned) AS total_points
    FROM courses_answer ca
    JOIN homework_questions hq ON hq.id = ca.question_id
    GROUP BY ca.student_id, hq.course_id
) sub;

-- ─────────────────────────────────────────────
-- 2g. Login Providers — GitHub and Google OAuth for each student
-- Every student has at least a GitHub provider; ~60% also have Google.
-- ─────────────────────────────────────────────

-- GitHub provider for all students
INSERT INTO login_providers (student_id, provider, provider_uid, created_at)
SELECT
    s.id,
    'github',
    format('gh-%s', md5(s.id::text || 'github')),
    '2023-06-01'::timestamp + (random() * (interval '730 days'))
FROM generate_series(1, 2000) AS s(id);

-- Google provider for ~60% of students
INSERT INTO login_providers (student_id, provider, provider_uid, created_at)
SELECT
    s.id,
    'google',
    format('goog-%s', md5(s.id::text || 'google')),
    '2023-06-01'::timestamp + (random() * (interval '730 days'))
FROM generate_series(1, 2000) AS s(id)
WHERE random() < 0.60;

COMMIT;

-- =============================================================================
-- Quick sanity check — run after restoring to verify row counts
-- =============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT 'courses'            AS tbl, count(*) AS cnt FROM courses
        UNION ALL SELECT 'students',           count(*) FROM students
        UNION ALL SELECT 'enrollments',        count(*) FROM enrollments
        UNION ALL SELECT 'homework_questions', count(*) FROM homework_questions
        UNION ALL SELECT 'courses_answer',     count(*) FROM courses_answer
        UNION ALL SELECT 'leaderboard',        count(*) FROM leaderboard
        UNION ALL SELECT 'login_providers',    count(*) FROM login_providers
    LOOP
        RAISE NOTICE '  %-25s %s rows', r.tbl, r.cnt;
    END LOOP;
END $$;
