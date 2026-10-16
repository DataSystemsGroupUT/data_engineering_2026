FROM python:3.11-slim

RUN pip install --no-cache-dir \
    "jupyterlab==4.2.5" \
    "pymongo==4.10.1" \
    "pandas==2.2.3"

WORKDIR /notebooks
EXPOSE 8888

# No token/password: this is a local teaching environment bound to localhost.
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--allow-root", "--IdentityProvider.token=", "--ServerApp.password="]
