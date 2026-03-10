#!/bin/bash
# Verify database integrity after seed or restore

set -e

COMPOSE="docker compose"
PSQL="$COMPOSE exec -T postgres psql -U admin -d course_platform -t -A"

echo "📊 Verifying database integrity..."
echo "================================="

# Check each table
tables=("courses" "students" "enrollments" "homework_questions" "courses_answer" "leaderboard" "login_providers")

total=0
for table in "${tables[@]}"; do
    count=$($PSQL -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d '[:space:]')
    printf "  %-25s %s rows\n" "$table:" "$count"
    total=$((total + count))
done

echo "================================="
echo "  Total rows:              $total"
echo ""

# Critical check: courses_answer must have 50K+ rows
answer_count=$($PSQL -c "SELECT COUNT(*) FROM courses_answer;" | tr -d '[:space:]')
if [ "$answer_count" -ge 50000 ]; then
    echo "✅ courses_answer has $answer_count rows (expected 50K+)"
else
    echo "❌ courses_answer has only $answer_count rows (expected 50K+)"
    exit 1
fi

# Check data freshness
echo ""
echo "📅 Latest submission: $($PSQL -c "SELECT MAX(submitted_at) FROM courses_answer;")"
echo "👥 Unique students: $($PSQL -c "SELECT COUNT(DISTINCT student_id) FROM courses_answer;")"
echo "📚 Active courses: $($PSQL -c "SELECT COUNT(*) FROM courses WHERE is_active = true;")"
echo ""
echo "✅ Database verification complete!"
