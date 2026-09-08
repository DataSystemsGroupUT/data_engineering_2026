# 00 — Docker & PostgreSQL

Instead of installing PostgreSQL natively on Windows, macOS and Linux and troubleshooting three different sets of problems, we run it in a container. Everyone gets the identical version, and cleanup is a single command.

**Prerequisite:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed **and running**. Verify with `docker --version`.

**Contents**

1. [Docker CLI](#1-docker-cli)
2. [Docker Compose](#2-docker-compose)
3. [PostgreSQL in a container](#3-postgresql-in-a-container)
4. [Connecting a client](#4-connecting-a-client)
5. [Preparing for the assignment](#5-preparing-for-the-assignment)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Docker CLI

Full reference: https://docs.docker.com/engine/reference/commandline/cli/

### Images

| Command | What it does |
| :--- | :--- |
| `docker images` | List images you have locally |
| `docker pull alpine:3.20` | Download an image from a registry |
| `docker rmi alpine:3.20` | Remove an image (remove its containers first) |

### Container lifecycle

| Command | What it does |
| :--- | :--- |
| `docker create -it --name hello alpine:3.20` | Create a container **without** starting it |
| `docker start hello` | Start it |
| `docker ps` | List running containers (`-a` includes stopped ones) |
| `docker stop hello` | Stop it |
| `docker rm hello` | Delete it |

In `docker create -it --name hello alpine:3.20`:  
`-it` enables an interactive tty. Whether you need it depends on the type of service.  
`--name hello` names the container so you can refer to it later instead of using its ID.

`docker run` is the shortcut that does everything at once — if the image is missing it pulls it, then creates the container, then starts it:

```bash
docker run alpine:3.20
docker run -it --name hello_again alpine:3.20
```

### Getting a shell inside a container

```bash
docker exec -it hello sh
```

Or, because we created this one with an interactive tty, `docker attach hello` works the same way.

**Exiting without accidentally killing the container:**

| Keys | Effect |
| :--- | :--- |
| `exit` | Exits **and shuts down** the container |
| `ctrl+a`, `ctrl+d` | Detaches — works if you started a different tty session |
| `ctrl+p`, `ctrl+q` | Graceful detach, container keeps running |

The last one depends on your tool's shortcuts — VS Code, for example, may intercept it.

---

## 2. Docker Compose

Compose describes a whole stack of services in one `compose.yml` file, so nobody has to retype long `docker run` commands. Full reference: https://docs.docker.com/compose/reference/

| Command | What it does |
| :--- | :--- |
| `docker compose up -d` | Start all services in detached mode |
| `docker compose up -d db` | Start just one service |
| `docker compose ps` | Show which services are up or exited |
| `docker compose logs db` | Show a service's output |
| `docker compose stop` | Stop services, keep the containers |
| `docker compose down` | Stop **and remove** containers |
| `docker compose down -v` | Also delete the volumes — wipes your database |

These commands assume your terminal is in the directory holding `compose.yml`. From elsewhere, point at the file explicitly:

```bash
docker compose -f 00_Docker/compose.yml up -d
```

When reviewing a `.yml` file, look at how it declares **versioning**, **services**, **ports**, **volumes** and **networks**.

> **NB!** Remember to remove containers that have `restart: always` if you don't actually want them running in the background forever.

### Services talk to each other by name

Containers on the same Compose network reach each other using the **service name** as a hostname. Start the Python interpreter in the `my_python` service and try:

```python
from urllib import request
r = request.urlopen("http://my_html")
print(r.read())
```

This rule matters more than it first appears, and it is where most assignment bugs come from:

| Connecting from | Host to use | Port to use |
| :--- | :--- | :--- |
| Your laptop (DBeaver, browser) | `localhost` | the **host** port, e.g. `5432` |
| Another container (`py`, `pgadmin`) | the service name, e.g. `db` | the **container** port, always `5432` |

Inside a container, `localhost` means *that container itself* — so a Python script pointing at `localhost` fails with connection refused, even though the database is running fine.

---

## 3. PostgreSQL in a container

### Option A — `docker run`

```bash
docker run --name pg-course-db -e POSTGRES_PASSWORD=mysecretpassword -d -p 5432:5432 postgres:16.4
```

Anatomy of that command:

| Flag | Meaning |
| :--- | :--- |
| `--name pg-course-db` | Names the container so you can refer to it later |
| `-e POSTGRES_PASSWORD=...` | Postgres refuses to initialise without a password |
| `-d` | Detached mode — runs in the background, you keep your terminal |
| `-p 5432:5432` | Maps `HOST_PORT:CONTAINER_PORT`, bridging your laptop to the container |
| `postgres:16.4` | Pin the version; don't rely on `latest` |

Confirm it started, and watch the logs if it didn't:

```bash
docker ps
docker logs -f pg-course-db
```

### Option B — Compose

The `db` service in `compose.yml` does the same thing with the settings kept in a file:

```bash
docker compose up -d db
```

Two differences from Option A:

* It uses the named volume `pg_data`, so data survives `docker compose down`. Use `docker compose down -v` when you deliberately want a clean database.
* Option A stores nothing — removing that container deletes its data. To persist it, add `-v pg_data:/var/lib/postgresql/data` to the `docker run` command.

### Cleanup

```bash
docker stop pg-course-db
docker rm pg-course-db
```

---

## 4. Connecting a client

### `psql`, inside the container

No client installation needed:

```bash
docker exec -it pg-course-db psql -U postgres
```

### Any client, from your machine

| Setting | Value |
| :--- | :--- |
| Host | `localhost` |
| Port | `5432` |
| Database | `postgres` |
| Username | `postgres` |
| Password | whatever you set as `POSTGRES_PASSWORD` |

Prove the connection is live by running `SELECT 1;`.

### DBeaver

DBeaver Community Edition is a free SQL client for Windows, macOS and Linux — download it at https://dbeaver.io/download/

1. **Database → New Database Connection**, or the plug icon with a `+` in the top-left toolbar.
2. Select **PostgreSQL**, click **Next**.
3. Fill in the **Main** tab with the values from the table above. Tick **Save password** so you aren't asked every time.
4. Click **Test Connection**. On first use DBeaver offers to **Download** the PostgreSQL JDBC driver — accept it. This needs an internet connection.
5. Click **Finish**. The connection appears in the **Database Navigator** on the left.
6. Open **SQL Editor → New SQL Script** (`Ctrl+]` / `Cmd+]`), type `SELECT 1;`, run it with `Ctrl+Enter` / `Cmd+Enter`.

Tips:

* If you mapped a different host port (e.g. `-p 5433:5432`), use that one. DBeaver connects from your laptop, so it always uses `localhost` and the **host** port — never the container port.
* By default DBeaver shows only the database you connected to. To see the rest, edit the connection and tick **Show all databases** on the **PostgreSQL** tab.
* After creating tables from another tool, right-click the schema and **Refresh** (`F5`) — DBeaver caches the object tree.

---

## 5. Preparing for the assignment

Everything above gets a database running. The assignment also needs you to move files into containers, run commands against them, and let containers talk to each other.

| Assignment level | What it needs from this section |
| :--- | :--- |
| 1 | `.env` and Compose variables, pgAdmin service |
| 2 | [Service hostnames](#services-talk-to-each-other-by-name), `docker exec` to install packages |
| 3 | Bind mounts, `COPY` vs `\copy` |
| 4 | Bind mounts, `docker exec` to run a script |
| 5 | `psql -f` to apply a `.sql` file |

### Getting files into a container

A container has its own filesystem, so it cannot see your CSV or your Python scripts by default. There are two ways to attach storage:

**Named volume** — Docker manages the location and you never look inside it. Use it for database data:

```yaml
volumes:
  - pg_data:/var/lib/postgresql/data
```

**Bind mount** — maps a folder from your machine into the container. Use it for files you edit:

```yaml
volumes:
  - ./pgtmp:/tmp
  - ./py_app:/scripts
```

The syntax is `HOST_PATH:CONTAINER_PATH`, and the host path is relative to the location of `compose.yml`. Bind mounts are live: edit `py_app/ingest.py` in your editor and the container sees the change immediately, with no rebuild or restart.

Always verify what actually landed inside:

```bash
docker exec -it my_postgres ls /tmp
```

That should list `cities.csv` and `load_cities.sql` from this folder's `pgtmp`. If the listing is empty, nothing else will work — fix the mount first.

Note that `docker exec` takes the **container** name, which is not always the service name: it's `my_postgres` here, but the assignment names its container `db`.

### `COPY` runs inside the server

This is the most common place to get stuck on Level 3, so there is a working example in this folder to try first.

`compose.yml` mounts `./pgtmp` into the `db` service at `/tmp`, and `pgtmp/load_cities.sql` creates a small table and loads `pgtmp/cities.csv` into it:

```sql
COPY cities FROM '/tmp/cities.csv' DELIMITER ',' CSV HEADER;
```

Run it, then check the result:

```bash
docker compose up -d db
docker exec -it my_postgres bash -c "psql -f /tmp/load_cities.sql"
docker exec -it my_postgres bash -c "psql -c 'SELECT * FROM cities;'"
```

`COPY` is executed by the Postgres **server process**, so `/tmp/cities.csv` is a path *inside the `db` container* — not a path on your laptop. That is exactly why the CSV has to be bind-mounted in first.

To see this for yourself, edit the `.sql` file to point at a path on your own machine and run it again. It fails even though the file plainly exists, and Postgres tells you why:

```
ERROR:  could not open file "C:/.../pgtmp/cities.csv" for reading: No such file or directory
HINT:  COPY FROM instructs the PostgreSQL server process to read a file.
       You may want a client-side facility such as psql's \copy.
```

The alternative is `\copy`, a `psql` **client** command that reads the file from wherever `psql` is running and streams it over the connection:

```
\copy cities FROM 'cities.csv' DELIMITER ',' CSV HEADER
```

Same end result, different machine reading the file.

Neither command needs a username or password here, because `compose.yml` sets `PGUSER` on the service — see [Configuration with `.env`](#configuration-with-env).

### One-off commands with `docker exec`

`docker exec` also takes a single command, runs it, and hands your prompt back:

```bash
# Apply a SQL file
docker exec -it db bash -c "psql -f /tmp/create_table.sql"

# Install Python dependencies
docker exec -it py bash -c "pip install -r /scripts/requirements.txt"

# Run your ingest script
docker exec -it py bash -c "python /scripts/ingest.py"
```

Packages installed this way exist only in that container. Recreate it (`docker compose down`, then `up`) and they're gone. Building a custom image with a `Dockerfile` is the real fix — that comes later in the course.

### Configuration with `.env`

Compose automatically reads a file named `.env` next to `compose.yml` and substitutes `${VARIABLE}` references.

```ini
POSTGRES_USER=data_engineer
POSTGRES_PASSWORD=Pass!w0rd
POSTGRES_DB=assignment
```

```yaml
environment:
  POSTGRES_USER: ${POSTGRES_USER}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  POSTGRES_DB: ${POSTGRES_DB}
  PGUSER: ${POSTGRES_USER}
  PGPASSWORD: ${POSTGRES_PASSWORD}
  PGDATABASE: ${POSTGRES_DB}
```

The `POSTGRES_*` variables tell the image which user and database to create. The `PG*` variables are read by the `psql` client — that's why `psql -f /tmp/create_table.sql` above needs no username, password or database flags.

Check that substitution resolved before starting anything:

```bash
docker compose config
```

> **Trap:** `POSTGRES_USER` and `POSTGRES_DB` only apply when the data directory is **first** initialised. Start the stack, then edit `.env`, and nothing changes — the database already exists. Remove the volume with `docker compose down -v` to reinitialise.

Keep real credentials out of version control by adding `.env` to `.gitignore`. The one in the assignment solution is committed deliberately, because it holds throwaway teaching values.

### Connecting from Python

Following the [hostname rule](#services-talk-to-each-other-by-name), the SQLAlchemy URL points at the service name, not `localhost`:

```python
DATABASE_URL = f"postgresql+psycopg2://{POSTGRES_USER}:{POSTGRES_PASSWORD}@db:5432/{POSTGRES_DB}"
```

### pgAdmin in a container

Level 1 asks for pgAdmin as a service:

```yaml
pgadmin:
  container_name: pgadmin
  image: elestio/pgadmin:REL-8_10
  environment:
    PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL}
    PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD}
  ports:
    - "5050:80"
```

Open http://localhost:5050/ and log in with the values from `.env`. Then **Add new server**, name it anything, and on the **Connection** tab set Host to `db` — pgAdmin runs in a container, so it follows the container row of the hostname table, not `localhost`.

---

## 6. Troubleshooting

**`Cannot connect to the Docker daemon`**  
Docker Desktop is installed but not started. Open the application and wait until the whale icon stops animating.

**`Bind for 0.0.0.0:5432 failed: port is already allocated`**  
Something already occupies port 5432 — often a locally installed PostgreSQL. Map a different **host** port and connect to that one instead:
```bash
docker run --name pg-course-db -e POSTGRES_PASSWORD=mysecretpassword -d -p 5433:5432 postgres:16.4
```

**`could not open file "/tmp/countries.csv" for reading`**  
The path is resolved inside the container. Either the bind mount is missing or you used a host path. Check with `docker exec -it my_postgres ls /tmp`.

**`connection refused` from the Python container**  
You used `localhost` in the connection URL instead of the service name `db`.

**Edits to `.env` appear to do nothing**  
`POSTGRES_USER` and `POSTGRES_DB` only apply on first initialisation. Run `docker compose down -v` and start again.

**A service won't start**  
`docker compose ps` shows what exited; `docker compose logs db` shows why.

**The Python container exits immediately**  
Expected, not a bug: `python` with no script reaches end of input and stops. These two lines keep it alive for `docker exec`:
```yaml
stdin_open: true
tty: true
```

**Windows: WSL2 errors on startup**  
Update the WSL kernel: https://learn.microsoft.com/en-us/windows/wsl/install

---

![Docker Meme](docker.JPG)
