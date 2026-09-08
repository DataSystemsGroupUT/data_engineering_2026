DROP TABLE IF EXISTS cities;

CREATE TABLE cities (
    name         TEXT,
    country_code CHAR(2),
    population   INTEGER
);

-- '/tmp/cities.csv' is a path inside the db container, provided by the
-- ./pgtmp bind mount in compose.yml. It is not a path on your machine.
COPY cities FROM '/tmp/cities.csv' DELIMITER ',' CSV HEADER;
