FROM python:3.12-slim

WORKDIR /app

# Dependencies change rarely; app.py is mounted by Compose for live edits.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

CMD ["streamlit", "run", "/app/app.py", "--server.address=0.0.0.0", "--server.port=8501", "--server.headless=true"]
