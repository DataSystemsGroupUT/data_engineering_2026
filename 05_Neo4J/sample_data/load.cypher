// =============================================================================
// Load the movie graph from the CSVs in this directory.
//
// Run it from the host with:
//   docker exec -i neo4j cypher-shell -u neo4j -p password < sample_data/load.cypher
//
// Safe to re-run: constraints are IF NOT EXISTS and every write uses MERGE,
// so loading twice does not duplicate anything.
// =============================================================================

// --- Constraints -------------------------------------------------------------
// A uniqueness constraint also creates an index, which is what makes the
// MERGE lookups below fast instead of a scan per row.
CREATE CONSTRAINT person_id IF NOT EXISTS FOR (p:Person) REQUIRE p.person_id IS UNIQUE;
CREATE CONSTRAINT movie_id  IF NOT EXISTS FOR (m:Movie)  REQUIRE m.movie_id  IS UNIQUE;
CREATE CONSTRAINT user_id   IF NOT EXISTS FOR (u:User)   REQUIRE u.user_id   IS UNIQUE;
CREATE CONSTRAINT genre_name IF NOT EXISTS FOR (g:Genre) REQUIRE g.name      IS UNIQUE;

// --- Nodes -------------------------------------------------------------------
// toInteger()/toFloat() matter: every value LOAD CSV reads is a string.
LOAD CSV WITH HEADERS FROM 'file:///people.csv' AS row
MERGE (p:Person {person_id: toInteger(row.person_id)})
SET p.name    = row.name,
    p.born    = toInteger(row.born),
    p.country = row.country;

LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movie_id: toInteger(row.movie_id)})
SET m.title        = row.title,
    m.released     = toInteger(row.released),
    m.tagline      = row.tagline,
    m.runtime      = toInteger(row.runtime),
    m.budget_musd  = toFloat(row.budget_musd),
    m.revenue_musd = toFloat(row.revenue_musd);

LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {user_id: toInteger(row.user_id)})
SET u.name    = row.name,
    u.joined  = toInteger(row.joined),
    u.country = row.country;

// --- Relationships -----------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///acted_in.csv' AS row
MATCH (p:Person {person_id: toInteger(row.person_id)})
MATCH (m:Movie  {movie_id:  toInteger(row.movie_id)})
MERGE (p)-[r:ACTED_IN]->(m)
SET r.roles = row.roles;

LOAD CSV WITH HEADERS FROM 'file:///directed.csv' AS row
MATCH (p:Person {person_id: toInteger(row.person_id)})
MATCH (m:Movie  {movie_id:  toInteger(row.movie_id)})
MERGE (p)-[:DIRECTED]->(m);

// Genre nodes are created from the relationship file -- the genre list only
// exists as a column, so MERGE both ends here.
LOAD CSV WITH HEADERS FROM 'file:///in_genre.csv' AS row
MATCH (m:Movie {movie_id: toInteger(row.movie_id)})
MERGE (g:Genre {name: row.genre})
MERGE (m)-[:IN_GENRE]->(g);

LOAD CSV WITH HEADERS FROM 'file:///rated.csv' AS row
MATCH (u:User  {user_id:  toInteger(row.user_id)})
MATCH (m:Movie {movie_id: toInteger(row.movie_id)})
MERGE (u)-[r:RATED]->(m)
SET r.rating     = toInteger(row.rating),
    r.rated_year = toInteger(row.rated_year);

LOAD CSV WITH HEADERS FROM 'file:///follows.csv' AS row
MATCH (a:User {user_id: toInteger(row.from_user)})
MATCH (b:User {user_id: toInteger(row.to_user)})
MERGE (a)-[r:FOLLOWS]->(b)
SET r.since = toInteger(row.since);

// --- Verify ------------------------------------------------------------------
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS nodes ORDER BY label;
