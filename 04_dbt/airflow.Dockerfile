FROM apache/airflow:2.8.1

# Pre-install dbt and the Postgres provider so containers start immediately.
# Using _PIP_ADDITIONAL_REQUIREMENTS is avoided because it reinstalls on every
# container restart, making startup take 10+ minutes.
RUN pip install --no-cache-dir \
    "dbt-core==1.8.7" \
    "dbt-postgres==1.8.2" \
    "apache-airflow-providers-postgres"
