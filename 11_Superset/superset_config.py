"""Small configuration for the local, PostgreSQL-backed Superset lesson."""

import os

# Superset stores users, saved charts, and dashboards in its metadata database.
# Student sales data lives in a different database and is added in the web UI.
SQLALCHEMY_DATABASE_URI = os.environ["SUPERSET_META_URI"]

# This must remain the same across restarts or saved database passwords cannot
# be decrypted. The local exercise value comes from the ignored .env file.
SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# Our small synchronous queries work without a Redis cache or Celery worker.
CACHE_CONFIG = {"CACHE_TYPE": "SimpleCache", "CACHE_DEFAULT_TIMEOUT": 300}
DATA_CACHE_CONFIG = CACHE_CONFIG
