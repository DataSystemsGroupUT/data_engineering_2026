# Superset 6.1.0's standard release image is lean: its PostgreSQL driver is
# supplied here, once at build time. The web app and init job share this image.
FROM apache/superset:6.1.0

USER root
RUN . /app/.venv/bin/activate && uv pip install psycopg2-binary==2.9.11
USER superset
