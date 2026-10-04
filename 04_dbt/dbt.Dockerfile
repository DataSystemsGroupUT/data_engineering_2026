FROM python:3.11-slim

RUN pip install --no-cache-dir \
    "dbt-core>=1.7,<2.0" \
    "dbt-postgres>=1.7,<2.0"

WORKDIR /dbt
# Keep the container running so students can exec into it
CMD ["tail", "-f", "/dev/null"]
