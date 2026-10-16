#!/usr/bin/env bash
# Load both datasets. Safe to re-run: the Mongo import drops the collection
# first, and the Cypher loader is idempotent (constraints + MERGE).
set -euo pipefail

MONGO_USER="${MONGO_USER:-admin}"
MONGO_PASSWORD="${MONGO_PASSWORD:-password}"
NEO4J_USER="${NEO4J_USER:-neo4j}"
NEO4J_PASSWORD="${NEO4J_PASSWORD:-password}"

echo "==> MongoDB: importing the product catalog"
docker exec mongodb mongoimport \
  --username "$MONGO_USER" --password "$MONGO_PASSWORD" \
  --authenticationDatabase admin \
  --db shop --collection products \
  --file /sample_data/products.json --jsonArray --drop

echo "==> Neo4j: loading the movie graph"
docker exec -i neo4j cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
  < ../05_Neo4J/sample_data/load.cypher

echo
echo "==> Done. Verify:"
docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASSWORD" \
  --authenticationDatabase admin --quiet \
  --eval 'print("    MongoDB  shop.products: " + db.getSiblingDB("shop").products.countDocuments() + " documents")'
docker exec -i neo4j cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format plain \
  'MATCH (n) WITH labels(n)[0] AS label, count(*) AS nodes RETURN label, nodes ORDER BY label;' \
  | tail -n +2 | tr -d '"' | awk -F, '{printf "    Neo4j    %s: %s nodes\n", $1, $2}'
