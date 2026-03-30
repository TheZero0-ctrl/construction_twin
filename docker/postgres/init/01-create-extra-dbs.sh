#!/bin/bash
set -euo pipefail

QUEUE_DB="${APP_QUEUE_DB:-open_construction_twin_development_queue}"
TEST_DB="${DB_TEST_NAME:-open_construction_twin_test}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
SELECT 'CREATE DATABASE "${QUEUE_DB}"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${QUEUE_DB}')\gexec

SELECT 'CREATE DATABASE "${TEST_DB}"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${TEST_DB}')\gexec
SQL
