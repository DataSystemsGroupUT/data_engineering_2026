#!/usr/bin/env bash
set -euo pipefail

# The official PostgreSQL image runs this once, when its data volume is empty.
# Keep Superset's own tables in superset_meta and lesson data in viz_practice.
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v ON_ERROR_STOP=1 -v reader_password="$VIZ_READER_PASSWORD" <<'SQL'
CREATE ROLE viz_reader LOGIN PASSWORD :'reader_password';
CREATE DATABASE viz_practice;
GRANT CONNECT ON DATABASE viz_practice TO viz_reader;
SQL

# Seed the lesson data before Compose marks the database as ready.
psql --username "$POSTGRES_USER" --dbname viz_practice \
  -v ON_ERROR_STOP=1 -f /lesson-seed/02-seed-sales.sql
