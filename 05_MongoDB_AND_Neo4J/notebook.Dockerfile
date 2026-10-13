FROM python:3.11-slim

# Both drivers in one image, so a single notebook can query both databases.
RUN pip install --no-cache-dir \
    "jupyterlab==4.2.5" \
    "pymongo==4.10.1" \
    "neo4j==5.26.0" \
    "pandas==2.2.3"

WORKDIR /notebooks
EXPOSE 8888

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--allow-root", "--IdentityProvider.token=", "--ServerApp.password="]
