-- The PostgreSQL image runs this once, when its data volume is empty.
-- psql reads the password from the container environment, not from this file.
\getenv reader_password VIZ_READER_PASSWORD
CREATE ROLE viz_reader LOGIN PASSWORD :'reader_password';
CREATE DATABASE viz_practice;
GRANT CONNECT ON DATABASE viz_practice TO viz_reader;

-- Seed the lesson data before Compose marks the database as ready.
\connect viz_practice
\i /lesson-seed/02-seed-sales.sql
