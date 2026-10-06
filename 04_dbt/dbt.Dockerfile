FROM python:3.11-slim

RUN pip install --no-cache-dir \
    "dbt-core==1.8.7" \
    "dbt-postgres==1.8.2"

WORKDIR /dbt
# Keep the container running so students can exec into it
CMD ["tail", "-f", "/dev/null"]
